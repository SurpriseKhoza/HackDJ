import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../audio/deck.dart';
import '../palette.dart';

/// Platter-style jog wheel: a solid deck-coloured disc with a darker centre
/// label. The marker rotates at 33⅓ rpm of *track time*, so it speeds up /
/// slows down with the tempo. Touch to hold the record, drag to scrub and
/// scratch.
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

    // Solid platter with a thin black rim; dimmer while the deck is stopped.
    canvas.drawCircle(
      c,
      r,
      Paint()..color = color.withValues(alpha: deck.playing ? 1 : 0.85),
    );
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2.5
        ..color = const Color(0xFF000000),
    );

    // Rotating centre label with a cluster of white dots, so the spin is easy
    // to see.
    final turns = deck.position.value.inMilliseconds / 1000 * revPerSecond;
    final angle = turns * 2 * math.pi;
    final label = Color.lerp(color, const Color(0xFF000000), 0.62)!;
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    canvas.drawCircle(Offset.zero, r * 0.36, Paint()..color = label);
    final dot = Paint()..color = Palette.text;
    final dr = r * 0.035;
    for (final p in const [
      Offset(-0.16, -0.12),
      Offset(-0.06, -0.02),
      Offset(0.04, -0.12),
      Offset(0.12, 0.0),
      Offset(0.02, 0.10),
    ]) {
      canvas.drawOval(
        Rect.fromCenter(
          center: Offset(p.dx * r, p.dy * r),
          width: dr * 2,
          height: dr * 2.6,
        ),
        dot,
      );
    }
    canvas.restore();
  }

  @override
  bool shouldRepaint(_JogPainter o) => o.color != color;
}
