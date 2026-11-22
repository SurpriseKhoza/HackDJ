import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../palette.dart';

enum PIcon { plus, grid, loop, mixer, wave, menu, search, up, close }

/// Round outlined icon button (the style used for the view switches).
/// Shows either a drawn [icon] or an italic text [label].
class CircleButton extends StatelessWidget {
  const CircleButton({
    super.key,
    this.icon,
    this.label,
    this.onTap,
    this.active = false,
    this.size = 52,
    this.color = Palette.text,
  });

  final PIcon? icon;
  final String? label;
  final VoidCallback? onTap;
  final bool active;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final i = icon;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        width: size,
        height: size,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: active ? Palette.panelHi : const Color(0x33000000),
          border: Border.all(color: Palette.text.withValues(alpha: 0.9), width: 1.6),
        ),
        child: i != null
            ? CustomPaint(
                size: Size.square(size * 0.5),
                painter: _IconPainter(i, color),
              )
            : Text(
                label ?? '',
                style: ts(size * 0.3, color: color, weight: FontWeight.w800)
                    .copyWith(fontStyle: FontStyle.italic),
              ),
      ),
    );
  }
}

class _IconPainter extends CustomPainter {
  _IconPainter(this.icon, this.color);

  final PIcon icon;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final s = size.width;
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.1
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..color = color;
    final thick = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = s * 0.2
      ..strokeCap = StrokeCap.round
      ..color = color;
    final fill = Paint()..color = color;

    switch (icon) {
      case PIcon.plus:
        canvas.drawLine(Offset(s * 0.5, s * 0.08), Offset(s * 0.5, s * 0.92), thick);
        canvas.drawLine(Offset(s * 0.08, s * 0.5), Offset(s * 0.92, s * 0.5), thick);
      case PIcon.grid:
        for (var r = 0; r < 3; r++) {
          for (var c = 0; c < 3; c++) {
            canvas.drawRRect(
              RRect.fromRectAndRadius(
                Rect.fromLTWH(s * (0.02 + 0.35 * c), s * (0.02 + 0.35 * r), s * 0.27, s * 0.27),
                const Radius.circular(2),
              ),
              fill,
            );
          }
        }
      case PIcon.loop:
        final centre = Offset(s / 2, s / 2);
        final radius = s * 0.36;
        final rect = Rect.fromCircle(center: centre, radius: radius);
        canvas.drawArc(rect, -math.pi * 0.15, math.pi * 0.75, false, line);
        canvas.drawArc(rect, math.pi * 0.85, math.pi * 0.75, false, line);
        for (final end in const [0.6, 1.6]) {
          final a = math.pi * end;
          final tip = centre + Offset(math.cos(a), math.sin(a)) * radius;
          final dir = a + math.pi / 2;
          final len = s * 0.24;
          final path = Path()
            ..moveTo(tip.dx + math.cos(dir) * len * 0.5, tip.dy + math.sin(dir) * len * 0.5)
            ..lineTo(
              tip.dx + math.cos(dir + 2.2) * len,
              tip.dy + math.sin(dir + 2.2) * len,
            )
            ..lineTo(
              tip.dx + math.cos(dir - 2.2) * len,
              tip.dy + math.sin(dir - 2.2) * len,
            )
            ..close();
          canvas.drawPath(path, fill);
        }
      case PIcon.mixer:
        canvas.drawLine(Offset(s * 0.05, s * 0.3), Offset(s * 0.95, s * 0.3), line);
        canvas.drawLine(Offset(s * 0.05, s * 0.7), Offset(s * 0.95, s * 0.7), line);
        canvas.drawRect(Rect.fromLTWH(s * 0.28, s * 0.14, s * 0.2, s * 0.32), fill);
        canvas.drawRect(Rect.fromLTWH(s * 0.58, s * 0.54, s * 0.2, s * 0.32), fill);
      case PIcon.wave:
        const heights = [0.3, 0.7, 0.5, 0.95, 0.4, 0.65];
        for (var i = 0; i < heights.length; i++) {
          final x = s * (0.08 + i * 0.168);
          final h = s * heights[i];
          canvas.drawLine(Offset(x, (s - h) / 2), Offset(x, (s + h) / 2), line);
        }
      case PIcon.menu:
        for (final y in const [0.22, 0.5, 0.78]) {
          canvas.drawLine(Offset(s * 0.08, s * y), Offset(s * 0.92, s * y), line);
        }
      case PIcon.search:
        canvas.drawCircle(Offset(s * 0.42, s * 0.42), s * 0.3, line);
        canvas.drawLine(Offset(s * 0.64, s * 0.64), Offset(s * 0.92, s * 0.92), line);
      case PIcon.up:
        canvas.drawLine(Offset(s * 0.5, s * 0.88), Offset(s * 0.5, s * 0.14), thick);
        canvas.drawLine(Offset(s * 0.16, s * 0.48), Offset(s * 0.5, s * 0.14), thick);
        canvas.drawLine(Offset(s * 0.84, s * 0.48), Offset(s * 0.5, s * 0.14), thick);
      case PIcon.close:
        canvas.drawLine(Offset(s * 0.15, s * 0.15), Offset(s * 0.85, s * 0.85), line);
        canvas.drawLine(Offset(s * 0.85, s * 0.15), Offset(s * 0.15, s * 0.85), line);
    }
  }

  @override
  bool shouldRepaint(_IconPainter o) => o.icon != icon || o.color != color;
}
