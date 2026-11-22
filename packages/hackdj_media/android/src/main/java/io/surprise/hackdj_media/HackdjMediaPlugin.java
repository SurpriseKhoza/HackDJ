package io.surprise.hackdj_media;

import android.app.Activity;
import android.content.ContentUris;
import android.content.Context;
import android.content.pm.PackageManager;
import android.database.Cursor;
import android.graphics.Bitmap;
import android.media.MediaMetadataRetriever;
import android.net.Uri;
import android.os.Build;
import android.os.Handler;
import android.os.Looper;
import android.provider.MediaStore;
import android.util.Size;

import java.io.ByteArrayOutputStream;
import java.util.ArrayList;
import java.util.HashMap;
import java.util.List;
import java.util.Map;
import java.util.concurrent.ExecutorService;
import java.util.concurrent.Executors;

import io.flutter.embedding.engine.plugins.FlutterPlugin;
import io.flutter.embedding.engine.plugins.activity.ActivityAware;
import io.flutter.embedding.engine.plugins.activity.ActivityPluginBinding;
import io.flutter.plugin.common.MethodCall;
import io.flutter.plugin.common.MethodChannel;
import io.flutter.plugin.common.PluginRegistry;

/**
 * Reads the device's music library from the Android MediaStore (internal
 * storage and SD cards) and serves cover art. Heavy work runs on a background
 * thread; results are posted back to the main thread.
 */
