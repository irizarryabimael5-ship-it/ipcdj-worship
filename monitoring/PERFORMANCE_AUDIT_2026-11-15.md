# IPCDJ Worship — Performance Initiative #41, Phase 1 (2026-11-15)

**Status:** ACTIVE; changes limited to the `staging` branch. **Not a finished cross-device performance certification.** Production `main` unchanged pending explicit approval.

## Report and non-negotiables

The owner observed noticeable lag when loading and using IPCDJ Worship on an iPad. The goal is faster, smoother behavior across iPad, iPhone, Android, desktop and supported PWAs **without changing the existing design, image quality, background gradients, animations or features**.

## Source inspection (grounded observations, not a measured device diagnosis)

- The main HTML document is large (~535 KB as retrieved from Staging at kickoff), with inline CSS and JavaScript. This affects network transfer and main-thread parse/execution; actual byte and CPU costs must be measured on representative devices.
- The active-song updater runs approximately once per second. During a stable preparation phase it was assigning repeated inline progress colors, CSS vars, `aria-hidden`, `aria-valuenow`, `aria-valuetext`, phase datasets and timeline classes even when serialized values did not change. This can trigger unnecessary attribute mutation/style invalidation. The code was modified to write only on actual value differences.
- The Staging HTML contained an eager high-priority image preload for the historical `Dios De Milagros` album art; it was not the current song cover in November. Removed this eager preload, leaving the historical song's curated artwork URL and normal lazy/normal artwork loading untouched.
- Existing ambient animation CSS uses multiple blurred, animated blobs and backdrop-filtered panels. Source analysis alone **cannot** determine how much they contribute to lag on a particular iPad. The visual animation system is **unchanged** by this patch.
- The previously implemented `ipcdj-performance-lite` guard can pause ambient blobs when it detects severe frame delays. This pre-existing behavior is a separate owner-level fidelity concern. It has **not** been modified, disabled or accepted as a solution under this performance initiative.
- Playwright's `webkit-tablet` project approximates an iPad-sized WebKit viewport but is **not** a physical iPad Safari measurement. Prior health workflows were repeatedly cancelled, so their cancellation must not be misreported as certification success or an application failure.

## Staging-only Phase 1 changes

1. Skip repeated no-op inline CSS custom-property and ARIA writes for stable countdown/progress rendering.
2. Preserve continuous one-second absolute-time countdown and exact progress percentage/color transitions. Use value-aware `active-phase` toggles instead of removing and re-adding every second.
3. Avoid needless reassignments of ambient-driver/phase metadata; preserve stage transitions and album-art logic.
4. Eliminate a historical cover image's high-priority preload, with no replacement or change to the existing cover rendering system.
5. Add `monitoring/tests/performance-contract.spec.js`: deterministic stable-tick MutationObserver regression, advancing-clock proof, ambient animation-preservation assertions and obsolete-preload guard. Run on Chromium desktop and WebKit tablet; existing tests continue covering the full matrix.
6. Bump the Staging build and service-worker caches together. No Live deployment.

## Pending evidence and subsequent work

- Run inline-script syntax and full Staging health matrix at the exact commit; repair evidenced failures, and separate external dependency or CI limitations from actual regressions.
- Collect representative cold/warm load timings (navigation timing, LCP, JS long tasks, frame p50/p95, scroll/interaction FPS, DOM nodes, memory/network) and trace the actual affected iPad's CPU/GPU and Web Inspector timeline where possible.
- Compare repeatable before/after metrics against the unchanged animation/output baseline before claiming a meaningful speed gain; identify larger structural bottlenecks from traces and implement separately in Staging.
- Obtain explicit owner approval before any changes to production Live or any visual tradeoffs.

**Decision:** Phase 1 removes demonstrable redundant writes without reducing visual effects. Root cause of the reported iPad lag remains unverified pending real-device evidence.
