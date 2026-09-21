# IPCDJ Watchdog Co-Development Policy

This file is a permanent engineering contract for IPCDJ Worship.

## Core rule

The watchdog evolves with the website.

Every substantive runtime feature, interaction, lifecycle behavior, external dependency, PWA behavior, or performance-sensitive visual system must receive an explicit watchdog disposition before the change is considered complete.

There are only two valid dispositions:

1. `GENERIC_COVERAGE_SUFFICIENT`
   - Existing global watchdog coverage already detects the realistic failure modes introduced by the change.
   - No dedicated feature assertion is necessary.
   - The implementation report must say why generic coverage is sufficient.

2. `FEATURE_COVERAGE_ADDED`
   - The feature has behavior or state that generic health checks cannot understand.
   - Add or update synthetic tests and/or in-page health instrumentation that verifies the feature's intended behavior.
   - The implementation report must name what was added.

Never leave a substantive feature with an unstated watchdog disposition.

## When dedicated feature coverage is required

Use `FEATURE_COVERAGE_ADDED` for changes such as:
- new interactive controls or state machines;
- audio/media playback behavior;
- navigation, routing, filtering, search, forms, or publishing flows;
- new network/provider dependencies;
- service-worker, manifest, install/PWA, cache, offline, or lifecycle behavior;
- background/foreground, lock-screen, visibility, or resume behavior;
- timed transitions where sequence/order matters;
- new automatic song/release/lifecycle state transitions;
- new data persistence or synchronization;
- new browser-specific compatibility behavior;
- complex responsive geometry where exact positioning/state matters;
- performance-sensitive animation/compositing systems;
- any feature whose failure could look visually "fine" while behaving incorrectly.

## When generic coverage is usually sufficient

`GENERIC_COVERAGE_SUFFICIENT` is normally acceptable for:
- copy/text edits;
- ordinary song/content additions that use an already-tested renderer and schema;
- simple spacing/type/color adjustments;
- artwork swaps using existing artwork paths;
- changes whose realistic failure modes are already caught by the global checks for JS errors, resource failures, overflow, launch integrity, service-worker/PWA health, DOM/resource runaway, frame health, and responsive matrix coverage.

If a cosmetic change creates a new responsive or animated mechanism, it is no longer merely cosmetic.

## Required development sequence

For every substantive website change:

1. Read `SITE_STANDARDS.md` and this file before implementation.
2. Preserve existing health instrumentation and compatibility invariants.
3. Decide the watchdog disposition before considering the feature complete.
4. If dedicated coverage is needed, implement it in the same change set.
5. Run/allow the GitHub health matrix against the deployed build.
6. Do not weaken a valid production behavior merely to satisfy a bad synthetic assertion; calibrate the assertion to the intended behavior.
7. If the matrix finds a real regression, fix the root cause and rerun.
8. Preserve evidence-driven separation between real-device behavior and CI/emulation limitations.

## Mandatory user-facing completion report

Every substantive website implementation response must include a concise watchdog line using one of these forms:

- `Watchdog: FEATURE_COVERAGE_ADDED — <what was added or updated>.`
- `Watchdog: GENERIC_COVERAGE_SUFFICIENT — <why existing coverage is enough>.`
- `Watchdog: PENDING — <what still needs to run or be verified>.`

If a health run is still queued/in progress, do not call the watchdog verification complete.

When a final run completes, state whether it passed or failed and, on failure, identify whether the evidence points to production behavior, an external dependency, or CI/test calibration.

## Architecture boundary

The watchdog may automatically:
- sample real-device health;
- enter/leave bounded performance-lite rendering;
- use service-worker/cache fallbacks;
- retry synthetic checks;
- capture diagnostics;
- create/update/close the GitHub health alert.

The watchdog must not autonomously rewrite production source code or roll back deployments solely because a synthetic check fails.

## Permanent coverage layers

Layer 1 — in-page:
- `window.IPCDJ_HEALTH`;
- runtime errors/rejections/resource failures;
- preview errors;
- sparse frame health;
- long-task / long-animation-frame metrics when supported;
- layout/overflow and core-state snapshots;
- adaptive performance-lite recovery.

Layer 2 — GitHub/Playwright:
- deployed-build verification;
- cross-engine/device matrix;
- launch/layout/scrolling;
- preview behavior and feature-specific assertions;
- translation resilience;
- PWA/manifest/service-worker integrity;
- coarse DOM/resource efficiency guardrails;
- diagnostic artifacts and health-alert lifecycle.

This policy must be updated whenever the monitoring architecture itself materially changes.
