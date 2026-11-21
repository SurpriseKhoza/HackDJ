import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../audio/deck.dart';
import '../palette.dart';

const _cueColors = [
  Color(0xFFF87171),
  Color(0xFF34D399),
  Color(0xFFFBBF24),
  Color(0xFFA78BFA),
];

/// Scrolling close-up waveform centred on the playhead, with a beat grid
/// (assumes the first beat is at 0:00 – nudge with the bend buttons), hot-cue
/// flags and the active loop region.
class ScrollingWaveform extends StatelessWidget {
  const ScrollingWaveform({super.key, required this.deck, required this.color});

  final Deck deck;
  final Color color;

  @override
  Widget build(BuildContext context) => ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: SizedBox.expand(
          child: CustomPaint(painter: _ScrollPainter(deck, color)),
        ),
      );
}

class _ScrollPainter extends CustomPainter {
  _ScrollPainter(this.deck, this.color)
      : super(repaint: Listenable.merge([deck.position, deck]));

  final Deck deck;
  final Color color;

  static const double _window = 5; // seconds shown each side of the playhead

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    final mid = h / 2;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0A0E16));

    final pos = deck.position.value.inMilliseconds / 1000;
    final pxPerSec = w / (_window * 2);
    double xOf(double seconds) => w / 2 + (seconds - pos) * pxPerSec;

    // Loop region.
    final a = deck.loopIn;
    final b = deck.loopOut;
    if (a != null && b != null) {
      final x1 = xOf(a.inMilliseconds / 1000);
      final x2 = xOf(b.inMilliseconds / 1000);
      canvas.drawRect(
        Rect.fromLTRB(x1.clamp(0, w), 0, x2.clamp(0, w), h),
        Paint()
          ..color = Palette.accent.withValues(alpha: deck.loopActive ? 0.22 : 0.08),
      );
    }

    // Beat grid.
    if (deck.bpm > 0) {
      final beat = 60 / deck.bpm;
      final first = ((pos - _window) / beat).floor();
      final last = ((pos + _window) / beat).ceil();
      for (var k = first; k <= last; k++) {
        if (k < 0) continue;
        final x = xOf(k * beat);
        canvas.drawLine(
          Offset(x, 0),
          Offset(x, h),
          Paint()
            ..strokeWidth = k % 4 == 0 ? 1.6 : 1
            ..color = Colors_white.withValues(alpha: k % 4 == 0 ? 0.28 : 0.10),
        );
      }
    }

    // Waveform bars.
    final peaks = deck.peaks;
    if (peaks.isNotEmpty) {
      final rate = deck.peakRate;
      final past = Paint()..color = color.withValues(alpha: 0.45);
      final future = Paint()..color = color;
      for (double x = 0; x < w; x += 2) {
        final t = pos + (x - w / 2) / pxPerSec;
        if (t < 0) continue;
        final idx = (t * rate).floor();
        if (idx >= peaks.length) break;
        final bh = math.max(1.5, peaks[idx] * (h - 8));
        canvas.drawRect(
          Rect.fromLTWH(x, mid - bh / 2, 1.5, bh),
          x < w / 2 ? past : future,
        );
      }
    } else {
      canvas.drawLine(
        Offset(0, mid),
        Offset(w, mid),
        Paint()..color = Palette.stroke,
      );
    }

    // Hot cue flags.
    for (var i = 0; i < deck.hotCues.length; i++) {
      final c = deck.hotCues[i];
      if (c == null) continue;
      final x = xOf(c.inMilliseconds / 1000);
      if (x < -4 || x > w + 4) continue;
      final paint = Paint()..color = _cueColors[i];
      canvas.drawRect(Rect.fromLTWH(x - 1, 0, 2, h), paint);
      canvas.drawRect(Rect.fromLTWH(x, 0, 12, 12), paint);
    }

    // Playhead.
    canvas.drawLine(
      Offset(w / 2, 0),
      Offset(w / 2, h),
      Paint()
        ..strokeWidth = 2
        ..color = Palette.text,
    );
  }

  @override
  bool shouldRepaint(_ScrollPainter o) => o.color != color;
}

/// Whole-track overview. Tap or drag to seek.
class OverviewWaveform extends StatelessWidget {
  const OverviewWaveform({super.key, required this.deck, required this.color});

  final Deck deck;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        void seekTo(double dx) {
          final f = (dx / box.maxWidth).clamp(0.0, 1.0);
          deck.seek(Duration(milliseconds: (deck.duration.inMilliseconds * f).round()));
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => seekTo(d.localPosition.dx),
          onHorizontalDragUpdate: (d) => seekTo(d.localPosition.dx),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(6),
            child: CustomPaint(
              size: Size(box.maxWidth, box.maxHeight),
              painter: _OverviewPainter(deck, color),
            ),
          ),
        );
      },
    );
  }
}

class _OverviewPainter extends CustomPainter {
  _OverviewPainter(this.deck, this.color)
      : super(repaint: Listenable.merge([deck.position, deck]));

  final Deck deck;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;
    canvas.drawRect(Offset.zero & size, Paint()..color = const Color(0xFF0A0E16));

    final total = deck.duration.inMilliseconds;
    final frac = total == 0 ? 0.0 : deck.position.value.inMilliseconds / total;
    final playX = w * frac;

    final peaks = deck.peaks;
    if (peaks.isNotEmpty) {
      final done = Paint()..color = color.withValues(alpha: 0.4);
      final todo = Paint()..color = color.withValues(alpha: 0.9);
      final perPx = peaks.length / w;
      for (double x = 0; x < w; x += 2) {
        final from = (x * perPx).floor();
        final to = math.min(peaks.length, ((x + 2) * perPx).ceil());
        var m = 0.0;
        for (var i = from; i < to; i++) {
          if (peaks[i] > m) m = peaks[i];
        }
        final bh = math.max(1.0, m * (h - 4));
        canvas.drawRect(
          Rect.fromLTWH(x, (h - bh) / 2, 1.5, bh),
          x < playX ? done : todo,
        );
      }
    }

    // Loop + cues.
    final a = deck.loopIn;
    final b = deck.loopOut;
    if (a != null && b != null && total > 0) {
      canvas.drawRect(
        Rect.fromLTRB(w * a.inMilliseconds / total, 0, w * b.inMilliseconds / total, h),
        Paint()..color = Palette.accent.withValues(alpha: deck.loopActive ? 0.30 : 0.12),
      );
    }
    for (var i = 0; i < deck.hotCues.length; i++) {
      final c = deck.hotCues[i];
      if (c == null || total == 0) continue;
      canvas.drawRect(
        Rect.fromLTWH(w * c.inMilliseconds / total - 1, 0, 2, h),
        Paint()..color = _cueColors[i],
      );
    }

    canvas.drawRect(
      Rect.fromLTWH(playX - 1, 0, 2, h),
      Paint()..color = Palette.text,
    );
  }

  @override
  bool shouldRepaint(_OverviewPainter o) => o.color != color;
}

// `Colors` lives in Material; keep a tiny local stand-in.
const Colors_white = Color(0xFFFFFFFF);
