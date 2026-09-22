# IPCDJ Worship — Notification Platform

Status: **v166 implemented and browser-tested, runtime-gated until the push backend is provisioned.**

The website, service worker, autonomous planner, browser subscription client, manual sender, D1 schema, Cloudflare Worker sender, cron dispatcher, catalog-sync workflow, and watchdog coverage are all present in this repository.

`notifications/config.json` intentionally keeps `enabled:false` until the backend is live. While false:
- no notification permission is requested;
- no browser subscribes to push;
- no backend is contacted by normal visitors;
- the Notifications card stays hidden;
- every existing website feature continues normally.

## Product behavior

Automatic notifications are generated only for managed songs in preparation. The default sequence is intentionally bounded to six moments:

1. **Added to preparation** — shortly after a future song becomes active.
2. **Learning week starts** — Monday/phase-start morning.
3. **Learning check-in** — one mid-learning reminder when the learning window is long enough.
4. **Final preparation starts** — includes the estreno date.
5. **Estreno eve** — one last-rehearsal/repaso reminder.
6. **Estreno day** — morning-of reminder with service time.

There are no post-release automatic pushes and no daily reminder loop.

Quiet hours are 9:00 PM–8:00 AM America/New_York. Phase notifications are scheduled at deliberate human times rather than midnight lifecycle boundaries.

## Human wording

Each phase owns six approved short Spanish title ideas and six approved short Spanish body ideas.

The planner independently selects title/body variants using a deterministic event key, yielding up to 36 natural combinations per phase while keeping retries identical. This prevents duplicate wording from cron retries and avoids the site sounding like a fixed template every song.

Automatic messages know the canonical song title, estreno date, and service time directly from the song record.

## Single source of truth

`SONG_CATALOG_SOURCE` in `index.html` remains the only authored song schedule.

After the main **IPCDJ Website Health** workflow completes successfully, `.github/workflows/notification-sync.yml`:
1. checks out the exact tested commit;
2. runs the notification planner tests;
3. exports the canonical song lifecycle;
4. syncs it to the push backend.

If `IPCDJ_PUSH_ADMIN_TOKEN` is not configured, the sync exits successfully without sending anything.

A new song must never be manually scheduled in a second notification file.

## Late activation / outage safety

The planner never replays old reminders in bulk.

- “Added” is generated only if the backend first sees the song before its learning phase begins.
- Scheduled events older than the five-minute scheduler grace window are excluded when a plan is rebuilt.
- Sent events remain sent across catalog resyncs.
- Event keys are idempotent.
- Delivery state is tracked per subscription.
- Expired 404/410 push endpoints are disabled automatically.
- Transient failures are retried with a bounded attempt count.

## User opt-in behavior

Notification permission is never requested automatically.

When enabled:
- desktop/Android/supporting browsers can subscribe from the normal website;
- iPhone/iPad users are guided to add IPCDJ Worship to the Home Screen and enable notifications from the installed web app;
- denying notifications does not affect any other website feature;
- users can unsubscribe from the same control.

The notification icon uses IPCDJ's white-background/black-logo app artwork. The visible notification icon uses the 512×512 PNG source for high-quality OS downsampling; the badge fallback uses the 192×192 IPCDJ asset. The vector SVG remains the master artwork.

## Immediate browser/device test

`/notifications/test.html` is an isolated no-index test surface for validating notification support before remote Web Push is activated.

It does not contact the push backend or subscribe the browser. After an explicit button press it:
- verifies HTTPS / secure context;
- verifies Notifications API;
- verifies the root IPCDJ service worker;
- reports whether PushManager is available;
- requests notification permission only from that deliberate click;
- calls `ServiceWorkerRegistration.showNotification()` using the production IPCDJ icon;
- writes the production-style click target into notification data so the real `notificationclick` handler opens/focuses IPCDJ Worship.

This proves the browser-side notification surface and click routing. It does **not** prove remote server-to-browser delivery; that requires the Worker/VAPID backend and a real PushSubscription.

## Manual notifications

`/notifications/admin.html` is an unlinked, no-index admin console.

It supports:
- immediate send;
- scheduled send;
- normal/high urgency;
- short title/body;
- same-site tap destination.

The administrative token is entered by the administrator and stored only in `sessionStorage`. It is never committed to GitHub.

The backend independently validates authorization, browser origin, title/body lengths, time, TTL, and destination URL.

## Backend

The production backend is designed for Cloudflare Workers + D1:

- Worker: `notifications/worker/src/index.js`
- D1 schema: `notifications/worker/schema.sql`
- Wrangler config: `notifications/worker/wrangler.jsonc`
- Web Push: `@block65/webcrypto-web-push@2.0.0`
- scheduler: one-minute Cron Trigger
- API target: `https://push.worship.ipcdj.org`

The sender uses standards-based Web Push/VAPID rather than a vendor-specific browser SDK.

## One-time production activation

These operations require access to the church's Cloudflare/GitHub account and therefore are intentionally not stored in this repository.

From `notifications/worker`:

```bash
npm install
npm run db:create
npm run db:remote
npm run credentials:generate
```

`db:create` asks Wrangler to create `ipcdj-worship-push` with binding `DB` and update `wrangler.jsonc` with the returned database id. `credentials:generate` produces one VAPID keypair plus a 256-bit admin token locally; it does not save them to the repository.

Store the three generated values as Worker secrets:

```bash
npx wrangler secret put VAPID_PUBLIC_KEY
npx wrangler secret put VAPID_PRIVATE_KEY
npx wrangler secret put ADMIN_TOKEN
```

Deploy:

```bash
npm run deploy
```

Then connect the Worker to the Custom Domain `push.worship.ipcdj.org`.

In GitHub repository settings, add:
- Actions secret: `IPCDJ_PUSH_ADMIN_TOKEN` = the same admin token.
- Actions variable: `IPCDJ_PUSH_API_ORIGIN` = `https://push.worship.ipcdj.org`.

Verify:
- `https://push.worship.ipcdj.org/health`
- `https://push.worship.ipcdj.org/v1/config`
- admin health through `/notifications/admin.html`
- autonomous catalog sync workflow succeeds.

Only after those checks pass, change `notifications/config.json` to:

```json
{
  "enabled": true,
  "apiOrigin": "https://push.worship.ipcdj.org",
  "siteOrigin": "https://worship.ipcdj.org",
  "timezone": "America/New_York",
  "version": 2
}
```

That final toggle exposes the opt-in card and allows browser subscriptions.

## Security / privacy

No login, name, phone, email, or precise location is required for a notification subscription.

Stored subscription data is limited to the Web Push capability endpoint/keys and small device metadata needed to operate the subscription.

The VAPID private key, admin token, and database control credentials are never public client assets.

Push click destinations are restricted to IPCDJ same-origin paths.

## Watchdog

The normal site-health workflow now validates:
- planner unit tests;
- D1 schema execution and required tables;
- D1 helper scripts target the real `DB` binding;
- offline VAPID/admin credential generation;
- stale-reminder prevention;
- DST-aware scheduling;
- short/deterministic human wording;
- JavaScript syntax for client/UI/service-worker foundation/Worker/sync scripts;
- canonical catalog export;
- notification assets on production;
- `push` and `notificationclick` handlers;
- no automatic permission state change;
- all existing cross-platform site invariants.

The main seven-profile Playwright matrix remains authoritative for website compatibility.
