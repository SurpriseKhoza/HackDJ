import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:hackdj_media/hackdj_media.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

enum LibraryAccess {
  /// Not asked yet.
  unknown,
  granted,
  denied,

  /// Not Android, so there is no device library to read.
  unsupported,
}

/// The music on the device (internal storage and SD card), read straight from
/// the Android MediaStore. Nothing is copied or imported: only audio files the
/// system has indexed as music show up. Detected BPMs are remembered in a small
/// JSON file.
class Library extends ChangeNotifier {
  /// Formats the custom sampler pads accept.
  static const extensions = ['mp3', 'wav', 'flac', 'ogg', 'm4a', 'aac', 'opus'];

  final List<Track> tracks = [];
  final Map<String, double> _bpms = {};
  File? _bpmFile;

  LibraryAccess access = LibraryAccess.unknown;
  bool scanning = false;
  String? error;

  Future<void> load() async {
    try {
      final docs = await getApplicationDocumentsDirectory();
      final file = File(p.join(docs.path, 'bpm.json'));
      _bpmFile = file;
      if (await file.exists()) {
        final map = jsonDecode(await file.readAsString()) as Map<String, dynamic>;
        for (final e in map.entries) {
          _bpms[e.key] = (e.value as num).toDouble();
        }
      }
    } catch (e) {
      debugPrint('BPM cache unreadable: $e');
    }

    if (!HackdjMedia.supported) {
      access = LibraryAccess.unsupported;
    } else if (await HackdjMedia.hasPermission()) {
      await scan();
      return;
    }
    notifyListeners();
  }

  /// Asks for permission to read the device's music (if needed) and scans.
  Future<void> ensureAccess() async {
    if (access == LibraryAccess.granted ||
        access == LibraryAccess.unsupported ||
        scanning) {
      return;
    }
    final ok = await HackdjMedia.requestPermission();
    if (!ok) {
      access = LibraryAccess.denied;
      notifyListeners();
      return;
    }
    await scan();
  }

  /// Reads every song on the device again.
  Future<void> scan() async {
    if (scanning) return;
    scanning = true;
    error = null;
    notifyListeners();
    try {
      final items = await HackdjMedia.queryAudio();
      tracks.clear();
      for (final a in items) {
        tracks.add(
          Track(
            path: a.path,
            title: a.title,
            artist: a.artist,
            album: a.album,
            durationMs: a.durationMs,
            mediaId: a.id,
            bpm: _bpms[a.path],
          ),
        );
      }
      access = LibraryAccess.granted;
    } catch (e) {
      error = 'Could not read your music: $e';
      debugPrint(error);
    }
    scanning = false;
    notifyListeners();
  }

  void setBpm(Track t, double bpm) {
    t.bpm = bpm;
    _bpms[t.path] = bpm;
    _saveBpms();
    notifyListeners();
  }

  Future<void> _saveBpms() async {
    final file = _bpmFile;
    if (file == null) return;
    try {
      await file.writeAsString(jsonEncode(_bpms));
    } catch (e) {
      debugPrint('Could not save BPM cache: $e');
    }
  }
}
