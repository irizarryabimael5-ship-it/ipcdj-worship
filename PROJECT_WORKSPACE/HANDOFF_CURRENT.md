# IPCDJ Worship — current always-updated handoff source
Snapshot date: 2026-10-15. **Not yet a final migration file**; compile at next room change per [HANDOFF_PROTOCOL.md](./HANDOFF_PROTOCOL.md).

## One-minute restart
- Project: IPCDJ Worship for Iglesia Pentecostal Ciudad de Jehová.
- Repo: `irizarryabimael5-ship-it/ipcdj-worship`.
- Live https://worship.ipcdj.org/ from `main`. User said it looks good; leave alone.
- Staging https://staging.worship.ipcdj.org/ from `staging`. User approved visual style at `/?visual=original` on Mac Chrome. This was staging-appearance approval, NOT permission to push Live.
- **Active MAIN LANE**: UI/UX, performance, visual fidelity, stability and functionality.
- Three registered sidebars: FEATURES standby; NOTIFICATIONS paused/gated; IOS_APP future research. Refer to the individual files under `PROJECT_WORKSPACE/SIDEBARS/`.
- Work coordination and all future migration files belong **only in this project's GitHub repository**, never the user's unrelated Google Drive folders.

## Current known code checkpoint
- `main` at `d75f8d7e90413f4eec87feb63b03765e6f72e8c4` (observed earlier 2026-10-15).
- `staging` before this documentation-only workspace commit at `87dbd998042f4555c1bc369f07accb1f0bd21c43`, `campana-weekend-v193`. Refresh branch HEAD on new chat.
- Production and baseline v190 staging share identical core runtime/visual code except environment metadata. Staging v193 has opt-in original motion preview, better read-only motion diagnostic, top-Prep ambient owner fix, and extra Playwright watchdog.
- Original v190 baseline `d15de11370be8da28a31719ba9202ca404c28d76`. Reverted baseline run `38724357235` passed. Latest v193 staging matrix run `38783527704` was in progress at last full check; read exact final state.
- User's confirmed behavior: the first visible song in En Preparación, generally next to debut/estreno, owns moving ambient background colors; follow its own cover art, smoothly transitioning to next top song. Reflective white progress sheen and soft gradients are essential.
- Preserve tabs En Preparación, Semanal Vie/Dom, Campañas archives; all song records, dates, countdowns, previews, release rollover, social previews and PWA. No YouTube playlist links in archived sets.
- Prior failed trials v191/v192 worsened visual aesthetics; restored v190 then built opt-in v193; avoid arbitrary reverts/optimizations.

## All lanes / where to resume
- MAIN: leave Live untouched, use Staging as sandbox; no pending user code request beyond this organizational system. At next UI task verify staging CI and compare Mac/iPhone visuals.
- FEATURES: no concrete extra feature requested yet; receive feature and create scoped spec inside the sidebar.
- NOTIFICATIONS: client/UI/Worker/D1/VAPID/planner/one-minute Cron/admin console/sync and tests implemented, **enabled:false** in Live and Staging. Last remote backend GitHub health run `38776347095` succeeded; catalog-sync run `38748551202` succeeded but may be a safe skip without token; verify actual sync and end-to-end delivery before activation. No separate approval to enable pushes.
- IOS_APP: manifest `display:standalone`, Apple touch icon, startup images, SW already exist; Home Screen PWA is no-fee default; signed native distribution requires additional eligibility/cost. No choice made or certificate installed.

## Latest action, risks and next instruction
2026-10-15 — Established durable workstream/sidebar routing, per-lane status, content tree, GitHub-only ownership, and migration protocol as docs on the Staging branch. No source runtime changes or production release authorized. Check actual commit and subsequent staging CI run after these doc changes.

**Next instruction:** Stand by in MAIN. On explicit "switch to sidebar NAME," read that sidebar and its current source, report exact pause point and work only within the requested lane.

## Sources
[PROJECT_WORKSPACE/README.md](./README.md) · [CONTENT_TREE.md](./CONTENT_TREE.md) · [MAIN_LANE.md](./MAIN_LANE.md) · [SIDEBARS/README.md](./SIDEBARS/README.md) · [HANDOFF_PROTOCOL.md](./HANDOFF_PROTOCOL.md) · [CHANGELOG.md](./CHANGELOG.md)

## Staging certification warning — recorded from completed GitHub logs
The 2026-10-15 deployed staging matrix [run 38783527704](https://github.com/irizarryabimael5-ship-it/ipcdj-worship/actions/runs/38783527704) **failed**: 183 passed, 21 failed, 6 skipped, 14 did not run. Three stale/malformed assertions repeated across seven browser profiles: the `original-motion-preview.spec.js` `test.skip` setup throws a TypeError; `site-health.spec.js` checks obsolete `ipcdj-worship-v190` SW cache while deployed SW is v193; and release ambient test requires old `release=entries.find` logic, contrary to the now-protected first-Prep-card palette rule. This is a watchdog/test calibration blocker. Do **not** alter production or undo accepted user requirements to make outdated tests pass. An updated staging run `38787351398` was in progress during this documentation review; check its exact final result before claiming certification. Main Lane backlog: repair those tests safely, rerun matrix, validate animations/device behavior. The documentation workspace commit is `71625fe2151a7ebbe63f6c4c0fdfd6848d3e0ef4`; a subsequent documentation-only state update may advance HEAD.
