# STEM Live Native 0.6.6

Native macOS live-stem performance application for macOS Ventura 13+.

## 0.6.6 priorities

0.6.6 builds directly on the verified 0.6.5 native SwiftUI/CoreAudio source. It does not regress to the old browser implementation and it keeps the 0.6.5 stability invariants:

- explicit mono generated-click node at the hardware sample rate;
- no realtime visualization tap on the live audio render path;
- no always-inline reverb in the program path;
- persistent runtime audio breadcrumbs;
- graph reconstruction for Stereo Music / Music L + Click R only while stopped.

## Responsiveness

The UI no longer performs full waveform-heavy project JSON encoding synchronously on each slider, marker or text edit. Persistence is debounced onto a dedicated utility queue.

Fast-changing playhead and Living Color metrics are isolated in a dedicated observable performance state. This prevents 30 Hz transport/color publication from invalidating unrelated app chrome and configuration views.

Interaction feedback is intentionally brief. Ambient color remains smooth and slower than buttons/tabs.

## Living Color 2

New stem imports receive offline analysis containing:

- overall RMS energy;
- low/bass energy;
- mid energy;
- upper/air energy;
- transient energy.

This metadata is cached with the stem and interpolated during playback. It never installs an AVAudioEngine tap.

All LIVE section cards can carry restrained musical color while the current section receives the strongest emphasis. Appearance controls include palette, global intensity, card color amount and ambient motion.

## Tempo and click

ARRANGE exposes editable song BPM with numeric entry, +/- 1 BPM and Tap Tempo.

The generated click supports:

- Follow Song or independent Custom BPM;
- Tap Tempo and +/- 1 BPM;
- 1/4, 1/8 and 1/16 divisions;
- multiple click sounds;
- click level;
- bar accent on/off and accent level;
- subdivision level;
- swing for subdivisions;
- grid nudge;
- Quick Click access in LIVE when split output is active;
- visual beat/downbeat animation in CLICK.

## Auto Sync and import naming

Auto Sync performs offline envelope correlation. It stores non-destructive source trim offsets and confidence values; it never time-stretches or rewrites source audio. Low-confidence estimates are left unshifted.

Import analyzes filenames for common song-title information and common stem roles such as Drums, Bass, Piano, Keys, Guitars, Vocals, Click/Cues and Full Mix/Reference. Names remain editable in MIX.

## View / stage operation

- setlist sidebar can be shown or hidden;
- Focused Live Mode removes nonessential chrome;
- global transport remains available outside LIVE;
- Space is reserved for Play/Pause instead of workspace-tab focus;
- menus expose workspace, transport, view and diagnostic commands;
- relevant setlist, section and stem controls have contextual menus.

## Transparent live audio path

Stereo music:

AVAudioPlayerNode -> Music Mixer -> Output Router -> CoreAudio

Split music:

AVAudioPlayerNode -> Music Mixer -> AUMatrixMixer -> Output Router -> CoreAudio

Lossless source files remain lossless source material and are not transcoded to AAC/MP3. AVAudioEngine internally renders floating-point PCM. That is normal transparent DSP representation, not a lossy codec, but it is not described as bit-perfect when mixing, gain or sample-rate conversion is active.

Split downmix modes:

- Safe Sum: L * 0.5 + R * 0.5 to program LEFT;
- Equal Power: L * 0.70710678 + R * 0.70710678 to program LEFT;
- Left Only;
- Right Only.

Program RIGHT is zeroed by the matrix and generated click is routed separately to RIGHT.

## Diagnostics

Runtime breadcrumbs remain at:

~/Library/Application Support/STEM Live Native/runtime-audio.log

## Release gates

CI must execute the runtime audio path, not only compile it. 0.6.6 requires:

- static source safety audit;
- explicit mono click regression check;
- no realtime render tap;
- no inline reverb in the production music path;
- dry direct-stereo offline render;
- Safe Sum split isolation;
- Equal Power coefficient behavior;
- Left/Right Only behavior;
- generated mono click routed to RIGHT;
- Intel and Apple Silicon compilation;
- universal app assembly;
- signing verification;
- PKG validation;
- DMG validation;
- artifact checksums.

Passing CI is not the same as user verification on the target 2017 Intel iMac / Ventura 13.7.8.
