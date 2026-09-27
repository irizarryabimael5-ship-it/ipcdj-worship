# STEM Live Native 0.6.3

Native macOS live-stem performance foundation for macOS Ventura 13+.

## 0.6.3 focus

- One permanent CoreAudio routing graph for Stereo Music and Music L / Click R.
  - Output-mode and mono-downmix changes alter AUMatrixMixer coefficients instead of rebuilding the engine.
  - Split routing validates that the hardware exposes at least two output channels.
- Serialized transport state and guarded recovery for CoreAudio configuration changes.
- Cancelable gain ramps and fade-tail work so stale transitions cannot stop a newly started performance.
- Cached audio preflight inspection to keep System responsive during playback.
- Functional section loop control tied to exact stored loop boundaries.
- Logic-style Arrange workspace with:
  - fixed track headers,
  - waveform lanes,
  - arrangement-marker lane,
  - bar/beat grid,
  - transport/LCD strip,
  - zoom,
  - mute/solo controls,
  - millisecond section and loop editing.
- Larger stage-readable typography and clearer control hierarchy throughout.
- Living Color 2:
  - GPU/Core Animation background,
  - black when transport is stopped,
  - restrained color during quiet music,
  - stronger blue/indigo/purple/cyan/pink response as energy changes,
  - long visual decay when playback stops.
- Ventura-native application icon artwork: full-square unmasked source artwork so macOS owns the final icon shape.
- Project JSON backup recovery and verified managed-stem copies.
- Legacy Alpha migration remains available.

## Audio architecture

Music stems feed AVAudioPlayerNode -> AVAudioMixerNode -> AVAudioUnitReverb -> Apple AUMatrixMixer -> program router -> main mixer. The matrix always operates stereo-to-stereo.

Stereo mode uses 1:1 matrix passthrough.

Split mode keeps the graph online and changes only crosspoint gains:
- Safe Sum: 0.5 L + 0.5 R -> output L
- Equal Power: 0.707 L + 0.707 R -> output L
- Left Only: L -> output L
- Right Only: R -> output L

The generated click is routed separately to output R.

## Stability

The CI build:
- rejects explicit force-unwrap patterns in native source,
- builds Intel and Apple Silicon binaries,
- assembles a universal app,
- validates Info.plist and app icon,
- verifies code signing,
- validates the PKG,
- creates and verifies the DMG,
- publishes SHA-256 checksums.
