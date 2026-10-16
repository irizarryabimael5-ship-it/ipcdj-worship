# IPCDJ WORSHIP — COMPLETE PROJECT HANDOFF

**Snapshot:** 16 October 2026, morning US Eastern time. **Migration:** conversation reached the ChatGPT length limit. **Purpose:** independently resumable status and instructions for the next IPCDJ Worship engineering room. **Use live GitHub refs as authoritative:** this file is a dated snapshot, not a claim that workflows cannot change after it was written.

## 1. FIRST ACTION IN THE NEW CHAT

1. Connect to GitHub repository **`irizarryabimael5-ship-it/ipcdj-worship`**. Do **not** use Google Drive or another project's files for IPCDJ Worship.
2. Read this handoff plus `PROJECT_WORKSPACE/README.md`, `MAIN_LANE.md`, `SIDE_LANES/README.md`, `SIDE_LANES/WORSHIP_SEMANAL.md`, every `SIDEBARS/*.md`, `HANDOFF_CURRENT.md`, `CHANGELOG.md`, `CONTENT_TREE.md`, `HANDOFF_PROTOCOL.md`, `SITE_STANDARDS.md`, `STAGING_POLICY.md`, and `monitoring/WATCHDOG_POLICY.md` from the current **staging** branch.
3. Refresh **both HEAD SHAs**, GitHub Actions run **38887478967**, and GitHub issues **#32 and #19**. Do not infer health from successful deployment or from a different SHA.
4. **IMMEDIATE TASK: complete certification of the newly implemented v200 Intelligent Calendar, not rebuild it.** Initial CI failed one calendar test; the test-only correction is present in the current staging HEAD. Evaluate the new CI run, fix any remaining demonstrated issue on Staging only, then ask for user Mac/iPhone review. Wait for **explicit Live promotion approval**.
5. Retain active **MAIN** and parallel **WEEKLY** Side Lane. Keep **NOTIFICATIONS, IOS_APP, FEATURES** Sidebars separately scoped/on hold.

## 2. REPOSITORY / HOSTING / CURRENT BRANCH STATE

