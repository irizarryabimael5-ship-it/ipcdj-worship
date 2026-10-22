# IPCDJ Worship — Worship Semanal Song-Row Artwork & Preview Enhancement
**Requested:** October 22, 2026 (user-provided Mac Chrome screenshots at about 5:27 PM ET)
**Classification:** DEFERRED VISUAL + MEDIA ENGINEERING FEATURE — DOCUMENTATION ONLY
**Primary lane:** Worship Semanal. Cross-referenced in Additional Features backlog. No active engineering work authorized.
**Priority / entry gate:** Resume only AFTER the currently active Solicitudes de Canciones integration/release work is fully completed, certified, and cleared by the user, and any blocking Live reliability work is handled. Do not divert the current project to implement this now.
**Live policy:** Stage, certify, visually inspect, obtain separate explicit owner approval, then selectively promote. Never automatically merge other feature work to production.

## User-observed examples
- Screenshot 1 (owner uploaded 2026-10-22, 5:27:17 PM local, browser staging.worship.ipcdj.org): the compact Worship Semanal "Canciones CDJ" numbered Friday song rows are currently mostly uniform dark cards, with readable number, song title, artist, tono and BPM but no per-song cover art or preview control.
- Screenshot 2 (owner uploaded 2026-10-22, 5:27:54 PM local, same Staging host): the "Después" scheduled-song cards (No Fallarás, Reinas Por La Eternidad) demonstrate the APPROVED visual treatment: authentic cover art softly integrated into each card's background, dynamically relevant color palette/gradients, readable song text, and a distinct circular play/preview action on the RIGHT.
- Screenshots are the user's references in the originating conversation; no screenshot binary was copied into the repository by this documentation-only commit.

## Exact future enhancement requested
Give EACH Worship Semanal **song row** the same family of artwork-driven gradients, relevant official album cover imagery and preview affordance that the existing "Después" cards use, **WITHOUT increasing the physical dimensions of the weekly song rows/cards**. Maintain a dense, tidy vertical list and a polished, restrained background treatment. Add the audio preview/play control at the row's **right edge**. The result should feel like a compact version of the established Después card, not a redesign into large posters.

### Preserve existing Worship Semanal information and behavior
- Keep numbered worship-song ordering and all current typography hierarchy, song titles, artists, **tono, BPM**, compact spacing and mobile readability; preserve Coritos sections, compás, corista, notes, PDFs and other resources unchanged.
- Applies in principle to the actual song rows inside Friday/Sunday Worship Semanal sets (and any appropriate event set rows). **Do not arbitrarily redesign Coritos, the entire weekly service card, or its navigation.**
- Do not enlarge the song-row height or expand overall card/list footprint to fit the cover. Prefer layered/soft cover composition and masked gradients behind the existing content with appropriate contrast; adaptable layouts on narrow devices.
- Right-aligned preview control should resemble the established Después affordance, with accessible label, keyboard/focus support, loading/error/playing/paused states, no disruptive auto-play, and coordinated playback (one song at a time). Do not place it where it covers tono/BPM or other details.
- Reuse as much of the approved Después player behavior and image treatment as safe and practical. Preserve Home Screen/PWA/browser sound behaviors, animations, input interactions, and reduced-motion/fallback behavior.

### Correct per-song metadata for ANY future weekly set
This is a reusable **source/identity/media pipeline**, not a one-off manual image per existing song:
1. Determine title, canonical artist, exact recorded version (original/live/acoustic/etc.), and verified provider track identity, respecting the actual roster's intended arrangement. Never use an unrelated cover/version because a title looks similar.
2. Select the authentic associated album/single artwork: prioritize the established official/Spotify-curated assets and the existing COV / MusicHoarders discovery-and-confirmation workflow; other reputable sources may cross-check identity when needed. COV is a reference/discovery resource, **not authorization to scrape or rely on an undocumented API**.
3. Extract a stable, polished, song-relevant palette/gradient while keeping all text legible and matched to the cover; deterministic results on reload and across devices where possible.
4. Attach a playable *authorized* preview if genuinely available. Spotify preview URLs may be absent; honor provider licensing/attribution/source-link requirements. Do not download/cache restricted provider previews or assume Apple/iTunes preview terms are interchangeable with Spotify media rules. Never fabricate audio, use an arbitrary other recording, or claim a clip works without actual test playback.
5. Graceful fallback: if exact official art or authorized audio cannot be verified, keep the existing compact dark song row, text metadata and accessible unavailable-preview treatment rather than breaking the weekly set or misleading users.
6. Support new weekly uploads, differing song counts, repeated songs, duplicate titles by different artists, songs with no previews, special services and long Spanish titles, without requiring redesign per song.

### Archive and project boundaries
- Preserve all past and future Worship Semanal sets, weekly rollover, seasonal/monthly archive work, and no-YouTube-playlists-inside-archives rule.
- If historical song rows inherit the new visuals, ensure the archive stays fast, accessible, conservative with provider rights, and never modifies original song order/notes/content. Scope archived preview availability separately if necessary.
- No changes to the managed SONG_CATALOG_SOURCE premiere scheduling, Solicitudes de Canciones, notifications, Cloudflare Workers, Wix/other sites, or production code as a side effect.
- No API credentials, tokens or secrets in browser HTML, repo history or project notes.

## Future engineering phases (do NOT start now)
1. Inspect current canonical weekly-row DOM/CSS, exact Después art/player pipeline, curated cover sources and provider licensing; define a safe per-song enrichment record with explicit source/recording confidence and fallback.
2. Prototype **one compact row only in isolated Staging**, comparing screenshot geometry before and after; obtain approval of appearance without broad rollout.
3. Implement reusable rendering/audio for arbitrary verified weekly songs, with bounded caching for safe metadata/art (not restricted audio), concurrency throttling, accessibility and predictable offline fallbacks.
4. Add exhaustive QA: seven-profile desktop/mobile/tablet health, media provider failures, no-preview and wrong-recording handling, one-active-preview behavior, narrow-row dimensions, title wrapping, contrast, battery/performance, physical iPhone/Mac playback, PWA and archive regression tests. Do not treat a UI screenshot alone as proof of audio/metadata correctness.
5. Obtain user Staging approval and a **separate** explicit Live promotion authorization after existing project priorities are cleared.

## Current checkpoint
**2026-10-22: captured and filed ONLY.** No Staging or Live interface, runtime files, weekly sets, worker source, release calendars, animations, CI workflows or audio settings changed. Continue the original Solicitudes de Canciones task from its existing project handoff and latest verified repository state when the user requests resumed work; do not jump to this deferred design.
