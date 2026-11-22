import 'package:flutter/widgets.dart';

import '../audio/engine.dart';
import 'deck_panel.dart';
import 'library_panel.dart';
import 'mixer_panel.dart';
import 'palette.dart';
import 'sampler_panel.dart';
import 'widgets/buttons.dart';
import 'widgets/controls.dart';

/// The whole UI is laid out on a fixed 1280x720 landscape canvas and scaled to
/// fit the screen, like a hardware controller: every device gets the same
/// layout and hit targets stay proportional.
class DjScreen extends StatefulWidget {
  const DjScreen({super.key});

  @override
  State<DjScreen> createState() => _DjScreenState();
}

class _DjScreenState extends State<DjScreen> {
  static const double _w = 1280;
  static const double _h = 720;
  static const double _libraryHeight = 420;

  final DjEngine engine = DjEngine.instance;
  bool _libraryOpen = false;

  void _setLibrary(bool open) => setState(() => _libraryOpen = open);

  @override
  Widget build(BuildContext context) {
    return ColoredBox(
      color: Palette.bg,
      child: SafeArea(
        child: FittedBox(
          fit: BoxFit.contain,
          child: SizedBox(
            width: _w,
            height: _h,
            child: Stack(
              children: [
                Padding(
                  padding: const EdgeInsets.all(8),
                  child: Column(
                    children: [
                      _TopBar(engine: engine, onLibrary: () => _setLibrary(!_libraryOpen)),
                      const SizedBox(height: 8),
                      Expanded(
                        child: Row(
                          children: [
                            Expanded(
                              flex: 52,
                              child: DeckPanel(
                                deck: engine.deckA,
                                other: engine.deckB,
                                color: Palette.deckA,
                                onLoad: () => _setLibrary(true),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Expanded(flex: 24, child: MixerPanel(engine: engine)),
                            const SizedBox(width: 8),
                            Expanded(
                              flex: 52,
                              child: DeckPanel(
                                deck: engine.deckB,
                                other: engine.deckA,
                                color: Palette.deckB,
                                onLoad: () => _setLibrary(true),
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 8),
                      SizedBox(height: 112, child: SamplerPanel(sampler: engine.sampler)),
                    ],
                  ),
                ),
                AnimatedPositioned(
                  duration: const Duration(milliseconds: 260),
                  curve: Curves.easeOutCubic,
                  left: 0,
                  right: 0,
                  bottom: _libraryOpen ? 0 : -_libraryHeight - 40,
                  height: _libraryHeight,
                  child: LibraryPanel(engine: engine, onClose: () => _setLibrary(false)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _TopBar extends StatelessWidget {
  const _TopBar({required this.engine, required this.onLibrary});

  final DjEngine engine;
  final VoidCallback onLibrary;

  @override
  Widget build(BuildContext context) {
    final rec = engine.recorder;
    return SizedBox(
      height: 46,
      child: Row(
        children: [
          Text('HACK', style: ts(22, weight: FontWeight.w900, spacing: 2)),
          Text('DJ', style: ts(22, color: Palette.accent, weight: FontWeight.w900, spacing: 2)),
          const SizedBox(width: 18),
          SizedBox(width: 130, child: DjButton(label: 'LIBRARY', onTap: onLibrary)),
          const Spacer(),
          ListenableBuilder(
            listenable: rec,
            builder: (context, _) => Row(
              children: [
                if (!rec.recording && rec.lastFile != null) ...[
                  SizedBox(
                    width: 110,
                    child: DjButton(label: 'EXPORT WAV', fontSize: 11, onTap: rec.exportLast),
                  ),
                  const SizedBox(width: 8),
                ],
                SizedBox(
                  width: 130,
                  child: DjButton(
                    color: Palette.rec,
                    active: rec.recording,
                    label: rec.recording ? 'REC ${_mmss(rec.elapsed)}' : 'REC',
                    onTap: rec.recording ? rec.stop : rec.start,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 16),
          SizedBox(width: 160, height: 14, child: VuMeter(level: engine.masterLevel, horizontal: true)),
          const SizedBox(width: 8),
          ListenableBuilder(
            listenable: engine,
            builder: (context, _) => Knob(
              label: 'MASTER',
              size: 34,
              min: 0,
              max: 1,
              resetTo: 0.85,
              value: engine.masterVolume,
              onChanged: engine.setMasterVolume,
            ),
          ),
        ],
      ),
    );
  }

  static String _mmss(Duration d) {
    final m = d.inMinutes;
    final s = d.inSeconds % 60;
    return '$m:${s.toString().padLeft(2, '0')}';
  }
}
