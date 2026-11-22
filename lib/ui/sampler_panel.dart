import 'dart:async';

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

class _PadButton extends StatefulWidget {
  const _PadButton({required this.sampler, required this.index});

  final Sampler sampler;
  final int index;

  @override
  State<_PadButton> createState() => _PadButtonState();
}

class _PadButtonState extends State<_PadButton> {
  bool _flash = false;
  Timer? _timer;

  Pad get _pad => widget.sampler.pads[widget.index];

  void _hit() {
    widget.sampler.trigger(widget.index);
    _timer?.cancel();
    setState(() => _flash = true);
    _timer = Timer(const Duration(milliseconds: 120), () {
      if (mounted) setState(() => _flash = false);
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = _pad;
    final lit = _flash || (widget.sampler.loopMode && widget.sampler.isLatched(pad));
    return GestureDetector(
      onLongPress: () => widget.sampler.loadCustom(widget.index),
      // Listener fires on touch-down with no tap delay: pads must feel instant.
      child: Listener(
        onPointerDown: (_) => _hit(),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 90),
          decoration: BoxDecoration(
            color: pad.color.withValues(alpha: lit ? 0.6 : 0.16),
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: pad.color, width: 1.4),
            boxShadow: lit
                ? [BoxShadow(color: pad.color.withValues(alpha: 0.5), blurRadius: 14)]
                : null,
          ),
          alignment: Alignment.center,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${widget.index + 1}',
                  style: ts(18, color: pad.color, weight: FontWeight.w800)),
              const SizedBox(height: 2),
              Text(pad.name, style: ts(10), maxLines: 1),
              if (pad.custom) Text('CUSTOM', style: ts(8, color: Palette.dim)),
            ],
          ),
        ),
      ),
    );
  }
}
