import 'package:flutter/widgets.dart';

/// HackDJ's look: charcoal-slate surfaces, raised grey hardware buttons,
/// yellow for deck A and sky blue for deck B.
abstract final class Palette {
  static const bg = Color(0xFF23262E);
  static const panel = Color(0xFF2B2E38);
  static const panelHi = Color(0xFF4A4F5B); // raised button face
  static const stroke = Color(0xFF3A3E4A);
  static const text = Color(0xFFF2F4F8);
  static const dim = Color(0xFF9AA0AE);
  static const deckA = Color(0xFFF0C832);
  static const deckB = Color(0xFF06A5E0);
  static const accent = Color(0xFFFB923C);
  static const rec = Color(0xFFEF4444);
  static const ok = Color(0xFF34D399);

  /// Text / icon colour used on top of a solid deck-coloured surface.
  static const onColor = Color(0xFF14161B);
}

TextStyle ts(
  double size, {
  Color color = Palette.text,
  FontWeight weight = FontWeight.w600,
  double spacing = 0.4,
}) =>
    TextStyle(
      fontSize: size,
      color: color,
      fontWeight: weight,
      letterSpacing: spacing,
      height: 1.15,
    );

/// m:ss.s (or -m:ss for remaining time).
String fmtTime(Duration d, {bool tenths = true}) {
  final neg = d.isNegative;
  final ms = d.abs().inMilliseconds;
  final m = ms ~/ 60000;
  final s = (ms ~/ 1000) % 60;
  final t = (ms ~/ 100) % 10;
  final body = '$m:${s.toString().padLeft(2, '0')}${tenths ? '.$t' : ''}';
  return neg ? '-$body' : body;
}
