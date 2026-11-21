/// Plain data types shared by the audio layer and the UI.
library;

enum TempoRange {
  pct8(0.08, '±8%'),
  pct16(0.16, '±16%'),
  pct50(0.50, '±50%');

  const TempoRange(this.fraction, this.label);
  final double fraction;
  final String label;

  TempoRange get next =>
      TempoRange.values[(index + 1) % TempoRange.values.length];
}

enum FxUnit {
  echo('ECHO'),
  reverb('REVERB'),
  flanger('FLANGER');

  const FxUnit(this.label);
  final String label;
}

enum CrossfaderCurve {
  /// Both decks stay at full level around the centre (typical "mix" curve).
  mix('MIX'),

  /// Constant-power blend.
  blend('BLEND'),

  /// Hard cut at the ends – for scratching.
  cut('CUT');

  const CrossfaderCurve(this.label);
  final String label;

  CrossfaderCurve get next =>
      CrossfaderCurve.values[(index + 1) % CrossfaderCurve.values.length];
}

class Track {
  Track({required this.path, required this.title, this.bpm});

  factory Track.fromJson(Map<String, dynamic> json) => Track(
        path: json['path'] as String,
        title: json['title'] as String,
        bpm: (json['bpm'] as num?)?.toDouble(),
      );

  final String path;
  final String title;
  double? bpm;

  Map<String, dynamic> toJson() => {'path': path, 'title': title, 'bpm': bpm};
}
