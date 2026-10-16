# IPCDJ Worship — chronological cross-lane changelog
Written for future Markdown handoffs. Each entry records reality rather than projected success.

## 2026-10-15 — WORKSPACE / all lanes
- User established **MAIN** as website UI/UX, performance, reliability and platform functionality.
- User requested **FEATURES**, **NOTIFICATIONS**, **IOS_APP** named sidebars with separate context and explicit switching, all in the IPCDJ Worship repository; **no Google Drive**.
- Inspected GitHub directory content tree, current standards and staging policy. Recorded owner map, lane routing and migration packaging protocol.
- Inspected notifications implementation and verified Live and Staging `enabled:false`. Observed GitHub Backend Health run `38776347095` SUCCESS and Notification Catalog Sync run `38748551202` SUCCESS; no end-to-end recipient delivery claim and no activation.
- Confirmed existing iOS manifest/icons/launch assets and Apple WebKit Home Screen PWA support; signed native certificates are a separate pathway requiring eligibility/cost.
- Files created under `PROJECT_WORKSPACE/`, with navigation links planned in root documents. Documentation-only; no change to website JS/CSS/data, SW, config, CI workflow or Live.
- Branch: `staging`; pre-workspace parent `87dbd998042f4555c1bc369f07accb1f0bd21c43`; final doc commit available from Git history.
- Watchdog disposition: `GENERIC_COVERAGE_SUFFICIENT` for pure Markdown management/navigation only. Staging checks may run because branch was updated; read final result rather than claiming success.
- Active lane after completion: **MAIN**, standing by.

## 2026-10-15 — MAIN background parity (prior user request)
- User liked Staging `?visual=original` Mac animation and reported Live looked good.
- Added Staging-only original Dios de Milagros motion preview + simple read-only `?motion_report=1` and specific animation watchdog.
- Enforced priority of first Prep song's artwork-derived palette, including overlaps, with a dedicated regression check; recorded in `SITE_STANDARDS.md`.
- Production stayed at `d75f8d7e90413f4eec87feb63b03765e6f72e8c4`, Staging latest visual code at `87dbd998042f4555c1bc369f07accb1f0bd21c43`.
- Latest staging run `38783527704` was still running at last check. No Live promotion.

## 2026-10-15 — MAIN CI readback correction
- Inspected GitHub completed failed staging run `38783527704` and 11.5 MB action log. 21 failed test cases due to 3 per-device categories: malformed `test.skip` setup, hard-coded v190 cache assertion versus v193 and stale release-driver source assertion contradicting approved top-Prep rule.
- 183 passed / 21 failed / 6 skipped / 14 not run. CI is **not** certified; no evidence from these failures alone of a new visual regression.
- New post-workspace staging run `38787351398` was in progress when reviewed. Pending later task in MAIN: correct outdated tests and revalidate all seven profiles. No app/runtime/notifications code or Live was changed during workspace setup.

## 2026-10-15 — MAIN: staged watchdog calibration
- Repaired three classes of documented stale/malformed staging watchdog expectations without changing production or runtime code.
- Actual paths: `monitoring/tests/original-motion-preview.spec.js`, `monitoring/tests/site-health.spec.js`, and current lane/handoff/changelog notes.
- Revalidate the exact new staging head with seven-profile deployed tests; note final result rather than assuming success.

## 2026-10-15 — Alert check and concurrent WEEKLY Side Lane
- Staging health run 38791297574 SUCCESS for `e30b00b...`; automatic recovery closed staging alert #31. Cloudflare Pages branch-preview issue #19 remains OPEN; independent production website health is green.
- User distinguished important, continuous, MAIN-parallel **Side Lanes** from optional/deferred **Sidebars**; created `PROJECT_WORKSPACE/SIDE_LANES/README.md` and `WORSHIP_SEMANAL.md`.
- Verified `index.html` current Friday/Sunday panels both show `Set pendiente` at this snapshot; completed GU archive and Oct 4 history preserved. Verified Sunday rollover script/workflow present on main and staging. No new member set details supplied.
- Updated MAIN, optional SIDEBARS router, source content tree and permanent Markdown continuity/handoff; no website runtime, music data, history, worker, notifications, or Live changed.
- Watchdog: `GENERIC_COVERAGE_SUFFICIENT` (organization-only documentation). A new staging CI run may occur on latest documentation HEAD and must be evaluated separately.