public class HackdjMediaPlugin
        implements FlutterPlugin,
                MethodChannel.MethodCallHandler,
                ActivityAware,
                PluginRegistry.RequestPermissionsResultListener {

    private static final int REQUEST_CODE = 7311;

    private MethodChannel channel;
    private Context context;
    private Activity activity;
    private ActivityPluginBinding activityBinding;
    private MethodChannel.Result pendingPermission;

    private final ExecutorService io = Executors.newSingleThreadExecutor();
    private final Handler main = new Handler(Looper.getMainLooper());

    // ------------------------------------------------------------ FlutterPlugin
    @Override
    public void onAttachedToEngine(FlutterPlugin.FlutterPluginBinding binding) {
        context = binding.getApplicationContext();
        channel = new MethodChannel(binding.getBinaryMessenger(), "hackdj_media");
        channel.setMethodCallHandler(this);
    }

    @Override
    public void onDetachedFromEngine(FlutterPlugin.FlutterPluginBinding binding) {
        channel.setMethodCallHandler(null);
        channel = null;
        context = null;
    }

    // ------------------------------------------------------------ ActivityAware
    @Override
    public void onAttachedToActivity(ActivityPluginBinding binding) {
        activity = binding.getActivity();
        activityBinding = binding;
        binding.addRequestPermissionsResultListener(this);
    }

    @Override
    public void onDetachedFromActivityForConfigChanges() {
        detachActivity();
    }

    @Override
    public void onReattachedToActivityForConfigChanges(ActivityPluginBinding binding) {
        onAttachedToActivity(binding);
    }

    @Override
    public void onDetachedFromActivity() {
        detachActivity();
    }

    private void detachActivity() {
        if (activityBinding != null) {
            activityBinding.removeRequestPermissionsResultListener(this);
        }
        activityBinding = null;
        activity = null;
    }

    // -------------------------------------------------------------- permissions
    private static String permissionName() {
        return Build.VERSION.SDK_INT >= 33
                ? "android.permission.READ_MEDIA_AUDIO"
                : "android.permission.READ_EXTERNAL_STORAGE";
    }

    private boolean hasPermission() {
        if (Build.VERSION.SDK_INT < 23) return true;
        return context.checkSelfPermission(permissionName())
                == PackageManager.PERMISSION_GRANTED;
    }

    private void requestPermission(MethodChannel.Result result) {
        if (hasPermission()) {
            result.success(true);
            return;
        }
        if (activity == null || Build.VERSION.SDK_INT < 23) {
            result.success(false);
            return;
        }
        if (pendingPermission != null) {
            result.error("busy", "A permission request is already running.", null);
            return;
        }
        pendingPermission = result;
        activity.requestPermissions(new String[] {permissionName()}, REQUEST_CODE);
    }

    @Override
    public boolean onRequestPermissionsResult(
            int requestCode, String[] permissions, int[] grantResults) {
        if (requestCode != REQUEST_CODE) return false;
        boolean granted =
                grantResults.length > 0 && grantResults[0] == PackageManager.PERMISSION_GRANTED;
        if (pendingPermission != null) {
            pendingPermission.success(granted);
            pendingPermission = null;
        }
        return true;
    }

    // ------------------------------------------------------------------ methods
    @Override
    public void onMethodCall(MethodCall call, MethodChannel.Result result) {
        switch (call.method) {
            case "hasPermission":
                result.success(hasPermission());
                break;
            case "requestPermission":
                requestPermission(result);
                break;
            case "queryAudio":
                queryAudio(result);
                break;
            case "artwork": {
                Number id = call.argument("id");
                String path = call.argument("path");
                Number size = call.argument("size");
                if (id == null) {
                    result.success(null);
                } else {
                    artwork(id.longValue(), path, size == null ? 192 : size.intValue(), result);
                }
                break;
            }
            default:
                result.notImplemented();
        }
    }

    private void queryAudio(final MethodChannel.Result result) {
        if (!hasPermission()) {
            result.error("permission", "Audio permission has not been granted.", null);
            return;
        }
        io.execute(() -> {
            try {
                List<Map<String, Object>> out = new ArrayList<>();
                String[] projection = new String[] {
                    MediaStore.Audio.Media._ID,
                    MediaStore.Audio.Media.TITLE,
                    MediaStore.Audio.Media.ARTIST,
                    MediaStore.Audio.Media.ALBUM,
                    MediaStore.Audio.Media.DURATION,
                    MediaStore.Audio.Media.DATA,
                };
                // Music only: skip ringtones, notification sounds and alarms.
                String selection =
                        "(" + MediaStore.Audio.Media.IS_MUSIC + " != 0 OR "
                                + MediaStore.Audio.Media.DURATION + " >= 60000) AND "
                                + MediaStore.Audio.Media.IS_RINGTONE + " = 0 AND "
                                + MediaStore.Audio.Media.IS_NOTIFICATION + " = 0 AND "
                                + MediaStore.Audio.Media.IS_ALARM + " = 0";
                Cursor c = context.getContentResolver().query(
                        MediaStore.Audio.Media.EXTERNAL_CONTENT_URI,
                        projection,
                        selection,
                        null,
                        MediaStore.Audio.Media.TITLE + " COLLATE NOCASE ASC");
                if (c != null) {
                    try {
                        while (c.moveToNext()) {
                            String path = c.getString(5);
                            if (path == null) continue;
                            Map<String, Object> row = new HashMap<>();
                            row.put("id", c.getLong(0));
                            row.put("title", c.getString(1));
                            row.put("artist", c.getString(2));
                            row.put("album", c.getString(3));
                            row.put("duration", c.getLong(4));
                            row.put("path", path);
                            out.add(row);
                        }
                    } finally {
                        c.close();
                    }
                }
                main.post(() -> result.success(out));
            } catch (Exception e) {
                final String message = String.valueOf(e);
                main.post(() -> result.error("query_failed", message, null));
            }
        });
    }

    private void artwork(
            final long id, final String path, final int size, final MethodChannel.Result result) {
        io.execute(() -> {
            byte[] bytes = null;
            try {
                if (Build.VERSION.SDK_INT >= 29) {
                    try {
                        Uri uri = ContentUris.withAppendedId(
                                MediaStore.Audio.Media.EXTERNAL_CONTENT_URI, id);
                        Bitmap bitmap = context.getContentResolver()
                                .loadThumbnail(uri, new Size(size, size), null);
                        ByteArrayOutputStream stream = new ByteArrayOutputStream();
                        bitmap.compress(Bitmap.CompressFormat.JPEG, 85, stream);
                        bytes = stream.toByteArray();
                    } catch (Exception ignored) {
                        // No thumbnail: fall back to the picture embedded in the file.
                    }
                }
                if (bytes == null && path != null) {
                    MediaMetadataRetriever retriever = new MediaMetadataRetriever();
                    try {
                        retriever.setDataSource(path);
                        bytes = retriever.getEmbeddedPicture();
                    } catch (Exception ignored) {
                        // Unreadable or no embedded picture.
                    } finally {
                        try {
                            retriever.release();
                        } catch (Exception ignored) {
                            // Nothing to do.
                        }
                    }
                }
            } catch (Throwable ignored) {
                // Artwork is optional; never fail the call.
            }
            final byte[] out = bytes;
            main.post(() -> result.success(out));
        });
    }
}
