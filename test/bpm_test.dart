import 'dart:typed_data';

import 'package:dj/audio/bpm.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('estimateBpm finds a 120 BPM pulse train', () {
    const pps = 400.0;
    const seconds = 40;
    final samples = Float32List((pps * seconds).toInt());
    // A kick every 0.5 s => 120 BPM.
    for (var beat = 0; beat < seconds * 2; beat++) {
      final start = (beat * 0.5 * pps).round();
      for (var k = 0; k < 4 && start + k < samples.length; k++) {
        samples[start + k] = 1.0;
      }
    }
    final bpm = estimateBpm(samples, pps);
    expect(bpm, isNotNull);
    expect(bpm!, closeTo(120, 2));
  });

  test('estimateBpm rejects clips that are too short', () {
    expect(estimateBpm(Float32List(100), 400), isNull);
  });

  test('estimateBeatOffset finds where the first beat falls', () {
    const pps = 400.0;
    const seconds = 40;
    const firstBeat = 0.2; // seconds of silence before the first kick
    final samples = Float32List((pps * seconds).toInt());
    for (var beat = 0; beat < seconds * 2 - 1; beat++) {
      final start = ((firstBeat + beat * 0.5) * pps).round();
      for (var k = 0; k < 4 && start + k < samples.length; k++) {
        samples[start + k] = 1.0;
      }
    }
    final offset = estimateBeatOffset(samples, pps, 120);
    expect(offset, isNotNull);
    expect(offset!, closeTo(firstBeat, 0.03));
  });

  test('estimateBeatOffset rejects clips that are too short', () {
    expect(estimateBeatOffset(Float32List(100), 400, 120), isNull);
  });
}
