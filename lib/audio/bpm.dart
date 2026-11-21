import 'dart:math' as math;
import 'dart:typed_data';

/// Rough tempo estimate from a sparse amplitude trace.
///
/// [samples] are point samples spread evenly over the whole track (what
/// `SoLoud.readSamplesFromFile` returns) and [pointsPerSecond] is how many
/// of them there are per second of audio. The result is an *estimate* – it is
/// folded into 80–160 BPM and the UI lets the DJ correct it with TAP.
///
/// Pure Dart, so it can run inside `Isolate.run`.
double? estimateBpm(Float32List samples, double pointsPerSecond) {
  if (pointsPerSecond <= 0 || samples.length < pointsPerSecond * 20) {
    return null;
  }

  // 1. Amplitude envelope at roughly 200 Hz.
  final group = math.max(1, (pointsPerSecond / 200).round());
  final envRate = pointsPerSecond / group;
  final n = samples.length ~/ group;
  final env = Float64List(n);
  for (var i = 0; i < n; i++) {
    var m = 0.0;
    for (var j = 0; j < group; j++) {
      final v = samples[i * group + j].abs();
      if (v > m) m = v;
    }
    env[i] = m;
  }

  // 2. Onset strength = positive change of the lightly smoothed envelope.
  final onset = Float64List(n);
  var prev = 0.0;
  for (var i = 0; i < n; i++) {
    final s = i > 0 ? env[i] * 0.6 + env[i - 1] * 0.4 : env[i];
    final d = s - prev;
    onset[i] = d > 0 ? d : 0;
    prev = s;
  }

  // 3. Autocorrelation over 70..180 BPM with fractional lags.
  var bestBpm = 0.0;
  var bestScore = -1.0;
  for (var bpm = 70.0; bpm <= 180.0; bpm += 0.25) {
    final lag = envRate * 60 / bpm;
    final lagInt = lag.floor();
    final frac = lag - lagInt;
    var sum = 0.0;
    var count = 0;
    for (var i = 0; i + lagInt + 1 < n; i++) {
      final a = onset[i];
      if (a == 0) continue;
      final b = onset[i + lagInt] * (1 - frac) + onset[i + lagInt + 1] * frac;
      sum += a * b;
      count++;
    }
    if (count == 0) continue;
    final score = sum / math.sqrt(count);
    if (score > bestScore) {
      bestScore = score;
      bestBpm = bpm;
    }
  }
  if (bestBpm <= 0) return null;

  // 4. Fold into a comfortable DJ range.
  var result = bestBpm;
  while (result < 80) {
    result *= 2;
  }
  while (result > 160) {
    result /= 2;
  }
  return (result * 10).round() / 10;
}
