# IPCDJ Worship — Automatic Monthly Worship Set Archive
**Owner request:** 2026-10-19 (local 2026-10-19 00:58 ET; message sent Oct 19 04:58Z)
**Lane:** WORSHIP SEMANAL (ongoing); indexed also as deferred Additional Features backlog
**Status:** DOCUMENTED / DEFERRED / NOT IMPLEMENTED. No staging UX change or Live release authorized.
**Priority:** After current Solicitudes de Canciones work and any Live reliability incidents, unless owner reprioritizes.

## Exact user intention
The existing Worship Semanal display should keep completed/nearby Friday and Sunday worship sets accessible in the **present separate weekend/service navigation** during the currently active month. Do not prematurely bury October's individual weekend sets while October remains the set-list month.

When the FIRST set list of the NEW month becomes **the next upcoming/in-effect weekend set**, all sets of the previous month should automatically move into a dedicated, clearly labeled MONTH tab (e.g., "Octubre 2026"). Opening that month should reveal an organized list of October's individual weekend/date entries, then clicking a weekend reveals its Friday/Sunday worship set details. The same pattern repeats for November -> December, etc. This is a NAVIGATION/ORGANIZATION layer over the existing, retained archive, not deletion or premature retirement of weekly sets.

## Example user journey (illustrative, not an instruction to deploy now)
1. During October, regular Fri/Sun weekend selections remain as currently displayed in Worship Semanal.
2. The first November worship set is published/queued as the **next set to be used**, establishing the month handoff even if publishing takes place before November 1.
3. October's completed weekends become grouped beneath an "Octubre 2026" month tab.
4. Click "Octubre 2026" -> select "2–4 oct", "9–11 oct (Campaña)", "16–18 oct", etc., as actually recorded, with dates derived from real stored sets, not invented events.
5. Click chosen weekend -> exact archived Viernes / Domingo (and special-event day if part of the historical set), including original ordered songs, artist, key, BPM, coritos, rehearsal notes, and still-valid approved PDF resources. Repeat this month-based archive for future years, with year-qualified identifiers to avoid "Octubre" collisions.

## Acceptance requirements
- Month handoff is determined by the first NEW-month set becoming **next up** from the canonical authored/published service calendar. **Do not group solely because a machine clock reaches the first day of the month** if the next published set is still October, nor based on an unconfirmed/pending placeholder. Use canonical America/New_York service dates, distinguishing publication time from service time.
- Current/next-up weekend tabs stay obvious and navigable; existing Friday/Sunday service switching still works. All prior-month sets are preserved and grouped; do not discard historical entries, duplicate them, or suppress dated weekend access.
- Nested hierarchy: Worship Semanal -> archive month (e.g., Octubre 2026) -> weekend/date -> Friday/Sunday/special-service content. Clear back/breadcrumb navigation, mobile-friendly accessible labels, keyboard/screen-reader behavior, sensible ordering (newest months first; dates documented and stable).
- Existing weekly 3 PM Sunday archival automation remains authoritative for **archiving content**; grouping happens independently and idempotently on month transition. No second competing content rollover scheduler. The site must not reshuffle historical sets on a refresh or offline/PWA restart.
- Campaigns/extra services (e.g., Campaña GU) remain available with their genuine service dates; avoid silently forcing a 3-day campaign into a normal Fri/Sun-only format.
- Preserve every historical song/title/order, tono/BPM, coritos, rehearsal details, and original approved PDFs. **Never show YouTube playlists, embeds, or YouTube playlist links inside archived sets** per standing policy; active/current sets may keep approved playlist links.
- Never change SONG_CATALOG_SOURCE managed-song premieres, schedule phases, preview engine, Notifications, Solicitudes, or production visuals as part of this feature.
- Respect staged/living calendar context (IPCDJ_CALENDAR and IPCDJ_WEEKLY); special handling for year boundaries, no-new-set months, delayed uploads, sets spanning months, and duplicate or previously archived weeks.
- No fabricated missing set lists or weekends. Pending sets stay explicitly pending. Month/week grouping must derive from actual authored service dates or existing metadata; record a conservative fallback/needs-review if an old archive lacks reliable dates.

## Implementation plan for a future approved iteration
1. Audit current `index.html` markers WEEKLY_CURRENT_VIERNES/DOMINGO and WEEKLY_HISTORY, actual service-date markup, campaign templates, IPCDJ_CALENDAR, and `scripts/weekly-rollover.mjs`. Define stable `YYYY-MM` and canonical weekend/cycle grouping keys WITHOUT rewriting historical song content.
2. Build a backward-compatible monthly archive model and nested month/week UI in STAGING only; use existing history structures as source of truth, including prior weeks and special campaigns.
3. Extend weekly archival scripts only where necessary with safe metadata tags; add pure tests for month rollover based on first next-up new-month set, month boundaries, incomplete/current-week cases, DST, year transitions, deduplication and preservation, and campaign inclusion.
4. Seven-profile Playwright + archive-contents/no-YouTube regression tests; responsive mobile and accessibility audit; explicitly test already archived October sets and future mock November/December transition.
5. User reviews real Staging navigation. Only after their explicit approval, selectively port tested monthly-archive changes to Live. **Do not merge Staging wholesale**, because Solicitudes and other features remain gated.

## Observed baseline (verified from Staging source when this note was created)
- `scripts/weekly-rollover.mjs` archives current Friday/Sunday into a single `<details class="weekly-history">` and renames earlier history as `weekly-history-older`; no monthly grouping exists.
- Current `index.html` contains `WEEKLY_HISTORY_START/END` and older October week/campaign entries; some earlier archives use legacy markup. This feature must migrate/read both safely.
- `PROJECT_WORKSPACE/SIDE_LANES/WORSHIP_SEMANAL.md` owns historical sets and strict YouTube omission rule.
- A separate Live health incident #35 was open when documented; investigate independently and do not attribute it to this not-yet-built feature.

## Current checkpoint and next resumption
**Documented only.** No runtime, archive markup, scheduling data, service worker, scripts, workflows, Staging Worker, or Live files changed. Resume by reading this spec and Worship Semanal lane, checking latest repository status and any incidents, then proposing the first isolated staging implementation with test coverage. Do not start implementation solely because this spec exists.
