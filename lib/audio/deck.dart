import 'dart:async';
import 'dart:isolate';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter_soloud/flutter_soloud.dart';

import 'bpm.dart';
import 'models.dart';

typedef BpmCallback = void Function(Track track, double bpm);

/// One DJ deck: a loaded track played through its own SoLoud mixing [bus].
///
/// Signal path per deck:
///   voice (trim volume, play speed) -> bus filters (3-band EQ, DJ filter,
///   key lock, echo / reverb / flanger) -> bus volume (channel fader x
///   crossfader) -> master (limiter).
///
/// Everything that touches the SoLoud filter API is funnelled through
/// [_guard] so a bad parameter can never take the UI down.
class Deck extends ChangeNotifier {
  Deck({
    required this.id,
    required this.soloud,
    required this.bus,
    this.onBpmFound,
  });

  final String id;
  final SoLoud soloud;
  final Bus bus;
  final BpmCallback? onBpmFound;

  // ------------------------------------------------------------- track state
  Track? track;
  AudioSource? _source;
  SoundHandle? _handle;
  Duration duration = Duration.zero;
  bool loading = false;
  bool playing = false;
  String? error;
  double bpm = 0;
  bool bpmAnalysing = false;

  /// Seconds into the track (track time, not scaled by pitch) where the first
  /// beat of the grid falls. Beat n sits at `beatOffset + n * 60 / bpm`.
  double beatOffset = 0;

  /// Updated ~30 times a second; listen to this, not the whole deck.
  final ValueNotifier<Duration> position = ValueNotifier(Duration.zero);
  final ValueNotifier<double> level = ValueNotifier(0);

  Float32List peaks = Float32List(0);
  double peakRate = 50; // peak bins per second of audio

  // ------------------------------------------------------------------- pitch
  double tempo = 0; // -1..1 of [range]
  TempoRange range = TempoRange.pct8;
  bool keyLock = false;
  double _bend = 0;
  bool _scratching = false;
  bool _wasPlaying = false;

  // ------------------------------------------------------------------- mixer
  double trim = 0; // -1..1  => x0.5 .. x2
  double eqLow = 0; // -1..1  (-1 = kill)
  double eqMid = 0;
  double eqHigh = 0;
  double filter = 0; // -1 low-pass .. +1 high-pass
  double fader = 1; // channel fader 0..1
  double crossGain = 1; // set by the engine

  // --------------------------------------------------------------- cues/loops
  Duration? cuePoint;
  final List<Duration?> hotCues = List<Duration?>.filled(4, null);
  Duration? loopIn;
  Duration? loopOut;
  bool loopActive = false;

  // ---------------------------------------------------------------------- fx
  final Map<FxUnit, bool> fxOn = {for (final u in FxUnit.values) u: false};
  double fxAmount = 0.4;

  // ----------------------------------------------------------------- derived
  bool get isLoaded => _source != null;
  bool get _voiceAlive {
    final h = _handle;
    return h != null && soloud.getIsValidVoiceHandle(h);
  }

  double get rate =>
      (1 + tempo * range.fraction + _bend).clamp(0.25, 3.0).toDouble();
  double get currentBpm => bpm * rate;
  double get tempoPercent => (rate - 1) * 100;
  double get _trimGain => math.pow(2.0, trim).toDouble();

  // ------------------------------------------------------------ bus / filters
  /// Call once after the bus has been played on the engine.
  void initFilters() {
    _guard(() {
      bus.filters.parametricEqFilter.activate(); // default 3 log-spaced bands
    });
    _applyBusVolume();
    _applyEq();
  }

  void _guard(void Function() body) {
    try {
      body();
    } catch (e, s) {
      debugPrint('[Deck $id] audio call failed: $e\n$s');
    }
  }

  void _applyBusVolume() {
    final h = bus.soundHandle;
    if (h != null) _guard(() => soloud.setVolume(h, fader * crossGain));
  }

  void setFader(double v) {
    fader = v.clamp(0.0, 1.0).toDouble();
    _applyBusVolume();
    notifyListeners();
  }

