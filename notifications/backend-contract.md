# IPCDJ Worship — Push Backend Contract

Status: design contract only; no backend is deployed yet.

## Recommended shape

Keep GitHub Pages as the website host. Add a separate small HTTPS serverless service for Web Push.

The transport code should stay provider-neutral so the first implementation can use a serverless platform without coupling the website to that vendor.

Recommended logical components:

1. **Subscription API**
2. **Subscription / preference store**
3. **VAPID signing keypair**
4. **Event scheduler / publisher**
5. **Web Push sender**
6. **Delivery cleanup / observability**

## Security boundary

### Public client may contain
- VAPID public key;
- backend base URL;
- anonymous installation id;
- selected notification preferences.

### Public client must never contain
- VAPID private key;
- backend administrative secrets;
- database credentials;
- push-subscription records belonging to other devices.

Push subscription endpoint URLs are capability URLs and must be treated as secrets.

## Subscription record

Suggested storage shape:

```json
{
  "installationId": "uuid",
  "endpointHash": "stable-server-hash",
  "endpoint": "push-service capability URL",
  "p256dh": "browser encryption key",
  "auth": "browser auth secret",
  "expirationTime": null,
  "preferences": {
    "song_phases": false,
    "estreno": false,
    "live_set": false,
    "announcements": false
  },
  "timezone": "America/New_York",
  "locale": "es-US",
  "createdAt": "ISO timestamp",
  "updatedAt": "ISO timestamp",
  "lastSuccessfulPushAt": null
}
```

Do not require name, phone number, email address, or login merely to receive ministry notifications.

## Proposed API

### POST /v1/push/subscriptions
Create/update this installation's subscription.

Body uses the client foundation record:
- contractVersion
- installationId
- subscription
- preferences
- appBuild
- locale
- timezone

Server validates:
- HTTPS origin;
- allowed CORS origin exactly `https://worship.ipcdj.org`;
- payload sizes;
- required subscription keys;
- rate limits;
- CSRF/origin protections appropriate to the chosen deployment.

### PATCH /v1/push/subscriptions/:installationId/preferences
Update category preferences without forcing a re-subscribe.

### DELETE /v1/push/subscriptions/:installationId
Remove the stored subscription.

### GET /v1/push/config
Return only public configuration such as:
- VAPID public key;
- contract version;
- currently supported notification categories.

## Event scheduler

The server, not the browser, owns notification timing.

Use one canonical schedule source with explicit `America/New_York` timestamps for church/song events. The website renderer and server scheduler should consume the same versioned schedule data.

Each generated event gets an idempotency key. Before sending, the server checks whether that event/subscription pair has already been delivered. This prevents duplicate pushes from cron retries or deploys.

## Delivery rules

For each event:
1. load matching subscriptions;
2. filter by saved category preference;
3. build a version-1 payload matching `notification-contract.schema.json`;
4. send encrypted Web Push using VAPID;
5. record success/failure;
6. delete subscriptions when the push service reports a permanently gone/invalid endpoint (for example HTTP 404/410 where applicable);
7. retry only transient failures with bounded backoff.

## Click/deep-link rules

Payload URLs must stay on `worship.ipcdj.org`.

Examples for future use:
- `/?song=glorioso-dia`
- `/?section=live-set&set=2026-09-27`

The service worker should first focus an existing IPCDJ window when practical, then navigate/open the requested same-origin URL.

## Scheduling decisions intentionally deferred

Do not implement these until the ministry specifies them:
- exact send hour for phase entries;
- estreno reminder lead times;
- quiet hours;
- Sunday morning reminder policy;
- repeated reminders;
- per-song exceptions;
- Live Set publication trigger;
- Live Set update threshold;
- manual/admin announcements;
- badges.

## Operational recommendation

When backend implementation begins, choose a serverless environment that supports:
- HTTPS API routes;
- scheduled/cron execution;
- durable key/value or SQL storage;
- environment secrets;
- outbound HTTPS requests;
- logs/metrics.

Keep the adapter behind this contract so moving providers later does not require changing the PWA notification model.
