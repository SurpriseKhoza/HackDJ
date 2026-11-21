import 'package:flutter/widgets.dart';

import '../audio/deck.dart';
import '../audio/engine.dart';
import '../audio/models.dart';
import 'palette.dart';
import 'widgets/buttons.dart';
import 'widgets/controls.dart';
import 'widgets/jog_wheel.dart';
import 'widgets/waveforms.dart';

const _cueColors = [
  Color(0xFFF87171),
  Color(0xFF34D399),
  Color(0xFFFBBF24),
  Color(0xFFA78BFA),
];

/// One full deck: header, waveforms, jog wheel, transport, tempo, loops,
/// hot cues and FX.
class DeckPanel extends StatelessWidget {
  const DeckPanel({
    super.key,
    required this.deck,
    required this.other,
    required this.color,
    required this.onLoad,
  });

  final Deck deck;
  final Deck other;
  final Color color;
  final VoidCallback onLoad;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.45), width: 1.2),
      ),
      child: ListenableBuilder(
        listenable: deck,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _header(),
            const SizedBox(height: 6),
            SizedBox(height: 30, child: OverviewWaveform(deck: deck, color: color)),
            const SizedBox(height: 6),
            SizedBox(height: 84, child: ScrollingWaveform(deck: deck, color: color)),
            const SizedBox(height: 8),
            Expanded(child: _mainRow()),
            const SizedBox(height: 8),
            _hotCues(),
            const SizedBox(height: 6),
            _fxRow(),
          ],
        ),
      ),
    );
  }

  // ------------------------------------------------------------------ header
  Widget _header() {
    final t = deck.track;
    return SizedBox(
      height: 44,
      child: Row(
        children: [
          GestureDetector(
            onTap: onLoad,
            behavior: HitTestBehavior.opaque,
            child: Container(
              width: 40,
              height: 40,
              alignment: Alignment.center,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: color, width: 1.4),
              ),
              child: Text(deck.id, style: ts(20, color: color, weight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  deck.loading
                      ? 'Loading…'
                      : (t?.title ?? 'Tap A / B to load a track'),
                  style: ts(14),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 3),
                Text(
                  deck.error ??
                      (deck.bpmAnalysing
                          ? 'Analysing BPM…'
                          : deck.bpm > 0
                              ? '${deck.currentBpm.toStringAsFixed(1)} BPM'
                              : 'BPM –  (tap TAP to set)'),
                  style: ts(11, color: deck.error != null ? Palette.rec : Palette.dim),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
          ValueListenableBuilder<Duration>(
            valueListenable: deck.position,
            builder: (context, pos, _) => Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(fmtTime(pos), style: ts(20, color: color, weight: FontWeight.w700)),
                Text(
                  fmtTime(deck.duration - pos, tenths: false).replaceFirst(RegExp('^'), '-'),
                  style: ts(11, color: Palette.dim),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------- main row
  Widget _mainRow() {
    return LayoutBuilder(
      builder: (context, box) {
        final jog = box.maxHeight.clamp(120.0, 230.0).toDouble();
        return Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            JogWheel(deck: deck, color: color, size: jog),
            const SizedBox(width: 10),
            Expanded(child: _controls()),
            const SizedBox(width: 10),
            SizedBox(width: 58, child: _tempo()),
          ],
        );
      },
    );
  }

  Widget _controls() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Expanded(
              flex: 3,
              child: DjButton(
                height: 54,
                color: color,
                active: deck.playing,
                onTap: deck.togglePlay,
                child: GlyphIcon(
                  deck.playing ? Glyph.pause : Glyph.play,
                  color: deck.playing ? color : Palette.text,
                  size: 26,
                ),
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              flex: 2,
              child: DjButton(
                height: 54,
                label: 'CUE',
                fontSize: 14,
                color: Palette.accent,
                onTap: deck.cuePressed,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: DjButton(label: 'SYNC', color: color, onTap: () => deck.syncTo(other)),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: DjButton(
                label: 'KEY',
                color: color,
                active: deck.keyLock,
                onTap: deck.toggleKeyLock,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(child: DjButton(label: 'TAP', onTap: deck.tapTempo)),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: DjButton(
                label: '◀ BEND',
                fontSize: 10,
                onPressStart: () => deck.bendStart(-1),
                onPressEnd: deck.bendEnd,
              ),
            ),
            const SizedBox(width: 6),
            Expanded(
              child: DjButton(
                label: 'BEND ▶',
                fontSize: 10,
                onPressStart: () => deck.bendStart(1),
                onPressEnd: deck.bendEnd,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(child: DjButton(label: 'IN', onTap: deck.setLoopIn)),
            const SizedBox(width: 6),
            Expanded(child: DjButton(label: 'OUT', onTap: deck.setLoopOut)),
            const SizedBox(width: 6),
            Expanded(
              child: DjButton(
                label: 'LOOP',
                active: deck.loopActive,
                color: Palette.accent,
                onTap: deck.toggleLoop,
              ),
            ),
          ],
        ),
        const SizedBox(height: 6),
        Row(
          children: [
            for (final beats in const [1.0, 2.0, 4.0, 8.0]) ...[
              Expanded(
                child: DjButton(
                  label: beats == beats.roundToDouble()
                      ? '${beats.round()}'
                      : '$beats',
                  fontSize: 11,
                  onTap: () => deck.beatLoop(beats),
                ),
              ),
              if (beats != 8.0) const SizedBox(width: 4),
            ],
          ],
        ),
      ],
    );
  }

  Widget _tempo() {
    final pct = deck.tempoPercent;
    return Column(
      children: [
        DjButton(label: deck.range.label, fontSize: 10, height: 26, onTap: deck.cycleRange),
        const SizedBox(height: 4),
        Expanded(
          child: Fader(
            value: (deck.tempo + 1) / 2,
            color: color,
            onChanged: (v) => deck.setTempo(v * 2 - 1),
            onDoubleTap: () => deck.setTempo(0),
          ),
        ),
        Text(
          '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(1)}%',
          style: ts(11, color: Palette.dim),
        ),
      ],
    );
  }

  // ---------------------------------------------------------------- hot cues
  Widget _hotCues() {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          for (var i = 0; i < 4; i++) ...[
            Expanded(
              child: DjButton(
                label: deck.hotCues[i] == null ? '${i + 1}' : fmtTime(deck.hotCues[i]!, tenths: false),
                color: _cueColors[i],
                active: deck.hotCues[i] != null,
                onTap: () => deck.hotCue(i),
                onLongPress: () => deck.clearHotCue(i),
              ),
            ),
            if (i < 3) const SizedBox(width: 6),
          ],
        ],
      ),
    );
  }

  // --------------------------------------------------------------------- fx
  Widget _fxRow() {
    return SizedBox(
      height: 36,
      child: Row(
        children: [
          for (final u in FxUnit.values) ...[
            Expanded(
              child: DjButton(
                label: u.label,
                fontSize: 11,
                color: color,
                active: deck.fxOn[u] ?? false,
                onTap: () => deck.toggleFx(u),
              ),
            ),
            const SizedBox(width: 6),
          ],
          SizedBox(
            width: 120,
            child: Fader(
              axis: Axis.horizontal,
              value: deck.fxAmount,
              color: color,
              onChanged: deck.setFxAmount,
            ),
          ),
        ],
      ),
    );
  }
}

/// Convenience for the screen: the engine's two decks with their colours.
extension DeckColors on DjEngine {
  Color colorOf(Deck d) => identical(d, deckA) ? Palette.deckA : Palette.deckB;
}
