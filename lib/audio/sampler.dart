import 'dart:ui' show Color;

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'library.dart';
import 'synth.dart';

class Pad {
  Pad(this.name, this.color, this.builtin);

  final String name;
  final Color color;
  final Uint8List Function() builtin;
  AudioSource? source;
  SoundHandle? loopHandle;
  bool custom = false;

  /// Bumped on every trigger so the UI can flash the pad.
  final ValueNotifier<int> hits = ValueNotifier(0);
}

/// 8-pad sampler routed through its own bus (so it can be level-matched and
/// ends up in the master recording like everything else).
class Sampler extends ChangeNotifier {
  Sampler(this.soloud);

  final SoLoud soloud;
  late final Bus bus;

  /// When on, pads latch a looping voice instead of firing one-shots.
  bool loopMode = false;
  double volume = 0.9;

  final List<Pad> pads = [
    Pad('KICK', const Color(0xFFF87171), Synth.kick),
    Pad('SNARE', const Color(0xFFFBBF24), Synth.snare),
    Pad('HAT', const Color(0xFF34D399), Synth.hat),
    Pad('OPEN HAT', const Color(0xFF22D3EE), () => Synth.hat(open: true)),
    Pad('CLAP', const Color(0xFFA78BFA), Synth.clap),
    Pad('TOM', const Color(0xFFF472B6), Synth.tom),
    Pad('AIR HORN', const Color(0xFFFB923C), Synth.airhorn),
    Pad('LASER', const Color(0xFF60A5FA), Synth.laser),
  ];

  Future<void> init() async {
    bus = soloud.createMixingBus(name: 'Sampler');
    bus.playOnEngine();
    for (final pad in pads) {
      pad.source = await soloud.loadMem('${pad.name}.wav', pad.builtin());
    }
    _applyVolume();
  }

  void setVolume(double v) {
    volume = v.clamp(0.0, 1.0).toDouble();
    _applyVolume();
    notifyListeners();
  }

  void _applyVolume() {
    final h = bus.soundHandle;
    if (h != null) soloud.setVolume(h, volume);
  }

  void toggleLoopMode() {
    loopMode = !loopMode;
    notifyListeners();
  }

  /// True while the pad's latched loop is sounding.
  bool isLatched(Pad pad) {
    final h = pad.loopHandle;
    return h != null && soloud.getIsValidVoiceHandle(h);
  }

  void trigger(int i) {
    final pad = pads[i];
    final src = pad.source;
    if (src == null) return;
    if (loopMode) {
      if (isLatched(pad)) {
        soloud.stop(pad.loopHandle!);
        pad.loopHandle = null;
      } else {
        pad.loopHandle = bus.play(src, looping: true);
      }
    } else {
      bus.play(src);
    }
    pad.hits.value++;
  }

  /// Long-press a pad to replace its sound with a file of your own.
  Future<void> loadCustom(int i) async {
    final f = await FilePicker.pickFile(
      type: FileType.custom,
      allowedExtensions: Library.extensions,
    );
    final path = f?.path;
    if (path == null) return;
    final pad = pads[i];
    try {
      if (isLatched(pad)) await soloud.stop(pad.loopHandle!);
      pad.loopHandle = null;
      final old = pad.source;
      pad.source = await soloud.loadFile(path);
      if (old != null) await soloud.disposeSource(old);
      pad.custom = true;
      notifyListeners();
    } catch (e) {
      debugPrint('Custom pad load failed: $e');
    }
  }
}
