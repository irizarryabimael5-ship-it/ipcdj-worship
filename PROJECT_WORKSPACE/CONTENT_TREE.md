# Verified IPCDJ Worship content tree
Updated: 2026-10-15. This index was compiled from GitHub repository directory listings on the `staging` branch. It is **not** a mirror of file contents. Use `main` / `staging` explicitly to avoid environment drift.

```text
ipcdj-worship/
├── PROJECT_WORKSPACE/                   # all management notes and future handoff
│   ├── README.md                        # lane router and ownership
│   ├── MAIN_LANE.md                     # current UI / experience status
│   ├── CONTENT_TREE.md                  # this source map
│   ├── HANDOFF_PROTOCOL.md              # future room migration spec
│   ├── HANDOFF_CURRENT.md               # living migration snapshot
│   ├── CHANGELOG.md                     # cross-workstream event log
│   ├── SIDE_LANES/
│   │   ├── README.md                    # important concurrent operational lanes
│   │   └── WORSHIP_SEMANAL.md           # Friday/Sunday sets, resources, archive
│   └── SIDEBARS/
│       ├── README.md                    # sidebar router
│       ├── ADDITIONAL_FEATURES.md       # supplemental features
│       ├── NOTIFICATIONS.md             # push notifications (on hold)
│       └── IOS_APP.md                   # installed app / iPhone options
├── README.md                            # public repository introduction
├── SITE_STANDARDS.md                    # protected implementation requirements
├── STAGING_POLICY.md                    # staging/live isolation and promotion
├── STAGING_SETUP.md
├── index.html                            # tabs, content, lifecycle, visuals, song catalog
├── sw.js                                 # root service worker + offline/PWA/notification hooks
├── manifest-v9.webmanifest              # installed web-app manifest
├── app-icon-safe.svg / icon-192.png / icon-512.png
├── apple-touch-icon.png
├── ios-launch/                          # 13 size-specific launch PNG assets
├── visual-motion-check.html             # older isolated trial; prior user report: unusable report control
├── social-preview-v176.jpg / social-preview-v180.jpg
├── robots.txt / _headers
├── docs/events/
│   ├── README.md
│   └── campana-gu-2026.template.source.txt
├── notifications/
│   ├── README.md / backend-contract.md
│   ├── config.json / event-catalog.json
│   ├── notification-contract.schema.json
│   ├── client.js / ui.js
│   ├── notification-foundation.js / sw-foundation.js
│   ├── admin.html / admin.js / test.html
│   ├── core/planner.mjs
│   ├── scripts/backend-smoke.mjs
│   ├── scripts/export-catalog.mjs
│   ├── scripts/sync-catalog.mjs
│   ├── tests/planner.test.mjs
│   └── worker/
│       ├── wrangler.jsonc / schema.sql / package.json
│       ├── scripts/generate-credentials.mjs
│       └── src/index.js
├── monitoring/
│   ├── WATCHDOG_POLICY.md / playwright.config.js / package.json
│   └── tests/
│       ├── site-health.spec.js
│       └── original-motion-preview.spec.js
├── scripts/
│   ├── build-staging-pages.sh
│   └── weekly-rollover.mjs
└── .github/workflows/
    ├── staging-health.yml
    ├── site-health.yml
    ├── weekly-worship-rollover.yml
    ├── notification-backend-health.yml
    ├── notification-sync.yml
    └── social-preview.yml
```

## Authoritative state, not copies
- **Song dates/details:** `index.html` `SONG_CATALOG_SOURCE`; don't duplicate schedules as editable data in sidebar files.
- **Current and historical worship tabs/sets:** `index.html` and (for related archived campaign source/templates) `docs/events`.
- **Real notification enabled/disabled flags:** environment-specific `notifications/config.json`; never trust outdated prose when the config disagrees.
- **Deployment health evidence:** exact workflow run for the exact branch HEAD.
- **Real installability:** manifest, SW, Apple launch/cover assets and live user-device tests; a roadmap file is not an install package.
- **Project status:** `PROJECT_WORKSPACE/README.md` and lane files.
- **Cross-chat continuity:** `PROJECT_WORKSPACE/HANDOFF_CURRENT.md` plus source of truth and commit identifiers.

This workspace is isolated to the IPCDJ Worship repository. No Google Drive folders or files are owned, indexed, edited or depended on for this workspace.

## WEEKLY Side Lane ownership
See [SIDE_LANES/WORSHIP_SEMANAL.md](SIDE_LANES/WORSHIP_SEMANAL.md). Canonical content is in `index.html` Friday/Sunday weekly markers; rollover engine `scripts/weekly-rollover.mjs`; workflow `.github/workflows/weekly-worship-rollover.yml`; completed-event archive in `docs/events/`. WEEKLY is an active Side Lane, not a Sidebar or new independent data store.


## 2026-10-17 current request-feature additions and new archive path
Original 2026-10-15 directory diagram predates the following now-verified Staging paths:
- PROJECT_WORKSPACE/HANDOFF_ARCHIVE/IPCDJ_WORSHIP_HANDOFF_2026-10-17.md (canonical complete migration).
- PROJECT_WORKSPACE/SIDEBARS/FEATURES_SONG_REQUESTS.md (active dedicated feature).
- requests/client.js (Staging form + published-only feed), index.html v203 and sw.js v203.
- requests/worker/wrangler.jsonc, schema.sql, deploy-control.json, README.md, CLOUD_ONLY_SETUP.md, EMAIL_NOTIFICATIONS_SETUP.md.
- requests/worker/src/index.js, email-outbox.js, email-probe.js; requests/worker/test/requests.test.mjs.
- monitoring/tests/requests-system.spec.js; scripts/build-staging-pages.sh copies requests/client.js.
- .github/workflows/song-requests-tests.yml and song-requests-staging-cloud-deploy.yml.
The request Worker / D1 are separate Cloudflare resources from the website and older Web Push backend. The one-time Gmail test is accepted AND owner-confirmed delivered, then disabled; normal mailing/public intake off. Live main excludes unfinished requests tab. Fetch fresh GitHub tree before making changes.

## 2026-10-19 new deferred specification
`PROJECT_WORKSPACE/SIDE_LANES/WORSHIP_MONTHLY_ARCHIVE_SPEC.md` — planned month -> dated weekend -> service archive navigation; currently notes only, not a new data store or runtime. Authoritative source remains `index.html` and `scripts/weekly-rollover.mjs`. Registered in [Worship Semanal](./SIDE_LANES/WORSHIP_SEMANAL.md) and [Additional Features](./SIDEBARS/ADDITIONAL_FEATURES.md).

## 2026-10-22 additional deferred documentation
`PROJECT_WORKSPACE/SIDE_LANES/WORSHIP_SONG_CARDS_ARTWORK_PREVIEWS_SPEC.md` — user-referenced screenshot-derived specification for compact weekly song-row authentic artwork, song-specific gradients and right-side previews; no code or independent song catalog. Indexed from Worship Semanal and Additional Features.

## 2026-10-24 migration archive
`PROJECT_WORKSPACE/HANDOFF_ARCHIVE/IPCDJ_WORSHIP_HANDOFF_2026-10-24.md` — new self-contained verified migration record: exact Oct24 main/staging refs, three curated Staging Solicitudes cards, six safety flags, Friday Oct23/Sunday Oct25 sets, Live issue #36, CI links, future work and explicit exclusions. This supersedes old current-status portions of the Oct17 handoff while retaining its full history. No runtime source changed in this archive operation.
