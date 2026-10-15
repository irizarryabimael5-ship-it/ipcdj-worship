# SIDEBAR — Notifications
Lane ID: NOTIFICATIONS | State: **PAUSED / PREIMPLEMENTED, PUBLICLY DISABLED** | Updated: 2026-10-15

## Original aim and where work stopped
Develop an optional Web Push notification system for song preparation/estreno and administrator messages, with especially good installed iPhone web-app behavior, without disturbing IPCDJ Worship's primary song UI. Source work from 2026-09-20–22 implemented a notification foundation, client, interface, scheduling backend and deployment runbook; later work added catalog and backend health automation. **The system is on hold: public opt-in and delivery have not been approved/activated.** Do not infer activation from GitHub workflow success.

## Verification: direct repository inspection (2026-10-15)
- Both `main` and `staging` `notifications/config.json` show `enabled:false` (checked directly). Live config has `apiOrigin:"https://push.worship.ipcdj.org"`; Staging config intentionally has empty API origin and Staging siteOrigin. Never copy the Live config into Staging.
- `notifications/README.md` begins "v166 implemented and browser-tested, runtime-gated until ... backend provisioned", but that introductory status may be **historical**; do not use it alone to decide today's deployment readiness.
- Recent `IPCDJ Notification Backend Health` GitHub Action run **38776347095** completed SUCCESS on 2026-10-15 17:19 UTC. It is a remote backend smoke test configured to require health/configured and a public VAPID key. This indicates the backend passed that check then, but does not prove successful end-to-end delivery to an enrolled device.
- Recent `IPCDJ Notification Catalog Sync` workflow run **38748551202** completed SUCCESS at 2026-10-15 14:07 UTC. Its sync script **safely skips** when `IPCDJ_PUSH_ADMIN_TOKEN` is absent; inspect its step logs, admin event counts and actual backend outcome before claiming song catalog synchronization.
- Attempted independent external read of `https://push.worship.ipcdj.org/health` and `/v1/config` through the research browser was **not accessible**. GitHub CI is the verified evidence, not direct browser inspection.
- Normal site's notifications card remains hidden when disabled; client code guards staging origins and does not ask for notification permission automatically.
- No notification subscription state, customer delivery count, or live administrative secrets were accessed, inferred or stored in these docs.

## Implemented content and source links
| Component | Source of truth | Observed capabilities |
| --- | --- | --- |
| Activation flags | `notifications/config.json` | Disabled in both environments; Staging isolated |
| Browser client | `notifications/client.js` | Secure-context / standalone / permission / PushManager handling; staging guard |
| User interface | `notifications/ui.js` | Notifications card, opt-in/out, iOS Add-to-Home-Screen instructions; hidden until configured |
| PWA event hooks | `notifications/sw-foundation.js` and `sw.js` | Push event display, click/deep-link behavior |
| Human phase planner | `notifications/core/planner.mjs` | Six scheduled moments, deterministic Spanish copy |
| Source exporter | `notifications/scripts/export-catalog.mjs` | Converts single authoritative `SONG_CATALOG_SOURCE`; no double-authoring |
| Catalog sync | `notifications/scripts/sync-catalog.mjs` and `.github/workflows/notification-sync.yml` | Main website-health -> tested commit -> planner tests -> authenticated sync |
| User-safety tests | `notifications/tests/planner.test.mjs` | Late activation, DST, final-only songs, duplicate avoidance, times |
| Backend | `notifications/worker/src/index.js`, `wrangler.jsonc`, `schema.sql` | Cloudflare Worker, D1, VAPID, one-minute cron, per-subscription delivery state |
| Manual admin | `notifications/admin.html`, `admin.js` | Protected manual/scheduled notices; session-scoped token |
| Browser dry-run | `notifications/test.html` | Local permission/notification click verification; does not prove remote push |
| Policies and API | `notifications/README.md`, `notifications/backend-contract.md`, `notification-contract.schema.json` | Security and message contract |
| Backend health | `.github/workflows/notification-backend-health.yml` | Hourly and main push checks |

## Planned automatic notifications (maximum six per song)
1. Added to Prep (when actually newly registered early enough).
2. Aprendizaje start.
3. One Aprendizaje midpoint reminder when the phase is long enough.
4. Preparación final start, including estreno date.
5. Evening before estreno.
6. Estreno morning and service time.

Quiet hours: **9:00 PM to 8:00 AM America/New_York**. No automated post-release spam; bounded idempotency and retry policy. Human-readable message variants, no login required. Administrator sends are separately authenticated. Final-only songs suppress aprendizaje reminders.

## Security and non-negotiable safeguards
- Permission must be requested via a deliberate user click, never on load.
- No push subscriptions, messages or origin calls in normal Live until the user explicitly approves activation and the backend is validated.
- No private VAPID key, ADMIN_TOKEN, GitHub secret, D1 customer records, capability URL or subscriber information in chat/Markdown/source.
- Staging must **never** interact with or enroll people in production push.
- Validate authenticated backend readiness, CORS, scheduled event queue, device subscription/delivery and cleanup, one-minute cron, retries, device-specific iOS Home Screen requirements, suppression of stale reminders.
- Never bulk-send missed notifications after activation or resync.
- CI health and user-facing Web Push delivery are two separate verification levels.

## Resume work — not yet authorized
1. Re-check `main`/`staging` configs, Worker deployment, real backend health and exact GitHub workflow logs. Determine whether backend provisioning has been completed since the v166 README was authored.
2. Validate catalog-sync actual write (not just an Action success that could be a safe skip), and inspect queue/sent counts through the authenticated admin tool without exposing token values.
3. Test with a **separate explicitly consented test subscription/device** using service worker, real Web Push and click routing; validate Safari iPhone Home Screen path.
4. Confirm final UX wording/frequency, sending eligibility and manual admin access with user.
5. Prepare a controlled staged rollout without enabling staging's production subscriptions. Require the user's **separate explicit approval** before setting `enabled:true` on Live.
6. Add watchdog coverage for actual recipient delivery and operational observability as warranted; verify end-to-end, then document.

## Last completed and next resumption
2026-10-15 — Audited code, source catalog, Worker/D1 schema, current flags and recent backend/catalog workflows. Created this sidebar; **no notification state changed**. When user says "switch to sidebar Notifications", resume at step 1, not from the beginning, and maintain the gated status.
