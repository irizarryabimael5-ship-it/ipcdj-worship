# MAIN LANE — UI, UX, performance, stability and functionality
Owner: IPCDJ Worship main engineering lane | Current status: **ACTIVE** | Updated: 2026-10-15

## User's established priority
The main lane is the platform-wide excellence of the IPCDJ Worship website: smooth, premium UI and backgrounds, responsive navigation, song-card experience, audio previews, countdowns, PWA functionality, refresh reliability, and performance/stability across mobile and desktop. Preserve the working product rather than making speculative optimizations.

## Approved visual baseline and current state
- User confirmed Live looks good on 2026-10-15; **do not modify Live without separately requested release approval**.
- User approved the **appearance** of the staging `?visual=original` preview in Mac Chrome. This is not an instruction to deploy it or to apply a permanent override to visitors with reduced-motion settings.
- Live reference: `main` commit `d75f8d7e90413f4eec87feb63b03765e6f72e8c4`, production build `campana-weekend-v190` at last audit.
- Staging reference before workspace creation: commit `87dbd998042f4555c1bc369f07accb1f0bd21c43`, build `campana-weekend-v193`. Later `staging` HEAD must be checked fresh.
- The original ambient blob movement timings, artwork-gradient design and reflective `progress-sheen` are shared by both environments. Staging additionally has an opt-in visual restoration class, a direct on-page motion diagnostic and extra watchdog coverage.
- **Permanent priority:** the top visible Prep current-song card determines the ambient field palette, ordinarily the nearest scheduled estreno; change palettes smoothly as the top card changes; lower cards never override the first card.
- Songs, scheduled dates, Semanal/Campañas/En Preparación tabs, history, previews and playlists must stay intact. Archives must not display YouTube playlist embed/card links, per prior project rule.

## Areas of ongoing ownership
1. Visual fidelity: moving ambient field, glossy panels, artwork-specific soft gradients, fade timing, white traveling reflection on progress bar.
2. Performance: fast, smooth scroll on macOS and iPhone without flattening motion or sacrificing features; verify Chrome user-device behavior beyond generic CI.
3. Song lifecycle: authoritative `SONG_CATALOG_SOURCE` within `index.html`; current/coming/introduced; countdown/progress, overlaps, exact calendar and rollover.
4. Other runtime: tabs, archived GU campaigns, playlists, audio preview playback, login-free access, offline app shell, fresh PWA update, dynamic social previews.
5. Cross-device watchdog: `window.IPCDJ_HEALTH`, `monitoring/tests/site-health.spec.js`, `monitoring/tests/original-motion-preview.spec.js`.

## Staging environment and gates
- Production: https://worship.ipcdj.org/; Staging: https://staging.worship.ipcdj.org/.
- Staging-only diagnostic: `?motion_report=1`, avoiding the earlier unreliable standalone `visual-motion-check.html` report UX.
- The 2026-10-15 run `38783527704` passed preflight but its deployed seven-profile Playwright matrix was **in progress at the last check**. Do not call it fully certified until the final result is read from GitHub.
- The preceding restored v190 tree run `38724357235` succeeded, but that success does not certify later v193 changes.
- Source changes use staging -> watchdogs -> user device review -> explicit promotion -> live verification; never auto-merge production-specific metadata.

## Active task / next step
The user asked to establish multiple independent sidebars and handoff preparedness. This is a documentation/organization request, not a new runtime feature. After workspace setup, **stand by in MAIN** until the user requests the next improvement. Before any release, check fresh staging CI status, ensure user approval of the exact version and account for accessibility/scroll performance.

## Dependencies
- NOTIFICATIONS: preserves user interactions and service worker; activation is separate.
- IOS_APP: shares manifest, icons, service worker, iOS launch and notification API but owns its own install/distribution decisions.
- FEATURES: supplementary features enter through user-approved scoping, not unsolicited implementation.

## Certification blocker captured after documentation readback — 2026-10-15
The previous staging v193 CI run [38783527704](https://github.com/irizarryabimael5-ship-it/ipcdj-worship/actions/runs/38783527704) is **FAILED**, despite passing preflight and deployment checks. The seven-profile matrix reported 183 passed, 21 failed, 6 skipped, 14 not run. In three repeated categories across seven projects: (1) `original-motion-preview.spec.js` test setup invokes a `test.skip` callback with an undefined test-info argument, causing `Cannot read properties of undefined (reading 'project')`; (2) `site-health.spec.js` PWA test still expects `ipcdj-worship-v190` despite intentionally versioned `sw.js` cache `v193`; (3) old ambient release test still asserts the now-removed `const release=entries.find(...)` path, whereas the user-approved rule selects the first visible Prep card. These are demonstrated **test/assertion calibration blockers**, not proof that the actual user interface stopped animating. Do not weaken the new user-approved palette rule to appease the old assertion. Fix test setup/expectations in MAIN before claiming health certification. Documentation-only workspace commit `71625fe2151a7ebbe63f6c4c0fdfd6848d3e0ef4` triggered the newer staging run `38787351398`, which was **in progress** at readback; it contains identical runtime/test code and cannot be assumed green.
