# HackDJ

A dual-deck DJ app with a hardware-style workflow: two decks with waveforms and jog wheels, a
channel mixer with EQ and filters, a crossfader, an FX section, an 8-pad sampler and one-tap
recording of your mix. Original design and code; built on the open-source
[SoLoud](https://solhsa.com/soloud/) engine through
[`flutter_soloud`](https://pub.dev/packages/flutter_soloud).

- **`main`** — Flutter (this branch)
- **`react-native`** — React Native (planned, same feature set, same layout)

Package / bundle id: **`io.surprise.dj`**

## Getting started

```bash
git clone https://github.com/SurpriseKhoza/HackDJ.git && cd HackDJ
./scripts/bootstrap.sh      # flutter create --org io.surprise --project-name dj . && flutter pub get
flutter analyze
flutter test
flutter run                 # phone or tablet in landscape
```

The native folders (`android/`, `ios/`, …) are generated rather than committed so they always
match your installed Flutter version. `--org io.surprise --project-name dj` produces the
`io.surprise.dj` application id and bundle id.

Web is not supported by this build (the SoLoud web build needs WASM and cross-origin isolation).

## Features

| Area | What you get |
|---|---|
| Decks (×2) | Play/pause, CDJ-style CUE, 4 hot cues (long-press clears), overview + scrolling waveform, jog wheel scrub, pitch bend |
| Tempo | ±8 / ±16 / ±50 % range, SYNC to the other deck, key lock, TAP tempo, approximate auto BPM |
| Loops | Manual IN / OUT, one-tap 1 / 2 / 4 / 8-beat loops |
| Mixer | Trim, 3-band EQ (with kill), one-knob DJ filter (low-pass ↔ high-pass), channel faders, LED meters |
| Crossfader | MIX / BLEND / CUT curves, one-tap A→B and B→A auto-fade |
| FX | Echo (beat-synced), reverb, flanger per deck with a wet/dry fader |
| Sampler | 8 synthesised pads (no bundled assets), loop-latch mode, long-press a pad to load your own sound |
| Recording | Records the master mix to 16-bit WAV, with export |
| Library | Import MP3 / WAV / FLAC / OGG / M4A / AAC, persistent, per-track BPM |
| Master | Volume and a safety limiter |

## Architecture

```
lib/
  audio/
    engine.dart    DjEngine: SoLoud init, one mixing bus per deck, crossfader law, limiter, meters
    deck.dart      Deck: transport, cues, loops, tempo/sync, EQ, filter, FX (all SoLoud calls live here)
    sampler.dart   8-pad sampler on its own bus
    recorder.dart  master-mix capture -> WAV
    library.dart   track import + persistence
    bpm.dart       pure-Dart tempo estimator (runs in an isolate)
    synth.dart     built-in drum / FX sounds
  ui/              widgets-only UI (custom painters; no Material/Cupertino dependency)
```

Signal path per deck: `voice (trim, speed) → bus filters (EQ, DJ filter, key lock, FX) → bus volume
(channel fader × crossfader) → master (global volume → limiter)`. The sampler has its own bus into
the same master, and the recorder taps the master output.

The UI is laid out on a fixed 1280×720 landscape canvas and scaled to the screen, like a hardware
controller.

## Known limitations

- **No headphone cueing (PFL).** SoLoud drives a single output device, so a separate cue bus is not
  possible with this engine. A native-audio build (Oboe / AVAudioEngine) would be needed.
- **Scratching is seek-based.** SoLoud cannot play backwards, so the jog wheel scrubs rather than
  producing true reverse audio.
- **BPM detection is approximate** (it works from a sparse amplitude trace). Correct it with TAP;
  beat-grid phase is assumed to start at 0:00.
- **EQ and key lock are FFT-based** (parametric EQ / pitch shift filters) and add latency and CPU
  load. On low-end Android devices pass `lowLatency: false` to `SoLoud.init` in `engine.dart`.

## CI

`docs/ci.yml` is a ready-made GitHub Actions workflow (analyze, test, debug APK). Move it to
`.github/workflows/ci.yml`.

## License

Application code: MIT (add your `LICENSE`). `flutter_soloud` is MIT; the underlying SoLoud engine
is zlib/libpng licensed.