  void setCrossGain(double g) {
    crossGain = g;
    _applyBusVolume();
  }

  void setTrim(double v) {
    trim = v.clamp(-1.0, 1.0).toDouble();
    final h = _handle;
    if (h != null && _voiceAlive) {
      _guard(() => soloud.setVolume(h, _trimGain));
    }
    notifyListeners();
  }

  double _eqGain(double v) => v <= 0 ? 1 + v : 1 + v * 1.5;

  void setEq({double? low, double? mid, double? high}) {
    if (low != null) eqLow = low.clamp(-1.0, 1.0).toDouble();
    if (mid != null) eqMid = mid.clamp(-1.0, 1.0).toDouble();
    if (high != null) eqHigh = high.clamp(-1.0, 1.0).toDouble();
    _applyEq();
    notifyListeners();
  }

  void _applyEq() => _guard(() {
        final eq = bus.filters.parametricEqFilter;
        final h = bus.soundHandle;
        eq.bandGain(0, soundHandle: h).value = _eqGain(eqLow);
        eq.bandGain(1, soundHandle: h).value = _eqGain(eqMid);
        eq.bandGain(2, soundHandle: h).value = _eqGain(eqHigh);
      });

  /// One-knob DJ filter: left = low-pass sweep, right = high-pass sweep.
  void setFilter(double v) {
    filter = v.clamp(-1.0, 1.0).toDouble();
    _guard(() {
      final f = bus.filters.biquadFilter;
      final h = bus.soundHandle;
      if (filter.abs() < 0.03) {
        if (f.isActive) f.deactivate();
        return;
      }
      if (!f.isActive) f.activate();
      final t = filter.abs();
      final low = filter < 0;
      final hz = low
          ? 16000 * math.pow(80 / 16000, t)
          : 30 * math.pow(8000 / 30, t);
      f.type(soundHandle: h).value = low ? 0 : 1; // 0 = low-pass, 1 = high-pass
      f.frequency(soundHandle: h).value = hz.toDouble();
      f.resonance(soundHandle: h).value = 1.5 + 2.5 * t;
    });
    notifyListeners();
  }

  // ---------------------------------------------------------------------- fx
  void toggleFx(FxUnit unit) {
    fxOn[unit] = !(fxOn[unit] ?? false);
    _applyFx();
    notifyListeners();
  }

  void setFxAmount(double v) {
    fxAmount = v.clamp(0.0, 1.0).toDouble();
    _applyFx();
    notifyListeners();
  }

  void _applyFx() => _guard(() {
        final h = bus.soundHandle;
        final beat = (bpm > 0 ? 60 / currentBpm : 0.5).toDouble();

        final echo = bus.filters.echoFilter;
        if (fxOn[FxUnit.echo]!) {
          if (!echo.isActive) echo.activate();
          echo.delay(soundHandle: h).value =
              (beat * 0.75).clamp(0.05, 2.9).toDouble();
          echo.decay(soundHandle: h).value = 0.5;
          echo.wet(soundHandle: h).value = fxAmount;
        } else if (echo.isActive) {
          echo.deactivate();
        }

        final verb = bus.filters.freeverbFilter;
        if (fxOn[FxUnit.reverb]!) {
          if (!verb.isActive) verb.activate();
          verb.roomSize(soundHandle: h).value = 0.75;
          verb.damp(soundHandle: h).value = 0.5;
          verb.wet(soundHandle: h).value = fxAmount;
        } else if (verb.isActive) {
          verb.deactivate();
        }

        final flanger = bus.filters.flangerFilter;
        if (fxOn[FxUnit.flanger]!) {
          if (!flanger.isActive) flanger.activate();
          flanger.wet(soundHandle: h).value = fxAmount;
        } else if (flanger.isActive) {
          flanger.deactivate();
        }
      });

