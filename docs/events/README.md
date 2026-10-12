# IPCDJ Worship — Reusable special-event playbook

## Verified reference: Campaña GU 2026 (9–11 October)

**Theme:** Llenos del Espíritu Santo. Event UI was active October 9–11, 2026, America/New_York, with automatic expiration at **2026-10-12T00:00:00-04:00**. This removal is intentional and must never be reversed merely to silence a test.

**Permanent preservation:** The complete markup and every authored content/resource link from the finished three-day event are held in [campana-gu-2026.template.source.txt](campana-gu-2026.template.source.txt) and the actual historic source is still contained in `index.html` as `<template id="template-campana-gu-2026">`. The archived file is the source-of-truth recovery copy should the current website's markup later be repurposed. Preserve it verbatim. The source's referenced external PDFs and playlists remain externally hosted and should be checked when reused. This archive does not back up external files.

### What the finished template contains

- Separate main event tab, programmatically inserted between **Inicio** and **Worship semanal** during the authorized event window; accessible keyboard focus, distinct selected indicator and compact/mobile tab styling.
- Event dashboard with its own three chronological subtabs **Viernes**, **Sábado**, **Domingo**. Each contains distinct finalized worship set, musicians / rehearsals / vocals metadata where supplied, lyric and BPM/tono annotations, playlist embeds and external links to PDFs/resources, and associated coritos. Friday selected by default.
- **Worship semanal** during the special-event weekend shows an explicit linked redirect rather than duplicating event sets; the last regular week stays in a collapsible **Semana anterior** archive. Weekly Friday and Sunday current slots remain intentionally `Pendiente`.
- Expiration removes the event tab and panel, returns normal navigation and weekly visibility, clears special-event redirect, and preserves the regular previous-week archive and static source template. **No event content is deleted.**
- Robust integration with global tab switching, iOS/PWA launch overlay, countdown/lifecycle and lazy rendering; finished event date and content validated by full Chromium, Firefox and WebKit desktop/mobile/tablet watchdogs. The source still contains the details of the completed Fri/Sat/Sun sets; do not summarize or recreate songs from memory.

### Reuse for another special event

1. **Preserve historic evidence.** Copy this archive into a newly named version, e.g. `<event-slug>.template.source.txt`, and use an entirely new stable lowercase event key such as `retiro-juvenil-2027`. Do **not** alter the Campaña GU archive or its completed content.
2. **Agree on real event dates and timezone.** Define precise start/expiration instants with explicit offsets for `America/New_York`, including DST. No fabricated times. Decide whether the event overrides normal weekly Friday/Sunday slots and when to restore standard routine.
3. **Create unique markup IDs.** Use a unique `template-<slug>`, `tab-<slug>`, `panel-<slug>` and unique nested IDs/aria-controls for each event day/session. Avoid copying the fixed `campaign-tab-*` IDs unchanged when simultaneous templates may coexist.
4. **Reuse the design system and component shapes.** The classes `weekly-dashboard campaign-dashboard`, `campaign-day-tabs`, `campaign-day-panel`, `weekly-song`, `weekly-corito`, `weekly-youtube-frame`, resource links, service metadata and `weekly-history` already provide a polished tested layout. Keep responsive typography, mobile overflow checks, accessibility roles/keyboard Home/End/Arrows, dark-glass surfaces and continuity with native weekly styling.
5. **Retarget runtime routing.** Add a separate object to `SPECIAL_EVENT_TABS` with unique `key,label,eyebrow,title,description,templateId,hideAt`. Current source has **event-specific logic** in `createSpecialEventNodes` (`initCampaignDayTabs`), `syncSpecialEventTabs` (`campaignVisible`), `syncWeeklyEventRedirect` (`Campaña GU` label), `data-open-campaign`, and `data-weekly-special-event`. These must be adapted safely for the new event; do not merely rename the visible heading.
6. **Treat each service independently.** Fill only verified song ordering, exact title/artist, tono, BPM, coritos, rehearsal time, vocalists, PDF, playlists (Spotify/Apple/YouTube Music as applicable). Show an explicit `Pendiente` for anything not submitted. Never carry historic set lists into a new event without approval.
7. **Maintain content lifecycle separately from song release lifecycle.** A special service event tab is not a new `SONG_CATALOG_SOURCE` release. Do not create fictitious estreno timestamps, push notifications, or normal-week duplicates.
8. **Staging first.** Update the event markup + runtime, cache/build versions if relevant, isolated staging site, and **dedicated watchdog coverage in the same commit**. Validate event visibility before start and during the weekend, all days' independent metadata/links and keyboard behavior, exact expiration boundary, redirect clearance, and preservation of history. Lock synthetic time with `IPCDJ_CATALOG_TEST.renderAt` so CI cannot race the live clock. Assert current production only by comparing to actual event bounds.
9. **Preserve production isolation.** Promote only after exact staging deployment hash and all seven profiles have passed. Production is GitHub Pages; staging is Cloudflare Pages with `noindex`/push isolation. Never merge staging wholesale into `main`.
10. **Archive and hand off.** Update this playbook and the Google Drive continuity manual, preserve links and source files, list the event's exact finish/expiration, confirm clean disappearance, and hand off the new event's unique settings.

### Regression testing discipline (post-expiration)

Do not write tests asserting that a historical event is still visible on `Date.now()`. Instead use `IPCDJ_CATALOG_TEST.renderAt(Date.parse(<in-event-timestamp>))` and independently validate `renderAt(Date.parse(<expiry-timestamp>))` before returning to the real clock with `resume()`. Failures should represent real regressions, not event aging. Never disable a mandatory watchdog or ignore a genuine failing check just to avoid GitHub notification emails.

### Reference implementation points

- `index.html`: `<template id="template-campana-gu-2026">`; `SPECIAL_EVENT_TABS`; `initCampaignDayTabs`; `createSpecialEventNodes`; `syncSpecialEventTabs`; `syncWeeklyEventRedirect`.
- `monitoring/tests/site-health.spec.js`: `primary tabs, weekly panel and special-event lifecycle remain healthy`; `special-event lifecycle is clock-deterministic and retains an archived source`; `standalone full-scroll cycle cannot arm launch before tab switching`.
- `SITE_STANDARDS.md`: Special-event Worship semanal routing contract v182; weekly rollover v181.
- `monitoring/WATCHDOG_POLICY.md`: `FEATURE_COVERAGE_ADDED` required for time-gated UI, navigation, routing and keyboard controls.

**Archive note:** This archive is private-project source/version documentation kept in the repository, not a currently visible website tab. Audit resource availability before future reuse.

## Published worship history playlist policy (October 2026)

The event source archive retains all original service playlists and URLs as historically supplied. When the event is shown inside `Semana anterior` or `Historial anterior`, however, the website **must not display any YouTube playlist card/link/embed**. Future weekly rollover also strips YouTube players from the archived clone while keeping the current active set unchanged. All songs, PDF links, coritos, tones/BPM and metadata remain in history. This distinction is mandatory for future event template reuse.
