import 'package:flutter/widgets.dart';

/// HackDJ's own visual identity: deep navy surfaces, cyan for deck A,
/// magenta for deck B, amber accents.
abstract final class Palette {
  static const bg = Color(0xFF080B11);
  static const panel = Color(0xFF111723);
  static const panelHi = Color(0xFF182131);
  static const stroke = Color(0xFF2A3550);
  static const text = Color(0xFFE8ECF4);
  static const dim = Color(0xFF8793AB);
  static const deckA = Color(0xFF22D3EE);
  static const deckB = Color(0xFFF472B6);
  static const accent = Color(0xFFFBBF24);
  static const rec = Color(0xFFEF4444);
  static const ok = Color(0xFF34D399);
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
