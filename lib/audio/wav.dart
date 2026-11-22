import 'dart:typed_data';

/// Builds a 16-bit mono PCM WAV file from [samples] (floats in -1..1) played
/// **backwards**, at [sampleRate] Hz.
///
/// Used for scratching: SoLoud cannot play a voice in reverse, so the deck
/// pre-renders a short reversed clip around the playhead and plays that
/// instead while the jog wheel moves backwards.
Uint8List reversedMonoWav(Float32List samples, int sampleRate) {
  final n = samples.length;
  final dataLength = n * 2;
  final b = ByteData(44 + dataLength);

  void tag(int offset, String text) {
    for (var i = 0; i < 4; i++) {
      b.setUint8(offset + i, text.codeUnitAt(i));
    }
  }

  tag(0, 'RIFF');
  b.setUint32(4, 36 + dataLength, Endian.little);
  tag(8, 'WAVE');
  tag(12, 'fmt ');
  b.setUint32(16, 16, Endian.little); // fmt chunk size
  b.setUint16(20, 1, Endian.little); // PCM
  b.setUint16(22, 1, Endian.little); // mono
  b.setUint32(24, sampleRate, Endian.little);
  b.setUint32(28, sampleRate * 2, Endian.little); // byte rate
  b.setUint16(32, 2, Endian.little); // block align
  b.setUint16(34, 16, Endian.little); // bits per sample
  tag(36, 'data');
  b.setUint32(40, dataLength, Endian.little);

  for (var i = 0; i < n; i++) {
    final v = (samples[n - 1 - i].clamp(-1.0, 1.0) * 32767).round();
    b.setInt16(44 + i * 2, v, Endian.little);
  }
  return b.buffer.asUint8List();
}
