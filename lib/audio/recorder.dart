import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

/// Records the master mix (both decks + sampler, after the limiter) to a
/// 16-bit WAV using SoLoud's mixer-output capture, then patches the WAV header
/// with the final sizes when the recording stops.
class Recorder extends ChangeNotifier {
  Recorder(this.soloud);

  final SoLoud soloud;

  bool recording = false;
  Duration elapsed = Duration.zero;
  String? lastFile;

  RandomAccessFile? _raf;
  StreamSubscription<Uint8List>? _sub;
  Timer? _timer;
  final Stopwatch _clock = Stopwatch();

  Future<void> start() async {
    if (recording) return;
    final docs = await getApplicationDocumentsDirectory();
    final dir = Directory(p.join(docs.path, 'recordings'));
    await dir.create(recursive: true);
    final stamp = DateTime.now().toIso8601String().replaceAll(RegExp(r'[:.]'), '-');
    final file = File(p.join(dir.path, 'HackDJ_$stamp.wav'));
    _raf = await file.open(mode: FileMode.write);
    lastFile = file.path;

    final stream = soloud.startMixerOutputStream(format: MixerOutputFormat.wav);
    _sub = stream.listen((chunk) => _raf?.writeFromSync(chunk));

    recording = true;
    elapsed = Duration.zero;
    _clock
      ..reset()
      ..start();
    _timer = Timer.periodic(const Duration(milliseconds: 250), (_) {
      elapsed = _clock.elapsed;
      notifyListeners();
    });
    notifyListeners();
  }

  Future<void> stop() async {
    if (!recording) return;
    recording = false;
    _timer?.cancel();
    _clock.stop();

    final done = Completer<void>();
    _sub?.onDone(() {
      if (!done.isCompleted) done.complete();
    });
    soloud.stopMixerOutputStream();
    await done.future.timeout(const Duration(seconds: 2), onTimeout: () {});
    await _sub?.cancel();
    _sub = null;

    // The header written at the start has zero sizes; the engine gives us the
    // finalised one once capture has stopped.
    final header = soloud.getMixerOutputWavHeader();
    final raf = _raf;
    _raf = null;
    if (raf != null) {
      if (header.isNotEmpty) {
        raf.setPositionSync(0);
        raf.writeFromSync(header);
      }
      raf.closeSync();
    }
    notifyListeners();
  }

  /// Lets the user save the last recording somewhere visible (Files, Downloads…).
  Future<void> exportLast() async {
    final path = lastFile;
    if (path == null) return;
    await FilePicker.saveFile(
      dialogTitle: 'Export recording',
      fileName: p.basename(path),
      bytes: await File(path).readAsBytes(),
    );
  }
}
