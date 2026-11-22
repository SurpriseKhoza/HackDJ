import 'package:flutter/widgets.dart';

import '../audio/deck.dart';
import '../audio/engine.dart';
import 'palette.dart';
import 'widgets/buttons.dart';
import 'widgets/controls.dart';

/// Centre mixer: two channel strips (trim, 3-band EQ, DJ filter, level meter,
/// channel fader) and the crossfader section.
class MixerPanel extends StatelessWidget {
  const MixerPanel({super.key, required this.engine});

  final DjEngine engine;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.stroke, width: 1.2),
      ),
      child: Column(
        children: [
          Expanded(
            child: Row(
              children: [
                Expanded(child: _Strip(deck: engine.deckA, color: Palette.deckA)),
                const SizedBox(width: 6),
                Expanded(child: _Strip(deck: engine.deckB, color: Palette.deckB)),
              ],
            ),
          ),
          const SizedBox(height: 8),
          _crossfader(),
        ],
      ),
    );
  }

  Widget _crossfader() {
    return ListenableBuilder(
      listenable: engine,
      builder: (context, _) => Column(
        children: [
          Row(
            children: [
              Text('A', style: ts(13, color: Palette.deckA, weight: FontWeight.w800)),
              const Spacer(),
              DjButton(
                label: engine.curve.label,
                fontSize: 10,
                height: 24,
                onTap: engine.cycleCurve,
              ),
              const Spacer(),
              Text('B', style: ts(13, color: Palette.deckB, weight: FontWeight.w800)),
            ],
          ),
          SizedBox(
            height: 46,
            child: Fader(
              axis: Axis.horizontal,
              value: engine.crossfader,
              onChanged: (v) {
                engine.cancelAutoFade();
                engine.setCrossfader(v);
              },
              onDoubleTap: () => engine.setCrossfader(0.5),
            ),
          ),
          Row(
            children: [
              Expanded(
                child: DjButton(
                  label: 'A ▶ B',
                  fontSize: 11,
                  height: 28,
                  color: Palette.accent,
                  onTap: () => engine.autoFade(toB: true),
                ),
              ),
              const SizedBox(width: 6),
              Expanded(
                child: DjButton(
                  label: 'B ▶ A',
                  fontSize: 11,
                  height: 28,
                  color: Palette.accent,
                  onTap: () => engine.autoFade(toB: false),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _Strip extends StatelessWidget {
  const _Strip({required this.deck, required this.color});

  final Deck deck;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: deck,
      builder: (context, _) => Column(
        children: [
          Knob(label: 'TRIM', value: deck.trim, color: color, onChanged: deck.setTrim),
          const SizedBox(height: 4),
          Knob(
            label: 'HI',
            value: deck.eqHigh,
            color: color,
            onChanged: (v) => deck.setEq(high: v),
          ),
          const SizedBox(height: 4),
          Knob(
            label: 'MID',
            value: deck.eqMid,
            color: color,
            onChanged: (v) => deck.setEq(mid: v),
          ),
          const SizedBox(height: 4),
          Knob(
            label: 'LOW',
            value: deck.eqLow,
            color: color,
            onChanged: (v) => deck.setEq(low: v),
          ),
          const SizedBox(height: 4),
          Knob(label: 'FILTER', value: deck.filter, color: Palette.accent, onChanged: deck.setFilter),
          const SizedBox(height: 6),
          Expanded(
            child: Row(
              children: [
                SizedBox(width: 10, child: VuMeter(level: deck.level)),
                const SizedBox(width: 4),
                Expanded(
                  child: Fader(
                    value: deck.fader,
                    color: color,
                    onChanged: deck.setFader,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