  // -------------------------------------------------------------- loading
  Future<void> load(Track t) async {
    await eject();
    loading = true;
    error = null;
    notifyListeners();
    try {
      final src = await soloud.loadFile(t.path);
      _source = src;
      track = t;
      duration = soloud.getLength(src);
      bpm = t.bpm ?? 0;
      beatOffset = 0;
      tempo = 0;
      _bend = 0;
      cuePoint = Duration.zero;
      position.value = Duration.zero;
      _applyRate();
      _applyFx();
      unawaited(_buildPeaks(t.path));
      if (bpm <= 0) {
        unawaited(_analyseBpm(t));
      } else {
        unawaited(_analyseGrid(t));
      }
    } catch (e) {
      error = 'Could not load track: $e';
      _source = null;
      track = null;
    }
    loading = false;
    notifyListeners();
  }

  Future<void> eject() async {
    final h = _handle;
    _handle = null;
    if (h != null && soloud.getIsValidVoiceHandle(h)) {
      await soloud.stop(h);
    }
    final s = _source;
    _source = null;
    if (s != null) await soloud.disposeSource(s);
    track = null;
    playing = false;
    duration = Duration.zero;
    peaks = Float32List(0);
    bpm = 0;
    beatOffset = 0;
    cuePoint = null;
    hotCues.fillRange(0, hotCues.length, null);
    loopIn = null;
    loopOut = null;
    loopActive = false;
    position.value = Duration.zero;
    notifyListeners();
  }

  Future<void> _buildPeaks(String path) async {
    final secs = duration.inMilliseconds / 1000;
    if (secs <= 0) return;
    const over = 8;
    final bins = (secs * peakRate).ceil();
    try {
      final raw = await soloud.readSamplesFromFile(path, bins * over);
      final count = raw.length ~/ over;
      if (count == 0) return;
      final out = Float32List(count);
      var top = 1e-6;
      for (var i = 0; i < count; i++) {
        var m = 0.0;
        for (var j = 0; j < over; j++) {
          final v = raw[i * over + j].abs();
          if (v > m) m = v;
        }
        out[i] = m;
        if (m > top) top = m;
      }
      for (var i = 0; i < count; i++) {
        out[i] = (out[i] / top).clamp(0.0, 1.0).toDouble();
      }
      if (track?.path != path) return; // another track was loaded meanwhile
      peaks = out;
      peakRate = count / secs;
      notifyListeners();
    } catch (e) {
      debugPrint('[Deck $id] waveform failed: $e');
    }
  }

  /// Estimates both the tempo and the beat-grid phase of a track whose BPM is
  /// not known yet.
  Future<void> _analyseBpm(Track t) async {
    final secs = duration.inMilliseconds / 1000;
    if (secs < 20) return;
    bpmAnalysing = true;
    notifyListeners();
    try {
      final raw = await soloud.readSamplesFromFile(t.path, (secs * 400).round());
      final pps = raw.length / secs;
      final result = await Isolate.run(() {
        final b = estimateBpm(raw, pps);
        return b == null ? null : (b, estimateBeatOffset(raw, pps, b));
      });
      if (result != null && identical(track, t)) {
        bpm = result.$1;
        beatOffset = result.$2 ?? 0;
        t.bpm = result.$1;
        onBpmFound?.call(t, result.$1);
        _applyFx();
      }
    } catch (e) {
      debugPrint('[Deck $id] bpm analysis failed: $e');
    }
    bpmAnalysing = false;
    notifyListeners();
  }

  /// Finds the beat-grid phase for a track whose BPM is already known (from
  /// the library or a previous TAP).
  Future<void> _analyseGrid(Track t) async {
    final secs = duration.inMilliseconds / 1000;
    final knownBpm = bpm;
    if (secs < 20 || knownBpm <= 0) return;
    try {
      final raw = await soloud.readSamplesFromFile(t.path, (secs * 400).round());
      final pps = raw.length / secs;
      final offset =
          await Isolate.run(() => estimateBeatOffset(raw, pps, knownBpm));
      if (offset != null && identical(track, t)) {
        beatOffset = offset;
        notifyListeners();
      }
    } catch (e) {
      debugPrint('[Deck $id] beat grid analysis failed: $e');
    }
  }

