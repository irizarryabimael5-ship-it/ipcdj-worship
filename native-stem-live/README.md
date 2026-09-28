# STEM Live Native 0.6.5

Native macOS live-stem performance foundation for macOS Ventura 13+.

## 0.6.5 playback crash correction

The 0.6.4 build could still terminate immediately on Play in Music L / Click R mode. The generated click buffers were mono while the click AVAudioPlayerNode connection was allowed to negotiate its output format implicitly. AVAudioPlayerNode requires scheduled buffers to match the node output channel count. 0.6.5 fixes that boundary explicitly.

- Generated click node is connected with an explicit 1-channel CoreAudio format at the hardware sample rate.
- Before any click buffer is accepted, STEM Live verifies:
  - node channel count = 1;
  - buffer channel count = node channel count;
  - buffer sample rate = node sample rate.
- A mismatch disables the click and reports status instead of proceeding into the playback call.
- Click events use AVAudioPlayerNode sample-time scheduling instead of constructing click events from arbitrary host-time timestamps.
- CI now renders split multistem audio with an actual generated mono click buffer. The release is blocked if the click format or render path fails.

## Transparent live audio path

Stereo music:
AVAudioPlayerNode -> Music Mixer -> Output Router -> CoreAudio

Split music:
AVAudioPlayerNode -> Music Mixer -> AUMatrixMixer -> Output Router -> CoreAudio

No lossy encoding stage is introduced. Lossless source files are decoded by AVFoundation into the native floating-point render graph. 0.6.5 removes the always-inline reverb unit from the program path to minimize processing and failure surface. The smooth fade remains gain-based; a reverb-tail send can return later as an isolated auxiliary path rather than sitting in the main signal chain.

## UI / visual isolation

Living Color no longer installs a realtime audio tap. It follows the precomputed waveform envelopes already stored with each imported stem. This keeps the visual layer music-sensitive without executing visualization analysis on the CoreAudio render thread.

## Diagnostics

STEM Live now writes flushed playback breadcrumbs to:
~/Library/Application Support/STEM Live Native/runtime-audio.log

The file records operations such as Play request, engine start, stem scheduling, click scheduler start and uncaught Objective-C exceptions. Diagnostics are deliberately isolated so logging failure cannot interrupt playback.

## Release gates

A successful compile is not sufficient. CI now requires:
- no explicit unsafe force operations found by the source audit;
- explicit mono click-node connection;
- no implicit click connection;
- no realtime audio tap in the native engine;
- direct stereo multistem render;
- split-matrix multistem render;
- generated mono click render;
- Intel and Apple Silicon compilation;
- universal app assembly;
- signing verification;
- PKG validation;
- DMG verification.
