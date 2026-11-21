import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import '../palette.dart';

/// Rotary knob driven by vertical drags. Double-tap resets to [resetTo].
class Knob extends StatelessWidget {
  const Knob({
    super.key,
    required this.value,
    required this.onChanged,
    required this.label,
    this.min = -1,
    this.max = 1,
    this.resetTo = 0,
    this.color = Palette.accent,
    this.size = 46,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final String label;
  final double min;
  final double max;
  final double resetTo;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) {
    final t = ((value - min) / (max - min)).clamp(0.0, 1.0).toDouble();
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        GestureDetector(
          behavior: HitTestBehavior.opaque,
          onDoubleTap: () => onChanged(resetTo),
          onVerticalDragUpdate: (d) => onChanged(
            (value - d.delta.dy * (max - min) / 150).clamp(min, max).toDouble(),
          ),
          child: SizedBox(
            width: size,
            height: size,
            child: CustomPaint(painter: _KnobPainter(t, color, min < 0 && max > 0)),
          ),
        ),
        const SizedBox(height: 2),
        Text(label, style: ts(10, color: Palette.dim)),
      ],
    );
  }
}

class _KnobPainter extends CustomPainter {
  _KnobPainter(this.t, this.color, this.bipolar);

  final double t;
  final Color color;
  final bool bipolar;

  static const double _start = 3 * math.pi / 4; // 135°
  static const double _sweep = 3 * math.pi / 2; // 270°

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 3;
    final rect = Rect.fromCircle(center: c, radius: r);

    final track = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = Palette.stroke;
    canvas.drawArc(rect, _start, _sweep, false, track);

    final arc = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.5
      ..strokeCap = StrokeCap.round
      ..color = color;
    if (bipolar) {
      final mid = _start + _sweep / 2;
      final end = _start + _sweep * t;
      canvas.drawArc(rect, math.min(mid, end), (end - mid).abs(), false, arc);
    } else {
      canvas.drawArc(rect, _start, _sweep * t, false, arc);
    }

    canvas.drawCircle(c, r - 7, Paint()..color = Palette.panelHi);
    canvas.drawCircle(
      c,
      r - 7,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1
        ..color = Palette.stroke,
    );

    final a = _start + _sweep * t;
    final dir = Offset(math.cos(a), math.sin(a));
    canvas.drawLine(
      c + dir * (r - 17),
      c + dir * (r - 9),
      Paint()
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round
        ..color = Palette.text,
    );
  }

  @override
  bool shouldRepaint(_KnobPainter o) =>
      o.t != t || o.color != color || o.bipolar != bipolar;
}

/// Linear fader. [value] is 0..1 (for vertical faders 1 is the top).
class Fader extends StatelessWidget {
  const Fader({
    super.key,
    required this.value,
    required this.onChanged,
    this.axis = Axis.vertical,
    this.color = Palette.accent,
    this.onDoubleTap,
  });

  final double value;
  final ValueChanged<double> onChanged;
  final Axis axis;
  final Color color;
  final VoidCallback? onDoubleTap;

  static const double _pad = 16;

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, box) {
        final vertical = axis == Axis.vertical;
        final length = vertical ? box.maxHeight : box.maxWidth;
        void set(Offset p) {
          final pos = vertical ? p.dy : p.dx;
          final f = ((pos - _pad) / (length - _pad * 2)).clamp(0.0, 1.0).toDouble();
          onChanged(vertical ? 1 - f : f);
        }

        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTapDown: (d) => set(d.localPosition),
          onDoubleTap: onDoubleTap,
          onVerticalDragStart: vertical ? (d) => set(d.localPosition) : null,
          onVerticalDragUpdate: vertical ? (d) => set(d.localPosition) : null,
          onHorizontalDragStart: vertical ? null : (d) => set(d.localPosition),
          onHorizontalDragUpdate: vertical ? null : (d) => set(d.localPosition),
          child: CustomPaint(
            size: Size(box.maxWidth, box.maxHeight),
            painter: _FaderPainter(value, color, vertical),
          ),
        );
      },
    );
  }
}

class _FaderPainter extends CustomPainter {
  _FaderPainter(this.value, this.color, this.vertical);

