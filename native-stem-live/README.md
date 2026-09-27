# STEM Live Native 0.6.2

Native macOS performance foundation for STEM Live.

- SwiftUI/AppKit interface with first-click workspace navigation.
- AVAudioEngine/CoreAudio multistem playback and explicit AUMatrixMixer mono downmix.
- Strict lossless-source/sample-rate preflight.
- Host-clock generated click.
- Native Core Animation music-reactive stage color.
- Background waveform extraction and native Arrange timeline.
- Managed stem media in Application Support for stable projects.
- Guided Legacy Alpha migration from the existing Chrome-profile IndexedDB library.
- Native app icon and DMG-first installation with an Applications-location guard.

## Legacy migration

If the old Chrome Alpha and its custom profile are present, STEM Live Native offers a migration assistant. The assistant:

1. Copies the legacy Chrome profile to a temporary working copy.
2. Opens the exact Legacy Alpha file origin in an isolated Chrome process.
3. Exports songs, lyrics, section metadata, and embedded stem blobs from IndexedDB.
4. Copies the audio into STEM Live Native's managed media library.
5. Rebuilds native waveform overviews.

The original Legacy Alpha data is not modified.

Target: macOS Ventura 13+.
