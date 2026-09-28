# STEM Live Native 0.6.4

Native macOS live-stem performance foundation for macOS Ventura 13+.

## 0.6.4 playback recovery

This release narrows the audio graph deliberately after the 0.6.3 play-start failure.

- Stereo playback uses the shortest path:
  - AVAudioPlayerNode -> music mixer -> reverb -> program router -> main mixer.
  - AUMatrixMixer is completely absent from the normal stereo graph.
- Music L / Click R creates AUMatrixMixer only when split output is selected.
  - Matrix input/output element counts are explicitly configured before attachment.
  - Safe Sum, Equal Power, Left Only and Right Only remain available.
- Stereo <-> split switching is blocked while the transport is running.
  - Stop first, switch routing, then play.
  - This avoids reconstructing an AVAudioEngine graph during live rendering.
- Multistem startup queues file segments at player sample-time zero and starts every player from one future host-clock time.
- Invalid/empty stem formats are rejected before playback instead of being attached to the graph.
- A runtime CI smoke test now generates three stereo stems and actually renders:
  - direct stereo multistem audio;
  - split AUMatrixMixer multistem audio.
  The DMG build is blocked if either render path fails.
- 0.6.3 improvements remain: serialized transport state, cancelable fades, CoreAudio recovery guards, managed media, project backup recovery, Logic-style Arrange, Living Color 2, and the Ventura-native icon.

## Stability policy

A successful compile/package is no longer considered sufficient for a native audio release. The release workflow must pass the executable audio render smoke test before PKG/DMG artifacts are published.
