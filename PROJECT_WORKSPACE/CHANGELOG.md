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
