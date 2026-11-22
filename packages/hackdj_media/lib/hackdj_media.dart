import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// One audio file as reported by the Android MediaStore.
class DeviceAudio {
  const DeviceAudio({
    required this.id,
    required this.title,
    required this.path,
    required this.durationMs,
    this.artist,
    this.album,
  });

  factory DeviceAudio.fromMap(Map<Object?, Object?> m) => DeviceAudio(
        id: (m['id'] as num).toInt(),
        title: _clean(m['title']) ?? 'Untitled',
        artist: _clean(m['artist']),
        album: _clean(m['album']),
        durationMs: (m['duration'] as num?)?.toInt() ?? 0,
        path: m['path'] as String,
      );

  final int id;
  final String title;
  final String? artist;
  final String? album;
  final int durationMs;
  final String path;

  static String? _clean(Object? v) {
    final s = (v as String?)?.trim();
    if (s == null || s.isEmpty || s == '<unknown>') return null;
    return s;
  }
}

/// Access to the music stored on the device (internal storage and SD card).
///
/// Everything is a no-op on platforms other than Android.
class HackdjMedia {
  HackdjMedia._();

  static const MethodChannel _channel = MethodChannel('hackdj_media');

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Whether the app may already read the device's audio files.
  static Future<bool> hasPermission() async {
    if (!supported) return false;
    return (await _channel.invokeMethod<bool>('hasPermission')) ?? false;
  }

  /// Shows the system permission dialog if needed. Resolves to whether access
  /// was granted.
  static Future<bool> requestPermission() async {
    if (!supported) return false;
    return (await _channel.invokeMethod<bool>('requestPermission')) ?? false;
  }

  /// All music on the device, sorted by title.
  static Future<List<DeviceAudio>> queryAudio() async {
    if (!supported) return const [];
    final raw = await _channel
        .invokeListMethod<Map<Object?, Object?>>('queryAudio');
    return [for (final m in raw ?? const <Map<Object?, Object?>>[]) DeviceAudio.fromMap(m)];
  }

  // ----------------------------------------------------------------- artwork
  static final Map<int, Uint8List?> _art = {};
  static final Map<int, Future<Uint8List?>> _artPending = {};

  static bool isArtworkCached(int id) => _art.containsKey(id);

  static Uint8List? cachedArtwork(int id) => _art[id];

  /// Cover art for a track, or null if it has none. Results are cached.
  static Future<Uint8List?> artwork(int id, String path, {int size = 192}) {
    if (_art.containsKey(id)) return Future.value(_art[id]);
    return _artPending[id] ??= _fetchArtwork(id, path, size);
  }

  static Future<Uint8List?> _fetchArtwork(int id, String path, int size) async {
    Uint8List? bytes;
    try {
      bytes = await _channel.invokeMethod<Uint8List>(
        'artwork',
        {'id': id, 'path': path, 'size': size},
      );
    } catch (e) {
      debugPrint('Artwork lookup failed: $e');
    }
    if (_art.length >= 600) _art.remove(_art.keys.first);
    _art[id] = bytes;
    _artPending.remove(id);
    return bytes;
  }
}