  /// Nearest beat on the grid to [p] (never before the start of the track).
  Duration _snapToBeat(Duration p) {
    if (bpm <= 0) return p;
    final period = 60 / bpm;
    final s = p.inMicroseconds / 1e6;
    final k = ((s - beatOffset) / period).round();
    final snapped = math.max(0.0, beatOffset + k * period);
    return Duration(microseconds: (snapped * 1e6).round());
  }

  // ----------------------------------------------------------- transport
  SoundHandle _spawn(Duration at, {required bool paused}) {
    final h = bus.play(_source!, volume: _trimGain, paused: true);
    if (at > Duration.zero) soloud.seek(h, at);
    soloud.setRelativePlaySpeed(h, rate);
    _applyLoopTo(h);
    if (!paused) soloud.setPause(h, false);
    return h;
  }

  void play() {
    if (!isLoaded) return;
    if (!_voiceAlive) {
      var at = position.value;
      if (at >= duration - const Duration(milliseconds: 50)) at = Duration.zero;
      _handle = _spawn(at, paused: false);
    } else {
      soloud.setPause(_handle!, false);
    }
    playing = true;
    notifyListeners();
  }

  void pause() {
    if (_voiceAlive) soloud.setPause(_handle!, true);
    playing = false;
    notifyListeners();
  }

  void togglePlay() => playing ? pause() : play();

  void seek(Duration p) {
    if (!isLoaded) return;
    var t = p;
    if (t < Duration.zero) t = Duration.zero;
    if (t > duration) t = duration;
    if (_voiceAlive) soloud.seek(_handle!, t);
    position.value = t;
  }

  /// CDJ-style cue: while playing jump back to the cue point and pause; while
  /// stopped, drop a new cue point at the current position.
  void cuePressed() {
    if (!isLoaded) return;
    if (playing) {
      pause();
      seek(cuePoint ?? Duration.zero);
    } else {
      cuePoint = position.value;
      notifyListeners();
    }
  }

  /// Empty slot: store the playhead. Filled slot: jump to it.
  void hotCue(int i) {
    if (!isLoaded) return;
    final existing = hotCues[i];
    if (existing == null) {
      hotCues[i] = position.value;
    } else {
      seek(existing);
    }
    notifyListeners();
  }

  void clearHotCue(int i) {
    hotCues[i] = null;
    notifyListeners();
  }

  // ------------------------------------------------------------ tempo / sync
  void setTempo(double v) {
    tempo = v.clamp(-1.0, 1.0).toDouble();
    _applyRate();
    _applyFx();
    notifyListeners();
  }

  void cycleRange() {
    // Keep the current speed when the range changes if it still fits.
    final pct = tempo * range.fraction;
    range = range.next;
    tempo = (pct / range.fraction).clamp(-1.0, 1.0).toDouble();
    _applyRate();
    notifyListeners();
  }

  void _applyRate() {
    if (_voiceAlive) soloud.setRelativePlaySpeed(_handle!, rate);
    if (keyLock) {
      _guard(() {
        bus.filters.pitchShiftFilter
            .shift(soundHandle: bus.soundHandle)
            .value = (1 / rate).clamp(0.5, 2.0).toDouble();
      });
    }
  }

  void toggleKeyLock() {
    keyLock = !keyLock;
    _guard(() {
      final f = bus.filters.pitchShiftFilter;
      if (keyLock) {
        if (!f.isActive) f.activate();
      } else if (f.isActive) {
        f.deactivate();
      }
    });
    _applyRate();
    notifyListeners();
  }

  /// Momentary pitch bend (nudge) while a button is held.
  void bendStart(int direction) {
    _bend = direction * 0.06;
    _applyRate();
  }

  void bendEnd() {
    _bend = 0;
    _applyRate();
  }

