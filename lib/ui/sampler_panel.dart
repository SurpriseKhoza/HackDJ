import 'package:flutter/widgets.dart';

import '../audio/sampler.dart';
import 'palette.dart';
import 'widgets/buttons.dart';
import 'widgets/controls.dart';

/// Bottom sampler strip: 8 pads (tap = trigger, long-press = load your own
/// sound), loop-latch mode and a volume knob.
class SamplerPanel extends StatelessWidget {
  const SamplerPanel({super.key, required this.sampler});

  final Sampler sampler;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: Palette.panel,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Palette.stroke, width: 1.2),
      ),
      child: ListenableBuilder(
        listenable: sampler,
        builder: (context, _) => Row(
          children: [
            SizedBox(
              width: 92,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text('SAMPLER', style: ts(12, color: Palette.dim)),
                  const SizedBox(height: 6),
                  DjButton(
                    label: 'LOOP',
                    fontSize: 11,
                    height: 28,
                    active: sampler.loopMode,
                    onTap: sampler.toggleLoopMode,
                  ),
                ],
              ),
            ),
            const SizedBox(width: 10),
            for (var i = 0; i < sampler.pads.length; i++) ...[
              Expanded(child: _PadButton(sampler: sampler, index: i)),
              const SizedBox(width: 8),
            ],
            Knob(
              label: 'VOL',
              value: sampler.volume,
              min: 0,
              max: 1,
              resetTo: 0.9,
              onChanged: sampler.setVolume,
            ),
          ],
        ),
      ),
    );
  }
}

class _PadButton extends StatelessWidget {
  const _PadButton({required this.sampler, required this.index});

  final Sampler sampler;
  final int index;

  @override
  Widget build(BuildContext context) {
    final pad = sampler.pads[index];
    return GestureDetector(
      onLongPress: () => sampler.loadCustom(index),
      // Listener fires on touch-down with no tap delay: pads must feel instant.
      child: Listener(
        onPointerDown: (_) => sampler.trigger(index),
        child: ValueListenableBuilder<int>(
          valueListenable: pad.hits,
          builder: (context, hits, _) {
            final latched = pad.loopHandle != null && sampler.loopMode;
            return AnimatedContainer(
              duration: const Duration(milliseconds: 140),
              decoration: BoxDecoration(
                color: pad.color.withValues(alpha: hits.isOdd || latched ? 0.55 : 0.16),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: pad.color, width: 1.4),
              ),
              alignment: Alignment.center,
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('${index + 1}', style: ts(18, color: pad.color, weight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(pad.name, style: ts(10, color: Palette.text), maxLines: 1),
                  if (pad.custom) Text('CUSTOM', style: ts(8, color: Palette.dim)),
                ],
              ),
            );
          },
        ),
      ),
    );
  }
}
