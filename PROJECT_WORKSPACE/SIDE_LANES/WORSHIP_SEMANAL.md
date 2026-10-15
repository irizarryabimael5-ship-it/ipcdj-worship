# SIDE LANE — Worship Semanal
ID: WEEKLY | Priority: **High, recurring, member-facing** | Status: **ACTIVE / ONGOING / PARALLEL TO MAIN** | Verified: 2026-10-15

## Mission and ownership
This is the practical use of IPCDJ Worship by the user and church worship-team members: accurate **Viernes** and **Domingo** current worship sets, members' rehearsal resources and the history of completed services. Unlike a discretionary Sidebar, it operates continuously and can run alongside MAIN, whose ownership remains platform-wide UI, animations, responsiveness, stability and performance.

## Direct source audit at setup
- `index.html`: `tab-worship-semanal` / `panel-worship-semanal`; independent nested Friday/Sunday panels with Friday default.
- Source's **current** Friday and Sunday show **Set pendiente**. Dashboard state `data-weekly-state="rolled"`, `data-weekly-cycle="2026-10-04"`. No new current repertoire was supplied with this task; do not claim one was published.
- Historic **Campaña GU 2026** (9–11 Oct) archived, plus older week ended 4 Oct. Original special-event template retained at `<template id="template-campana-gu-2026">` and `docs/events/campana-gu-2026.template.source.txt`.
- Weekly current sections are delimited by `WEEKLY_CURRENT_VIERNES_START/END` and `WEEKLY_CURRENT_DOMINGO_START/END`; historical section uses `WEEKLY_HISTORY_START/END`.
- `scripts/weekly-rollover.mjs` implements guarded, idempotent due-date archival; `.github/workflows/weekly-worship-rollover.yml` exists on both `main` and `staging`, configured for a Sunday window covering ~3 PM America/New_York and targeting `main`. Existence alone does **not** prove a particular rollover actually executed; verify workflow logs and deadline.
- The rendered archive must **never display YouTube playlist cards, embeds or links**. Preserve actual songs, order, artists, tonos/BPM, coritos, service dates and PDF/rehearsal resources. Active current sets may show approved playlist resources.
- Worship-service sets are distinct from Prep song release/estreno source `SONG_CATALOG_SOURCE`; never silently change release dates or enable the separate Notifications Sidebar.

## Ongoing weekly work
1. Publish Friday and Sunday **independently**, using only user-confirmed service dates, numbered songs, artists, tonos, BPM, coritos, musicians, rehearsals, PDFs and link resources. Explicit `Pendiente` for missing items; never reuse prior-week content without approval.
2. Preserve readable mobile/iPhone presentation, nested tabs, Friday default, accessible resources and functional links for members during services.
3. Protect every historical set and check exact automatic/archive rollover state; never delete prior weeks or completed campaigns.
4. Coordinate shared `index.html` source with MAIN. A task in one lane does not authorize overwriting code or content from the other.

## Publishing protocol and last checkpoint
Read latest `staging` HEAD and relevant Friday/Sunday markup; confirm user's new content. Edit **Staging only**; test seven-profile Playwright health and `scripts/weekly-rollover.mjs --self-test` as applicable, with feature-specific tests for new interaction/lifecycle. Show the staging update for approval; promote only after explicit authorization and verify Live. Record exact commit/run, sets, archival state, user approval and next service here and in `HANDOFF_CURRENT.md`.

**Last completed (2026-10-15):** auditing and establishing the side lane. No website markup, tabs, song data, weekly automation, notification state, or Live changed. **Next step:** await the user's verified next Friday/Sunday worship set details.
