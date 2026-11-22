import 'package:flutter/widgets.dart';

import '../palette.dart';

/// Raised hardware-style button: a grey gradient face with a dark edge, and a
/// solid [color] fill with dark text when [active]. Supports tap, long-press
/// and press-and-hold (via [onPressStart] / [onPressEnd]).
///
/// A custom [child] is drawn as given, so on an active button it should use
/// [Palette.onColor] to stay readable on the solid fill.
class DjButton extends StatelessWidget {
  const DjButton({
    super.key,
    this.label = '',
    this.child,
    this.onTap,
    this.onLongPress,
    this.onPressStart,
    this.onPressEnd,
    this.active = false,
    this.color = Palette.accent,
    this.height = 34,
    this.fontSize = 12,
  });

  final String label;
  final Widget? child;
  final VoidCallback? onTap;
  final VoidCallback? onLongPress;
  final VoidCallback? onPressStart;
  final VoidCallback? onPressEnd;
  final bool active;
  final Color color;
  final double height;
  final double fontSize;

  @override
  Widget build(BuildContext context) {
    final fg = active ? Palette.onColor : Palette.text;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      onLongPress: onLongPress,
      onTapDown: onPressStart == null ? null : (_) => onPressStart!(),
      onTapUp: onPressEnd == null ? null : (_) => onPressEnd!(),
      onTapCancel: onPressEnd,
      child: Container(
        height: height,
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: active ? color : null,
          gradient: active
              ? null
              : const LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [Color(0xFF5A5F6B), Palette.panelHi],
                ),
          borderRadius: BorderRadius.circular(6),
          border: Border.all(
            color: active ? color : const Color(0xFF2A2D35),
            width: 1,
          ),
          boxShadow: const [
            BoxShadow(color: Color(0x66000000), blurRadius: 3, offset: Offset(0, 1)),
          ],
        ),
        child: child ??
            Text(label, style: ts(fontSize, color: fg), maxLines: 1),
      ),
    );
  }
}

enum Glyph { play, pause }

/// Vector play / pause symbols (no icon font, no emoji surprises).
class GlyphIcon extends StatelessWidget {
  const GlyphIcon(this.glyph, {super.key, this.color = Palette.text, this.size = 22});

  final Glyph glyph;
  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => CustomPaint(
        size: Size.square(size),
        painter: _GlyphPainter(glyph, color),
      );
}

class _GlyphPainter extends CustomPainter {
  _GlyphPainter(this.glyph, this.color);

  final Glyph glyph;
  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()..color = color;
    switch (glyph) {
      case Glyph.play:
        final path = Path()
          ..moveTo(size.width * 0.22, size.height * 0.12)
          ..lineTo(size.width * 0.88, size.height * 0.5)
          ..lineTo(size.width * 0.22, size.height * 0.88)
          ..close();
        canvas.drawPath(path, paint);
      case Glyph.pause:
        final w = size.width * 0.26;
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.16, size.height * 0.12, w, size.height * 0.76),
            const Radius.circular(2),
          ),
          paint,
        );
        canvas.drawRRect(
          RRect.fromRectAndRadius(
            Rect.fromLTWH(size.width * 0.58, size.height * 0.12, w, size.height * 0.76),
            const Radius.circular(2),
          ),
          paint,
        );
    }
  }

  @override
  bool shouldRepaint(_GlyphPainter old) => old.glyph != glyph || old.color != color;
}
