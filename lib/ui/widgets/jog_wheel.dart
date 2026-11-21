import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../audio/deck.dart';
import '../palette.dart';

/// Platter-style jog wheel. The marker rotates at 33⅓ rpm of *track time*, so it
/// speeds up / slows down with the tempo. Touch to hold the record, drag to
/// scrub (and "scratch" by seeking).
class JogWheel extends StatefulWidget {
  const JogWheel({super.key, required this.deck, required this.color, required this.size});

  final Deck deck;
  final Color color;
  final double size;

  @override
  State<JogWheel> createState() => _JogWheelState();
}

class _JogWheelState extends State<JogWheel> {
  static const double _revPerSecond = 100 / 60 / 3; // 33⅓ rpm

  double _last = 0;

  double _angle(Offset p) {
    final c = Offset(widget.size / 2, widget.size / 2);
    return math.atan2(p.dy - c.dy, p.dx - c.dx);
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: widget.size,
      height: widget.size,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onPanStart: (d) {
          _last = _angle(d.localPosition);
          widget.deck.scratchStart();
        },
        onPanUpdate: (d) {
          final a = _angle(d.localPosition);
          var delta = a - _last;
          if (delta > math.pi) delta -= 2 * math.pi;
          if (delta < -math.pi) delta += 2 * math.pi;
          _last = a;
          widget.deck.scratchMove(delta / (2 * math.pi) / _revPerSecond);
        },
        onPanEnd: (_) => widget.deck.scratchEnd(),
        onPanCancel: widget.deck.scratchEnd,
        child: CustomPaint(
          painter: _JogPainter(widget.deck, widget.color, _revPerSecond),
        ),
      ),
    );
  }
}

class _JogPainter extends CustomPainter {
  _JogPainter(this.deck, this.color, this.revPerSecond)
      : super(repaint: Listenable.merge([deck.position, deck]));

  final Deck deck;
  final Color color;
  final double revPerSecond;

  @override
  void paint(Canvas canvas, Size size) {
    final c = size.center(Offset.zero);
    final r = size.shortestSide / 2 - 2;

    // Outer glow ring (brighter while playing).
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 5
        ..color = color.withValues(alpha: deck.playing ? 0.9 : 0.35),
    );

    // Platter body.
    canvas.drawCircle(c, r - 6, Paint()..color = const Color(0xFF0D121B));

    // Vinyl grooves.
    final groove = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..color = const Color(0xFF1A2232);
    for (var g = r - 14; g > r * 0.42; g -= 7) {
      canvas.drawCircle(c, g, groove);
    }

    // Rotating label + marker.
    final turns = deck.position.value.inMilliseconds / 1000 * revPerSecond;
    final angle = turns * 2 * math.pi;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    canvas.drawCircle(Offset.zero, r * 0.36, Paint()..color = color.withValues(alpha: 0.85));
    canvas.drawCircle(Offset.zero, r * 0.07, Paint()..color = const Color(0xFF0D121B));
    canvas.drawLine(
      Offset(0, -r * 0.40),
      Offset(0, -(r - 10)),
      Paint()
        ..strokeWidth = 4
        ..strokeCap = StrokeCap.round
        ..color = Palette.text,
    );
    canvas.restore();
  }

  @override
  bool shouldRepaint(_JogPainter o) => o.color != color;
}
