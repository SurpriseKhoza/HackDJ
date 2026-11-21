import 'dart:math' as math;
import 'dart:typed_data';

/// Tiny drum / FX synthesiser so HackDJ ships with a usable sampler and no
/// third-party audio assets. Every function returns a mono 16-bit 44.1 kHz WAV.
abstract final class Synth {
  static const int sampleRate = 44100;

  static Uint8List kick() {
    final n = (0.45 * sampleRate).round();
    final out = Float64List(n);
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final freq = 48 + 130 * math.exp(-t * 32);
      phase += 2 * math.pi * freq / sampleRate;
      final click = i < 90 ? 0.4 * (1 - i / 90) : 0.0;
      out[i] = math.sin(phase) * math.exp(-t * 7.5) + click;
    }
    return _wav(out);
  }

  static Uint8List snare() {
    final rnd = math.Random(3);
    final n = (0.35 * sampleRate).round();
    final out = Float64List(n);
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final noise = (rnd.nextDouble() * 2 - 1) * math.exp(-t * 22) * 0.8;
      final tone = math.sin(2 * math.pi * 190 * t) * math.exp(-t * 30) * 0.6;
      out[i] = noise + tone;
    }
    return _wav(out);
  }

  static Uint8List hat({bool open = false}) {
    final rnd = math.Random(5);
    final dur = open ? 0.5 : 0.12;
    final n = (dur * sampleRate).round();
    final out = Float64List(n);
    var prev = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final x = rnd.nextDouble() * 2 - 1;
      final hp = x - prev; // crude high-pass
      prev = x;
      out[i] = hp * math.exp(-t * (open ? 9 : 70)) * 0.7;
    }
    return _wav(out);
  }

  static Uint8List clap() {
    final rnd = math.Random(11);
    final n = (0.35 * sampleRate).round();
    final out = Float64List(n);
    const bursts = [0.0, 0.011, 0.023];
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      var env = math.exp(-t * 14) * 0.5;
      for (final b in bursts) {
        if (t >= b) env += math.exp(-(t - b) * 90);
      }
      out[i] = (rnd.nextDouble() * 2 - 1) * env;
    }
    return _wav(out);
  }

  static Uint8List tom() {
    final n = (0.5 * sampleRate).round();
    final out = Float64List(n);
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final freq = 95 + 100 * math.exp(-t * 14);
      phase += 2 * math.pi * freq / sampleRate;
      out[i] = math.sin(phase) * math.exp(-t * 6);
    }
    return _wav(out);
  }

  static Uint8List airhorn() {
    const dur = 1.0;
    final n = (dur * sampleRate).round();
    final out = Float64List(n);
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final vibrato = 1 + 0.012 * math.sin(2 * math.pi * 6 * t);
      phase += 2 * math.pi * 392 * vibrato / sampleRate;
      var s = 0.0;
      for (var k = 1; k <= 6; k++) {
        s += math.sin(k * phase) / k;
      }
      final attack = math.min(1.0, t / 0.02);
      final release = math.min(1.0, (dur - t) / 0.15);
      out[i] = s * attack * release;
    }
    return _wav(out);
  }

  static Uint8List laser() {
    final n = (0.45 * sampleRate).round();
    final out = Float64List(n);
    var phase = 0.0;
    for (var i = 0; i < n; i++) {
      final t = i / sampleRate;
      final freq = 180 + 3000 * math.exp(-t * 9);
      phase += 2 * math.pi * freq / sampleRate;
      out[i] = math.sin(phase) * math.exp(-t * 4);
    }
    return _wav(out);
  }

  /// Normalises to −0.7 dBFS and wraps [samples] in a canonical WAV header.
  static Uint8List _wav(Float64List samples) {
    var peak = 1e-9;
    for (final v in samples) {
      final a = v.abs();
      if (a > peak) peak = a;
    }
    final scale = 0.92 / peak;
    final dataLen = samples.length * 2;
    final bytes = ByteData(44 + dataLen);

    void tag(int offset, String text) {
      for (var i = 0; i < text.length; i++) {
        bytes.setUint8(offset + i, text.codeUnitAt(i));
      }
    }

    tag(0, 'RIFF');
    bytes.setUint32(4, 36 + dataLen, Endian.little);
    tag(8, 'WAVE');
    tag(12, 'fmt ');
    bytes.setUint32(16, 16, Endian.little);
    bytes.setUint16(20, 1, Endian.little); // PCM
    bytes.setUint16(22, 1, Endian.little); // mono
    bytes.setUint32(24, sampleRate, Endian.little);
    bytes.setUint32(28, sampleRate * 2, Endian.little);
    bytes.setUint16(32, 2, Endian.little);
    bytes.setUint16(34, 16, Endian.little);
    tag(36, 'data');
    bytes.setUint32(40, dataLen, Endian.little);
    for (var i = 0; i < samples.length; i++) {
      final v = (samples[i] * scale * 32767).round().clamp(-32768, 32767);
      bytes.setInt16(44 + i * 2, v.toInt(), Endian.little);
    }
    return bytes.buffer.asUint8List();
  }
}
