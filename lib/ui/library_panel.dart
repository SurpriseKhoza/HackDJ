import 'package:flutter/widgets.dart';

import '../audio/engine.dart';
import '../audio/models.dart';
import 'palette.dart';
import 'widgets/buttons.dart';

/// Slide-up track browser. Tap A / B to load a track onto that deck.
class LibraryPanel extends StatelessWidget {
  const LibraryPanel({super.key, required this.engine, required this.onClose});

  final DjEngine engine;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final lib = engine.library;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFF0E141F),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
        border: Border.all(color: Palette.stroke, width: 1.2),
        boxShadow: const [BoxShadow(color: Color(0xCC000000), blurRadius: 30)],
      ),
      child: ListenableBuilder(
        listenable: lib,
        builder: (context, _) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Text('LIBRARY', style: ts(16, weight: FontWeight.w800)),
                const SizedBox(width: 10),
                Text('${lib.tracks.length} tracks', style: ts(12, color: Palette.dim)),
                const Spacer(),
                SizedBox(
                  width: 130,
                  child: DjButton(
                    label: lib.importing ? 'IMPORTING…' : '+ IMPORT',
                    color: Palette.ok,
                    onTap: lib.importing ? null : lib.importFiles,
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(width: 80, child: DjButton(label: 'CLOSE', onTap: onClose)),
              ],
            ),
            const SizedBox(height: 10),
            Expanded(
              child: lib.tracks.isEmpty
                  ? Center(
                      child: Text(
                        'No tracks yet. Tap + IMPORT and pick MP3, WAV, FLAC, OGG, M4A or AAC files.',
                        style: ts(13, color: Palette.dim),
                      ),
                    )
                  : ListView.builder(
                      itemCount: lib.tracks.length,
                      itemExtent: 46,
                      itemBuilder: (context, i) => _Row(
                        track: lib.tracks[i],
                        index: i,
                        onA: () {
                          engine.deckA.load(lib.tracks[i]);
                          onClose();
                        },
                        onB: () {
                          engine.deckB.load(lib.tracks[i]);
                          onClose();
                        },
                        onRemove: () => lib.remove(lib.tracks[i]),
                      ),
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Row extends StatelessWidget {
  const _Row({
    required this.track,
    required this.index,
    required this.onA,
    required this.onB,
    required this.onRemove,
  });

  final Track track;
  final int index;
  final VoidCallback onA;
  final VoidCallback onB;
  final VoidCallback onRemove;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 4),
      padding: const EdgeInsets.symmetric(horizontal: 10),
      decoration: BoxDecoration(
        color: index.isEven ? Palette.panel : const Color(0xFF0E141F),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Row(
        children: [
          SizedBox(width: 34, child: Text('${index + 1}', style: ts(12, color: Palette.dim))),
          Expanded(
            child: Text(
              track.title,
              style: ts(14),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
          SizedBox(
            width: 80,
            child: Text(
              track.bpm == null ? '– BPM' : '${track.bpm!.toStringAsFixed(1)} BPM',
              style: ts(12, color: Palette.dim),
            ),
          ),
          SizedBox(
            width: 56,
            child: DjButton(label: 'A', height: 32, color: Palette.deckA, onTap: onA),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 56,
            child: DjButton(label: 'B', height: 32, color: Palette.deckB, onTap: onB),
          ),
          const SizedBox(width: 8),
          SizedBox(
            width: 40,
            child: DjButton(label: '✕', height: 32, color: Palette.rec, onLongPress: onRemove),
          ),
        ],
      ),
    );
  }
}
