import 'dart:typed_data';

import 'package:dj/audio/wav.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('reversedMonoWav writes a valid header and reverses the samples', () {
    final wav = reversedMonoWav(Float32List.fromList([0.0, 0.5, -0.5, 1.0]), 22050);
    final b = ByteData.sublistView(wav);

    expect(String.fromCharCodes(wav.sublist(0, 4)), 'RIFF');
    expect(String.fromCharCodes(wav.sublist(8, 12)), 'WAVE');
    expect(String.fromCharCodes(wav.sublist(36, 40)), 'data');
    expect(b.getUint32(24, Endian.little), 22050);
    expect(b.getUint32(40, Endian.little), 8); // 4 samples x 2 bytes
    expect(wav.length, 44 + 8);

    // Last input sample comes first.
    expect(b.getInt16(44, Endian.little), 32767);
    expect(b.getInt16(46, Endian.little), -16384);
    expect(b.getInt16(48, Endian.little), 16384);
    expect(b.getInt16(50, Endian.little), 0);
  });

  test('reversedMonoWav clamps out-of-range samples', () {
    final wav = reversedMonoWav(Float32List.fromList([2.0, -2.0]), 8000);
    final b = ByteData.sublistView(wav);
    expect(b.getInt16(44, Endian.little), -32767);
    expect(b.getInt16(46, Endian.little), 32767);
  });
}
