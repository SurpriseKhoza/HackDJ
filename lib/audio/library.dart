import 'dart:convert';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'models.dart';

/// The track collection. Imported files are copied into the app's documents
/// directory so they stay readable on iOS/Android after the picker's temporary
/// copy is cleaned up. The index is a small JSON file next to them.
class Library extends ChangeNotifier {
  static const extensions = ['mp3', 'wav', 'flac', 'ogg', 'm4a', 'aac', 'opus'];

  final List<Track> tracks = [];
  late Directory _tracksDir;
  late File _index;
  bool importing = false;

  Future<void> load() async {
    final docs = await getApplicationDocumentsDirectory();
    _tracksDir = Directory(p.join(docs.path, 'tracks'));
    await _tracksDir.create(recursive: true);
    _index = File(p.join(docs.path, 'library.json'));
    if (await _index.exists()) {
      try {
        final list = jsonDecode(await _index.readAsString()) as List<dynamic>;
        tracks
          ..clear()
          ..addAll(
            list
                .map((e) => Track.fromJson(e as Map<String, dynamic>))
                .where((t) => File(t.path).existsSync()),
          );
      } catch (e) {
        debugPrint('Library index unreadable: $e');
      }
    }
    notifyListeners();
  }

  Future<void> _save() async {
    await _index.writeAsString(jsonEncode(tracks.map((t) => t.toJson()).toList()));
  }

  /// Opens the system picker and imports the selected audio files.
  /// Returns how many new tracks were added.
  Future<int> importFiles() async {
    importing = true;
    notifyListeners();
    var added = 0;
    try {
      final picked = await FilePicker.pickFiles(
        type: FileType.custom,
        allowedExtensions: extensions,
      );
      for (final f in picked) {
        final src = f.path;
        if (src == null) continue;
        final name = p.basename(src);
        final dest = p.join(_tracksDir.path, name);
        if (tracks.any((t) => t.path == dest)) continue;
        await File(src).copy(dest);
        tracks.add(Track(path: dest, title: p.basenameWithoutExtension(name)));
        added++;
      }
      tracks.sort((a, b) => a.title.toLowerCase().compareTo(b.title.toLowerCase()));
      await _save();
    } catch (e) {
      debugPrint('Import failed: $e');
    }
    importing = false;
    notifyListeners();
    return added;
  }

  Future<void> remove(Track t) async {
    tracks.remove(t);
    try {
      await File(t.path).delete();
    } catch (_) {}
    await _save();
    notifyListeners();
  }

  void setBpm(Track t, double bpm) {
    t.bpm = bpm;
    _save();
    notifyListeners();
  }
}
