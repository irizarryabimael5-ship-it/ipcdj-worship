# IPCDJ Worship — Push Notification Foundation

Status: **Dormant foundation only.**

Nothing in this directory is imported by `index.html` or `sw.js` yet. The current website does not request notification permission, subscribe devices, contact a push backend, register push handlers, or change runtime behavior because of these files.

## Goal

Prepare one standards-based notification architecture that can later support:

- song phase-entry notifications;
- estreno reminders;
- release-day notifications;
- weekly Live Set publication / update notifications;
- future notification categories the ministry decides to add.

The system must work through standards-based Web Push rather than browser-specific notification products.

## Platform principles

1. Use feature detection, not browser-name detection.
2. Use the existing HTTPS service worker as the future persistent-notification surface.
3. Never call `Notification.requestPermission()` or `PushManager.subscribe()` automatically.
4. Permission/subscription must originate from a deliberate user action in the future Notifications settings UI.
5. iPhone/iPad users should be guided to the installed/Home Screen web-app experience when required.
6. The notification system must remain optional. Refusing notifications cannot affect any website feature.
7. Subscription endpoint URLs and encryption keys are secrets/capability URLs and belong only in the secure backend store.
8. The client must never contain the VAPID private key.
9. Notification schedules must be generated server-side. Do not depend on browser timers or periodic background execution.
10. Use the same canonical song/event dates as the website so UI state and push state cannot disagree.

## Foundation files

- `notification-foundation.js` — side-effect-free client capability / subscription helpers.
- `sw-foundation.js` — side-effect-free service-worker payload and click-routing helpers.
- `notification-contract.schema.json` — versioned push payload contract.
- `event-catalog.json` — draft event taxonomy and preference categories. No event is activated here.
- `backend-contract.md` — secure backend/subscription/scheduler interface.

## Future activation order

### Stage 1 — User-facing settings
Add a Notifications section to IPCDJ Worship that:
- detects support;
- explains install requirements when needed;
- shows current permission/subscription state;
- lets the user choose notification categories;
- only requests permission after a user taps an explicit enable control.

### Stage 2 — Push backend
Deploy a small HTTPS service with:
- VAPID keypair;
- subscription create/update/delete endpoints;
- anonymous installation identifiers;
- preference storage;
- expired-subscription cleanup;
- CSRF/origin validation, abuse/rate protections, and secret handling.

### Stage 3 — Service-worker activation
Import or integrate `sw-foundation.js` into `sw.js`, then add:
- `push`;
- `notificationclick`;
- optional `pushsubscriptionchange`.

Persistent notifications must be created with `ServiceWorkerRegistration.showNotification()`.

### Stage 4 — Event scheduler
Move/duplicate the canonical song schedule into a shared machine-readable source that both:
- the website phase renderer; and
- the backend event scheduler

consume.

The server creates idempotent events such as `song.phase.entered` or `live_set.published` and sends them only to subscriptions whose saved preferences permit them.

## Deliberately undecided

The following are intentionally not chosen until the ministry defines behavior:
- which event types are enabled;
- reminder lead times;
- quiet hours;
- whether reminders repeat;
- whether updates become push messages or silent in-app changes;
- Live Set publication cadence;
- notification wording;
- per-song overrides;
- badge-count rules;
- category defaults;
- whether administrators can send manual announcements.

This preserves flexibility without rewriting the transport architecture later.