  final double value;
  final Color color;
  final bool vertical;

  @override
  void paint(Canvas canvas, Size size) {
    const pad = Fader._pad;
    final slot = Paint()..color = const Color(0xFF05070B);
    final tick = Paint()
      ..color = Palette.stroke
      ..strokeWidth = 1;

    if (vertical) {
      final cx = size.width / 2;
      final top = pad;
      final bottom = size.height - pad;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(cx - 3, top, cx + 3, bottom),
          const Radius.circular(3),
        ),
        slot,
      );
      for (var i = 0; i <= 10; i++) {
        final y = top + (bottom - top) * i / 10;
        final w = i % 5 == 0 ? 10.0 : 5.0;
        canvas.drawLine(Offset(cx - 8 - w, y), Offset(cx - 8, y), tick);
        canvas.drawLine(Offset(cx + 8, y), Offset(cx + 8 + w, y), tick);
      }
      final y = bottom - (bottom - top) * value;
      _cap(canvas, Rect.fromCenter(center: Offset(cx, y), width: 40, height: 24));
    } else {
      final cy = size.height / 2;
      final left = pad;
      final right = size.width - pad;
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTRB(left, cy - 3, right, cy + 3),
          const Radius.circular(3),
        ),
        slot,
      );
      for (var i = 0; i <= 10; i++) {
        final x = left + (right - left) * i / 10;
        final h = i % 5 == 0 ? 10.0 : 5.0;
        canvas.drawLine(Offset(x, cy - 8 - h), Offset(x, cy - 8), tick);
        canvas.drawLine(Offset(x, cy + 8), Offset(x, cy + 8 + h), tick);
      }
      final x = left + (right - left) * value;
      _cap(canvas, Rect.fromCenter(center: Offset(x, cy), width: 26, height: 40));
    }
  }

  void _cap(Canvas canvas, Rect r) {
    final rr = RRect.fromRectAndRadius(r, const Radius.circular(5));
    canvas.drawRRect(rr, Paint()..color = const Color(0xFF222C42));
    canvas.drawRRect(
      rr,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 1.2
        ..color = Palette.dim,
    );
    final line = Paint()
      ..color = color
      ..strokeWidth = 2.5
      ..strokeCap = StrokeCap.round;
    if (vertical) {
      canvas.drawLine(Offset(r.left + 6, r.center.dy), Offset(r.right - 6, r.center.dy), line);
    } else {
      canvas.drawLine(Offset(r.center.dx, r.top + 6), Offset(r.center.dx, r.bottom - 6), line);
    }
  }

  @override
  bool shouldRepaint(_FaderPainter o) => o.value != value || o.color != color;
}

/// Segmented LED level meter. [level] is expected in 0..1.
class VuMeter extends StatelessWidget {
  const VuMeter({super.key, required this.level, this.horizontal = false});

  final ValueListenable<double> level;
  final bool horizontal;

  @override
  Widget build(BuildContext context) => SizedBox.expand(
        child: CustomPaint(painter: _VuPainter(level, horizontal)),
      );
}

class _VuPainter extends CustomPainter {
  _VuPainter(this.level, this.horizontal) : super(repaint: level);

  final ValueListenable<double> level;
  final bool horizontal;

  static const int _segments = 16;

  @override
  void paint(Canvas canvas, Size size) {
    final lit = (level.value * 1.8).clamp(0.0, 1.0) * _segments;
    final long = horizontal ? size.width : size.height;
    final cell = long / _segments;
    for (var i = 0; i < _segments; i++) {
      final f = i / _segments;
      final base = f > 0.88
          ? Palette.rec
          : f > 0.7
              ? Palette.accent
              : Palette.ok;
      final on = i < lit;
      final paint = Paint()..color = on ? base : base.withValues(alpha: 0.12);
      final rect = horizontal
          ? Rect.fromLTWH(i * cell + 1, 0, cell - 2, size.height)
          : Rect.fromLTWH(0, size.height - (i + 1) * cell + 1, size.width, cell - 2);
      canvas.drawRRect(RRect.fromRectAndRadius(rect, const Radius.circular(1.5)), paint);
    }
  }

  @override
  bool shouldRepaint(_VuPainter o) => o.horizontal != horizontal;
}