  /// Match this deck's tempo to [other] (octave-folded). Beat *phase* is left
  /// to the DJ: use the bend buttons or the jog wheel.
  void syncTo(Deck other) {
    if (bpm <= 0 || other.bpm <= 0) return;
    var target = other.currentBpm;
    while (target / bpm > 1.5) {
      target /= 2;
    }
    while (target / bpm < 0.67) {
      target *= 2;
    }
    final ratio = target / bpm;
    for (final r in TempoRange.values) {
      if ((ratio - 1).abs() <= r.fraction) {
        range = r;
        tempo = ((ratio - 1) / r.fraction).clamp(-1.0, 1.0).toDouble();
        _applyRate();
        _applyFx();
        notifyListeners();
        return;
      }
    }
  }

  final List<int> _taps = [];
  void tapTempo() {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (_taps.isNotEmpty && now - _taps.last > 2000) _taps.clear();
    _taps.add(now);
    if (_taps.length > 8) _taps.removeAt(0);
    if (_taps.length >= 3) {
      final avg = (_taps.last - _taps.first) / (_taps.length - 1);
      bpm = ((60000 / avg) / rate).clamp(60.0, 200.0).toDouble();
      final t = track;
      if (t != null) {
        t.bpm = bpm;
        onBpmFound?.call(t, bpm);
      }
      _applyFx();
      notifyListeners();
    }
  }

  // -------------------------------------------------------------------- loops
  void setLoopIn() {
    loopIn = position.value;
    final out = loopOut;
    if (out != null && out <= loopIn!) {
      loopOut = null;
      loopActive = false;
    }
    _applyLoop();
    notifyListeners();
  }

  void setLoopOut() {
    final start = loopIn;
    if (start == null) return;
    final p = position.value;
    if (p <= start) return;
    loopOut = p;
    loopActive = true;
    _applyLoop();
    notifyListeners();
  }

  void toggleLoop() {
    if (loopIn == null || loopOut == null) return;
    loopActive = !loopActive;
    _applyLoop();
    notifyListeners();
  }

  /// Auto loop of [beats] beats, starting on the nearest beat of the grid to
  /// the playhead (needs a BPM).
  void beatLoop(double beats) {
    if (bpm <= 0 || !isLoaded) return;
    final len = Duration(microseconds: (beats * 60 / bpm * 1e6).round());
    final start = _snapToBeat(position.value);
    loopIn = start;
    loopOut = start + len;
    loopActive = true;
    _applyLoop();
    notifyListeners();
  }

  void _applyLoop() {
    if (_voiceAlive) _applyLoopTo(_handle!);
  }

  void _applyLoopTo(SoundHandle h) {
    final a = loopIn;
    final b = loopOut;
    if (loopActive && a != null && b != null) {
      soloud.setLoopPoint(h, a);
      soloud.setLoopEndPoint(h, b);
      soloud.setLooping(h, true);
    } else {
      soloud.setLooping(h, false);
    }
  }

  // ------------------------------------------------------------ jog / scratch
  /// Touching the jog wheel holds the record; dragging scrubs the playhead.
  /// (SoLoud cannot play backwards, so scratching is seek-based.)
  void scratchStart() {
    _scratching = true;
    _wasPlaying = playing;
    if (_voiceAlive) soloud.setPause(_handle!, true);
  }

  void scratchMove(double seconds) {
    seek(position.value + Duration(milliseconds: (seconds * 1000).round()));
  }

  void scratchEnd() {
    _scratching = false;
    if (_wasPlaying) {
      play();
    } else {
      pause();
    }
  }

  // --------------------------------------------------------------------- tick
  void tick() {
    final h = _handle;
    if (h != null && !_scratching) {
      if (soloud.getIsValidVoiceHandle(h)) {
        position.value = soloud.getPosition(h);
      } else if (playing) {
        // Track ran off the end.
        playing = false;
        _handle = null;
        position.value = duration;
        notifyListeners();
      }
    }
    var l = 0.0;
    _guard(() {
      l = math.max(bus.getChannelVolume(0), bus.getChannelVolume(1));
    });
    level.value = math.max(l, level.value * 0.82);
  }

  @override
  void dispose() {
    position.dispose();
    level.dispose();
    super.dispose();
  }
}