## 2026-10-15 — WEEKLY: Sunday 18 October worship set
- User supplied Markdown for Sunday October 18; applied exact five-song titles/artists/tonos/BPM, five ordered coritos, Josselin, common-time meter, source rehearsal note, PDF and YouTube playlist to Sunday current panel in Staging.
- Friday current panel remains Pendiente; October 9–11 GU and October 4 historical archives unchanged; Sunday rollover scheduled 2026-10-18 3 PM Eastern.
- Staging build/cache advanced to v194 for freshness; existing visual, notification, song-release catalog and Main Lane animation unchanged.
- Updated affected site-health source expectations and app-build expectation in animation watchdog; all seven profiles must validate before promotion. No Live mutation or approval implied.

## 2026-10-15 — Staging v196 strict retry after v195 failure and v194 restoration
The user confirmed that emergency-restored v194 works. The recovery [GitHub Actions run 38820645135](https://github.com/irizarryabimael5-ship-it/ipcdj-worship/actions/runs/38820645135) succeeded across deployed Staging health. v195's missing songs/tabs were traced to an invalid `continue` in a `forEach` callback; it was rolled back. A backup `backup-pre-v196-mac-glass-tbd-retry-20261015` preserves v194. For v196, all 8 executable inline scripts were parsed before any GitHub branch commit. The precise user-facing changes are: (1) first-paint curated Reinas Por La Eternidad warm rose/umber palette with no stale cached color override and early TBD artwork loading (never autoplay); (2) remove Mac scroll-only `backdrop-filter:none` / ambient-pause code so frosted glass remains continuous. New `scripts/check-inline-js.mjs` executes in Staging preflight and `monitoring/tests/visual-fidelity.spec.js` checks initial-vs-click palette, glass while scrolling and the functioning Inicio/Worship semanal tabs. All existing song catalog entries, October 18 Sunday worship, Friday pending, archived weeks and Campaña histories are preserved byte-identically in source. Live is unchanged; obtain full seven-profile CI success and user Mac approval before any Live release.

## 2026-10-15 — WEEKLY Staging v197 Sunday playlist preview warm-up
The user reported that the YouTube playlist inside Worship semanal → Domingo displays a black preview for a few seconds when first opened. Root cause supported by source: the current Sunday iframe was `loading="lazy"` and lives in the initially hidden Sunday tab (Friday is default), so its request could be deferred until the user switched tabs. Targeted Staging-only optimization: set **only that current Sunday iframe** to `loading="eager"` (browser may start loading during the normal intro), add preconnect links in the head to `https://www.youtube-nocookie.com` and `https://i.ytimg.com`; no new runtime JavaScript, no autoplay, no changed YouTube URLs, no added clicks. Archived campaign templates still lazy-load and archives still strip playlist embeds. App/service-worker cache bumps to v197; main current-song build tests updated; watchdog asserts exactly one eager Sunday player, 3 lazy archival templates, and resource hints. All song titles, Sunday/Fri content, main palette rules, tabs, rollover and historical source preserved. YouTube's own rendering may still briefly delay on slow networks; don't guarantee instant thumbnail. Await exact deployed seven-profile tests, user Mac review, and separate Live approval. Backup branch `backup-pre-v197-sunday-embed-prefetch-20261015` preserves v196. The preceding v196 full matrix was still running at this checkpoint.

## 2026-10-15 — WEEKLY Staging v198 sharp Sunday playlist cover
User confirmed v197 eager preloading removed the black wait but YouTube's own iframe initially renders a **very low-resolution thumbnail**. No supported YouTube playlist embed parameter guarantees sharper thumbnail artwork. In Staging v198, the current Sunday YouTube player retains its original URL, eager-loading, video controls and dedicated playlist link, but is initially covered by a **local resolution-independent CSS branded graphic** showing Worship semanal, Sunday 18 October, five songs and "Mostrar reproductor". A single explicit button click dismisses the cover to reveal the already loaded native embedded player; because YouTube controls playback, pressing Play inside the native player is a separate action. No external artwork guesses, stock thumbnails, autoplay, new requests, or changes to past campaign/current song content. The Sunday-only cover disappears with its entire .weekly-youtube-card when archived, so history remains free of playlists. Targeted seven-profile watchdog checks poster presence, dismissal, iframe persistence, original eager loading and archive exclusion. App shell/cache v198, JS scripts parsed before promotion. Existing v197 backed up as `backup-pre-v197-sunday-embed-prefetch-20261015` (at `57a67f11faef1a2fffdbf5bce1d051a630ec1900`). The v197 test run was still in progress before this refinement. Staging only; verify Mac presentation and full CI and obtain explicit Live approval before release. If rejected, restore exact v197 tree, never merge to Live.