| Item | Verified snapshot |
| --- | --- |
| Repository | `irizarryabimael5-ship-it/ipcdj-worship` |
| Live website | https://worship.ipcdj.org/ — GitHub Pages from `main` |
| Staging website | https://staging.worship.ipcdj.org/ — Cloudflare Pages from `staging` |
| Live `main` SHA | **`d75f8d7e90413f4eec87feb63b03765e6f72e8c4`** — unchanged during this room |
| Staging HEAD as audited | **`bf72bef6e2633efd848f904e1c01820b512aaacc`** |
| Website build on Staging | **`campana-weekend-v200`** |
| Newest Staging CI | [run 38887478967](https://github.com/irizarryabimael5-ship-it/ipcdj-worship/actions/runs/38887478967), **IN PROGRESS at snapshot**; preflight SUCCESS, deployed-health IN PROGRESS |
| Prior failed v200 CI | [run 38846601063](https://github.com/irizarryabimael5-ship-it/ipcdj-worship/actions/runs/38846601063), **FAILED: 206 passed, 66 skipped, 1 failed** |
| Prior passing weekly v199 CI | [run 38840359529](https://github.com/irizarryabimael5-ship-it/ipcdj-worship/actions/runs/38840359529), **SUCCESS** |
| Open issue #32 | [IPCDJ Staging Health Alert](https://github.com/irizarryabimael5-ship-it/ipcdj-worship/issues/32), OPEN as audited; should be reassessed after v200 CI |
| Open issue #19 | [Cloudflare Pages staging project's main-branch preview checks](https://github.com/irizarryabimael5-ship-it/ipcdj-worship/issues/19), OPEN; separate configuration issue, not proof of Live outage |

**Do not promote or merge `staging` wholesale to `main`.** The environments have deliberately distinct noindex, robots, headers, notifications and social/OG metadata. For Live release, fetch a fresh main SHA, create a production rollback branch, cherry-pick/selectively port only approved changes, run exact-commit production certification, and reconcile Staging preserving isolation.

## 3. IMPORTANT DISCOVERY AT MIGRATION — V200 ALREADY EXISTS

After the user explicitly approved the permanent Intelligent Calendar, GitHub Staging **already contains the implementation**:

- v200 implementation commit **`c4ba6534e2305e55de0bcbd63478cde12ec67a60`**, message `Staging v200: Eastern calendar heartbeat, actual week awareness, wake recovery and tests`.
- Test-only fix commit / current HEAD **`bf72bef6e2633efd848f904e1c01820b512aaacc`**, message `Correct calendar test frozen-clock mismatch without changing v200 runtime`.
- Staging app source `index.html` exposes **`window.IPCDJ_CALENDAR`** with read-only `getContext(now?)`, `getSnapshot()`, `refresh(now?)` and retains `IPCDJ_WEEKLY.getContext` compatibility. It distinguishes current **actual** Monday/Friday/Sunday in `America/New_York` from the **published** worship cycle and knows `nextService`, `serviceToday`, `publishedIsCurrentWeek`, current phase and configured archive deadline.
- A light **30-second heartbeat while visible** and wake/reentry refresh (`pageshow`, `focus`, `online`, visibility and internal navigation) keep the calendar updated. It reuses server-calibrated song time when available; has fallback to device clock. Emits `ipcdj:calendarchange` for meaningful transitions; does not auto-select tabs, invent songs, send notifications, or add a second archival scheduler.
- Sunday **3 PM America/New_York** remains the single authoritative archive cutoff; browser rollover is idempotent and GitHub's production workflow persists the archive. During DST changes timezone behavior must remain correct. Current service repertoire never appears on a newly computed calendar week unless actually authored/published.
- `monitoring/tests/calendar-awareness.spec.js` checks week changes, DST, new year, midnight, waking, cutoffs, archives and navigation. The original **one** v200 test failure resulted from a Playwright browser frozen on Friday while the test artificially refreshed calendar state to Saturday; subsequent tab navigation correctly recalculated from the still-Friday clock. The follow-up commit freezes the browser on Saturday before expecting Sunday as the next service. **No runtime code changed in that correction.**
- v200 test suite must pass fully and be visually confirmed by the user before Live; the initial v200 run failure is NOT a sign that the whole site or calendar broke.
- Known stable v199 backup branch: `backup-pre-v200-intelligent-calendar-20261015`; additional pre-test-fix backup: `backup-pre-v201-intelligent-calendar-certification-20261016`.

**Precise next step:** check final outcome of 38887478967. If failed, inspect exact Playwright job/step logs first and fix only demonstrated issues without downgrading the calendar semantics or undoing v199 worship data. If passed, audit all checks and have the user approve the current Staging experience, then ask explicitly whether to promote.

## 4. WORKSTREAM STRUCTURE (MUST PERSIST)

**MAIN LANE — ACTIVE:** cross-platform premium visual design, first-load and moving background, original gradients/ambient, song prep and release lifecycle, preview audio, countdown/progress bars, animation, performance, responsive behavior, PWA and watchdogs. Canonical `PROJECT_WORKSPACE/MAIN_LANE.md`.

**SIDE LANE: WORSHIP SEMANAL / WEEKLY — ACTIVE IN PARALLEL WITH MAIN:** real-use Friday/Sunday worship set data for church musicians and congregation; artists, tones, tempos, notes, coritos, playlist resources and archival accuracy. User specifically distinguished important concurrently operable **Side Lanes** from optional **Sidebars**. Canonical `PROJECT_WORKSPACE/SIDE_LANES/WORSHIP_SEMANAL.md`. Both lanes share `index.html` and must reconcile latest branch HEAD on shared edits.

**SIDEBARS (distinct and currently not active):**

- **NOTIFICATIONS — PAUSED / PREIMPLEMENTED / PUBLICLY DISABLED.** Worker/D1, Web Push, human six-phase planner and admin code exist. Both `main` and `staging` `notifications/config.json` were verified **`enabled:false`**; staging API origin empty, production push origin `https://push.worship.ipcdj.org`. Green backend/catalog workflows do not prove end-to-end delivery or actual catalog sync (possible intentional skip if credentials absent). No user push permission, backend enabling, subscriptions or live notification activation without separate explicit authorization. Source `PROJECT_WORKSPACE/SIDEBARS/NOTIFICATIONS.md`, notification scripts, worker and workflows.
- **IOS_APP — FUTURE/RESEARCH.** Existing PWA manifest standalone, service worker, iPhone icons and 13 launch images. Preferred free Home Screen install via Safari. A signing certificate alone does not distribute native binaries freely to arbitrary devices. Do not enroll in Apple programs or pay/issue certificates unless separately authorized. Source `PROJECT_WORKSPACE/SIDEBARS/IOS_APP.md`.
- **FEATURES — STANDBY/INTAKE.** No independently approved additional feature backlog. Source `PROJECT_WORKSPACE/SIDEBARS/ADDITIONAL_FEATURES.md`.

The user does **not** want this project stored, searched or modified in Google Drive. All durable project coordination lives in the IPCDJ Worship repository.

## 5. EXACT CURRENT WEEKLY WORSHIP DATA (STAGING ONLY)

**Active authored week:** Monday 12 October–Sunday 18 October 2026 (Eastern Time), with authoritative `index.html` `data-weekly-cycle="2026-10-18"` and `data-weekly-rollover-at="2026-10-18T15:00:00-04:00"` (Sunday 3 PM Eastern). **Friday remains the default nested tab.** Verified current source contains **four Friday songs** and **five Sunday songs**. User has **not approved a Live release**. Calendar awareness must NOT publish a new week's song list from inference.

### Viernes 16 de octubre — currently authored on Staging

**Corista:** Josselin. **Compás:** 4/4. **Rehearsal:** `Ensayen con la canción, con metrónomo y eventualmente sin letra.` **Children:** `Los Niños cantaran los coritos`.

| # | Canción | Artista | Tono | BPM |
| --- | --- | --- | --- | --- |
| 1 | Dios No Está Muerto | Miel San Marcos | Sol Mayor | 65/130 |
| 2 | Dios Es Más Grande | Miel San Marcos & Danny Gokey | La Mayor | 73/146 |
| 3 | El Gran Yo Soy | En Espíritu y En Verdad | La Mayor | 80/160 |
| 4 | Ver La Victoria | Elevation Worship | Si♭ Mayor | 78/156 |

**Coritos: Re Mayor, 115 BPM**. Exact order: (1) Yo tengo un amigo que me ama; (2) Alabaré, Alabaré, Alabaré a mi Señor; (3) Mirad, Bendecid a Jehová; (4) No hay Dios tan grande como tú; (5) No es con espada, ni con ejército; (6) Conozco a un hombre de poder; (7) Viva la Fe, Viva la esperanza, Viva el amor.

Playlist: `https://youtube.com/playlist?list=PLXqqjNOyFIbg&si=yA9UpmWJEv2g7LPY`. **Letras & Coritos PDF: NO URL PROVIDED**; show `Enlace pendiente`, no fabricated destination.

### Domingo 18 de octubre — currently authored on Staging

**Corista:** Josselin. **Compás:** 4/4.

| # | Canción | Artista | Tono | BPM |
| --- | --- | --- | --- | --- |
| 1 | Yo Te Busco | Marcos Witt | Sol Mayor | 85/170 |
| 2 | Cuán Grande Es Dios | En Espíritu Y En Verdad | Sol Mayor | 72/144 |
| 3 | Proezas | Miel San Marcos | La Mayor | 78/156 |
| 4 | Tu Fidelidad | Marcos Witt | La Mayor | 57/113 |
| 5 | Eres Todopoderoso | Danilo Montero | La Mayor | 63/125 |

**Coritos: Re Mayor, 115 BPM**. Order: (1) Yo Vine A Alabar A Dios; (2) Así Se Alaba A Dios; (3) Alabaré; (4) Hay Poder (Sin Igual Poder); (5) Poderoso Es Nuestro Dios.

YouTube: `https://youtube.com/playlist?list=PLfbkpqopl-bE&si=tUYLsdWc2lOFICbQ`. PDF Letras & Coritos: `https://u.pone.rs/rsegrxgg.pdf`. Rehearsal: `Ensayen con la canción, con metrónomo y eventualmente sin letra.`

**ARCHIVES:** Completed Campaña GU October 9–11 preserved as history and prior October 4 services preserved. History must show song data, PDF/rehearsal information and coritos, but **no YouTube playlist cards/links/embedded players in archives**. Current sets may have their original YouTube playlists.

**Playlist preview experiments:** User specifically rejected the custom playlist cover v198 and the eager preload v197, asking to return to the original embedded preview. The source was restored to v196 appearance **before** v199 weekly data was added; new v200 must preserve that original iframe presentation (`loading="lazy"`), **no custom branded poster**, **no new YouTube preconnects** unless later explicitly requested. Do not reintroduce those experiments.

## 6. MAIN UI / AUDIO / PWA INVARIANTS AND LESSONS

- User-approved premium original visual reference: **Dios de Milagros** song style. Artwork-based blended ambient gradients, subtle moving blobs, progress sheen, opening animation, countdown, 30-second preview/pause fade and preserved cover-art palette. **Top visible En Preparación card**, not a lower estrenos/release song, owns ambient colors. Preserve original animations and accessibility preferences.
- **Reinas Por La Eternidad** (Hillsong en Español, estreno TBD) must display its artwork-matched warm rose/umber palette from first paint; not switch from gray after pointer interaction. Existing Mac scrolling must **never** temporarily turn off frosted `backdrop-filter` or pause the moving background just to gain performance. v196 fixed both after user reported a visually jarring shift/clear-on-scroll effect.
- **Critical failed v195:** a bad `continue` inside an Array `forEach` callback caused a syntax error, hiding songs and breaking site tabs; user was understandably upset. Emergency rollback restored working v194. Mandatory preflight `scripts/check-inline-js.mjs` parses all eight executable inline HTML scripts and `node --check sw.js`; browser tests must verify functioning tabs and song cards before release. v196 was rewritten with valid conditionals and targeted tests.
- Maintain both Inicio and Worship semanal, Friday default, current/archived sets, past campaigns. Song premiere catalog `index.html` `SONG_CATALOG_SOURCE` is authoritative. Examples in current schedule: Glorioso Día premiere October 25, No Fallarás November 8, Reinas Por La Eternidad TBD; verify current source before acting.
- Preserve original mobile/desktop behavior, no app reset when switching tabs, fast reliable PWA refresh and offline cache. `sw.js`, `manifest-v9.webmanifest` and iOS launch assets are critical; no unapproved rework.
- Staging-specific opt-in `?visual=original` is a diagnostic (normal users' accessibility preference still respected), plus `?motion_report=1`. Do not treat manual diagnostic opt-in as default for all users.
- User approval of how a screenshot looks is **not** explicit authorization to go Live; the exact desired tested staging release must be approved.

## 7. CALENDAR IMPLEMENTATION ACCEPTANCE / THINGS STILL TO VERIFY

The user's explicit aim: IPCDJ Worship should be **alive**, calendar- and service-aware, maintaining awareness as time passes without daily manual date edits. v200 is now authored; validate instead of rebuilding:

- Eastern weekday, real Monday/Friday/Sunday, next service, DST, year/week rollover; distinguish today's real week from the **last published song set**.
- Frequent but cheap refresh while visible; reliable resumption after lock/sleep, iOS background, pageshow, focus and offline/online transitions. The clock may calibrate to server source when available; do not assume server sync is always online.
- Must not auto-invent or publish new song lists, auto-enable notifications, auto-start previews, change tab selection or silently mutate Live. The client calendar is read-only except calling existing guarded idempotent weekly rollover; the production GitHub weekly archival automation remains separate.
- Confirm release and weekly page remain attractive, no new loading flashes, frozen tiles, missing tabs or cross-device performance regressions. Check v200 tests and original motion/visual tests on all seven profiles.
- **Do not call v200 fully certified until run 38887478967 has concluded successfully.** Initial failure was a single clock-test inconsistency with 206 successful tests; the follow-up only updates the test.

## 8. CURRENT OPEN ISSUES / RELEASE GATES

1. **Staging issue #32 OPEN** from previous failed run; see new CI. Corrected v200 exact HEAD **`bf72bef6e2633efd848f904e1c01820b512aaacc`** was in certification at last audit. If it succeeds, the alert may auto-close; verify live GitHub state.
2. **Cloudflare Pages issue #19 OPEN**, legacy staging preview check on main. Independent GitHub Pages Live health run [38866100994](https://github.com/irizarryabimael5-ship-it/ipcdj-worship/actions/runs/38866100994) was SUCCESS; do not confuse #19 with a Live outage.
3. **Friday Letras & Coritos PDF** remains missing. Do not fabricate a URL; ask only when user wants to supply it.
4. If full browser CI is green, arrange user visual check for calendar day transitions, Friday/Sunday content, Reinas artwork, scroll glass and both primary tabs. **No Live release requested yet.**
5. If user explicitly approves promoting v200 and both sets: follow `STAGING_POLICY.md` with production rollback branch, selective approved runtime/test promotion, preserving Live metadata and push isolation, then production watchdog and staging reconciliation.

## 9. SOURCE MAP / CONTINUITY

- Workspace router: `PROJECT_WORKSPACE/README.md`
- MAIN: `PROJECT_WORKSPACE/MAIN_LANE.md`
- Parallel WEEKLY: `PROJECT_WORKSPACE/SIDE_LANES/README.md`, `PROJECT_WORKSPACE/SIDE_LANES/WORSHIP_SEMANAL.md`
- Sidebars: `PROJECT_WORKSPACE/SIDEBARS/README.md`, `NOTIFICATIONS.md`, `IOS_APP.md`, `ADDITIONAL_FEATURES.md`
- Global state/history: `PROJECT_WORKSPACE/HANDOFF_CURRENT.md`, `CHANGELOG.md`, `HANDOFF_PROTOCOL.md`, `CONTENT_TREE.md`
- Implementation standards: `SITE_STANDARDS.md`, `STAGING_POLICY.md`, `monitoring/WATCHDOG_POLICY.md`
- Application and authoritative content: `index.html`; `sw.js`; `manifest-v9.webmanifest`
- Calendar tests: `monitoring/tests/calendar-awareness.spec.js`; site health: `monitoring/tests/site-health.spec.js`; visual regression: `monitoring/tests/visual-fidelity.spec.js`, `monitoring/tests/original-motion-preview.spec.js`
- Syntax gate: `scripts/check-inline-js.mjs`; Staging certification: `.github/workflows/staging-health.yml`
- Weekly rollover: `scripts/weekly-rollover.mjs` and `.github/workflows/weekly-worship-rollover.yml`
- Older campaign archive template: `docs/events/campana-gu-2026.template.source.txt`
- Notifications source/backend/flow: `notifications/*` and `.github/workflows/notification-*`
- Backup branches: `backup-pre-v196-mac-glass-tbd-retry-20261015` (v194), `backup-pre-v200-intelligent-calendar-20261015` (passing v199), `backup-pre-v201-intelligent-calendar-certification-20261016` (v200 before test correction); verify branch existence before using.

## 10. WHAT MUST NOT CHANGE

- **Do not modify Live `main` without explicit tested-version approval.** Never bulk-merge staging-only robots, header, social, notification or CI environment files to Live.
- **Do not re-create the already implemented v200 calendar** or assume the prior failed run indicates a runtime fault. Verify replacement CI.
- **Do not invent Friday PDF, musicians, song keys, BPMs, worship service dates or next-week songs.**
- **Do not reintroduce v197/v198 YouTube preview experiments** after explicit user rejection.
- **Do not lose songs, current Friday/Sunday services, Oct 9–11 GU archive or older October 4 history.** Do not expose archived YouTube links/embeds.
- **Do not break the premium original moving gradient, sheen, frosted glass, Reinas first-paint colors, main song catalog, audio, PWA, mobile UI or navigation.**
- **Do not turn on public Web Push, request permission automatically or connect staging to production subscriptions.**
- **Do not access unrelated Google Drive files.** IPCDJ Worship project coordination is GitHub-repo-only.
- **Do not claim any task is running in background** unless a real GitHub workflow or explicit automation demonstrates it; always cite exact SHA/run and distinguish queued/running/success/failure/cancelled.

## 11. RESUME SCRIPT FOR THE NEXT ASSISTANT

> We are continuing IPCDJ Worship after a chat-length migration. Read this standalone handoff plus current GitHub `PROJECT_WORKSPACE` documents. Confirm Staging HEAD, Main HEAD, full GitHub Actions result for run 38887478967, issue #32 and issue #19. The v200 Intelligent Calendar is already implemented on Staging and a test-only correction was made. Our first task is **complete its certification and verify the website and Friday/Sunday sets**, not restart development. MAIN and the ongoing WEEKLY Side Lane stay active; Notifications, iOS App and Features Sidebars remain paused. Never change Live without explicit approval. Give a concise verified status and next step.

---

**End of self-contained handoff.** Last audited staging runtime was v200; pending CI status is explicitly time-bound. When checking this file at a later time, refresh GitHub facts before reporting anything as current.