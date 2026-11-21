import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'deck.dart';
import 'library.dart';
import 'models.dart';
import 'recorder.dart';
import 'sampler.dart';

/// Owns the SoLoud engine and everything routed through it:
///
///   deck A bus ─┐
///   deck B bus ─┼─> master (global volume -> limiter) ─> output / recorder
///   sampler bus ┘
class DjEngine extends ChangeNotifier {
  DjEngine._();
  static final DjEngine instance = DjEngine._();

  final SoLoud soloud = SoLoud.instance;
  final Library library = Library();

  late final Deck deckA;
  late final Deck deckB;
  late final Sampler sampler;
  late final Recorder recorder;

  /// 0 = deck A, 1 = deck B.
  double crossfader = 0.5;
  CrossfaderCurve curve = CrossfaderCurve.mix;
  double masterVolume = 0.85;

  final ValueNotifier<double> masterLevel = ValueNotifier(0);

  Timer? _ticker;
  Timer? _autoFade;
  bool _ready = false;
  bool get isReady => _ready;

  Future<void> init() async {
    if (_ready) return;
    await soloud.init();
    soloud.setVisualizationEnabled(true); // needed for per-bus level meters

    final busA = soloud.createMixingBus(name: 'Deck A')..playOnEngine();
    final busB = soloud.createMixingBus(name: 'Deck B')..playOnEngine();

    deckA = Deck(id: 'A', soloud: soloud, bus: busA, onBpmFound: library.setBpm)
      ..initFilters();
    deckB = Deck(id: 'B', soloud: soloud, bus: busB, onBpmFound: library.setBpm)
      ..initFilters();

    sampler = Sampler(soloud);
    await sampler.init();
    recorder = Recorder(soloud);

    // Safety limiter on the master. Activate it last so it sits at the end of
    // the global chain.
    soloud.filters.limiterFilter.activate();
    soloud.setGlobalVolume(masterVolume);

    await library.load();
    _applyCrossfader();

    _ticker = Timer.periodic(const Duration(milliseconds: 33), (_) => _tick());
    _ready = true;
  }

  // ------------------------------------------------------------- crossfader
  void setCrossfader(double v) {
    crossfader = v.clamp(0.0, 1.0).toDouble();
    _applyCrossfader();
    notifyListeners();
  }

  void cycleCurve() {
    curve = curve.next;
    _applyCrossfader();
    notifyListeners();
  }

  (double, double) _gains(double x) {
    switch (curve) {
      case CrossfaderCurve.mix:
        final a = x <= 0.5 ? 1.0 : math.cos((x - 0.5) * math.pi);
        final b = x >= 0.5 ? 1.0 : math.sin(x * math.pi);
        return (a, b);
      case CrossfaderCurve.blend:
        return (math.cos(x * math.pi / 2), math.sin(x * math.pi / 2));
      case CrossfaderCurve.cut:
        return (x < 0.97 ? 1.0 : 0.0, x > 0.03 ? 1.0 : 0.0);
    }
  }

  void _applyCrossfader() {
    final (a, b) = _gains(crossfader);
    deckA.setCrossGain(a);
    deckB.setCrossGain(b);
  }

  /// Smooth transition to the other deck (a one-tap "auto mix" blend).
  void autoFade({required bool toB, Duration time = const Duration(seconds: 8)}) {
    _autoFade?.cancel();
    final from = crossfader;
    final to = toB ? 1.0 : 0.0;
    final clock = Stopwatch()..start();
    _autoFade = Timer.periodic(const Duration(milliseconds: 33), (t) {
      final p = (clock.elapsedMilliseconds / time.inMilliseconds).clamp(0.0, 1.0);
      final eased = p * p * (3 - 2 * p);
      setCrossfader(from + (to - from) * eased);
      if (p >= 1) t.cancel();
    });
  }

  void cancelAutoFade() => _autoFade?.cancel();

  // ----------------------------------------------------------------- master
  void setMasterVolume(double v) {
    masterVolume = v.clamp(0.0, 1.0).toDouble();
    soloud.setGlobalVolume(masterVolume);
    notifyListeners();
  }

  void _tick() {
    deckA.tick();
    deckB.tick();
    try {
      final l = math.max(soloud.getApproximateVolume(0), soloud.getApproximateVolume(1));
      masterLevel.value = math.max(l, masterLevel.value * 0.82);
    } catch (_) {}
  }
}
