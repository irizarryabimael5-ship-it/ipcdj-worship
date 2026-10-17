# IPCDJ Worship — Song Requests Backend (Phase 1)

**CLOUD ONLY:** [CLOUD_ONLY_SETUP.md](./CLOUD_ONLY_SETUP.md) is the default project setup and deployment procedure. GitHub-hosted CI/CD + Cloudflare Dashboard and D1; no local terminal or persistent user computer. The previous [PROVISION_STAGING.md](./PROVISION_STAGING.md) is an archived optional fallback, not a task to execute.

Status 2026-10-16: source and tests only. NO requests Worker deployed; NO public intake, email sends or automatic publishing; main/Live unchanged.

## Isolation
- New Cloudflare Worker: ipcdj-song-requests-staging. This is NOT the Web Push Worker.
- Separate database: ipcdj-song-requests-staging, never the existing Web Push D1.
- Root Wrangler config has no public route (workers_dev false). Only staging environment configured with Staging origin.
- APP_ENV must equal staging; all other environments fail closed at runtime.
- INGEST_ENABLED is false by default and must stay false until submission, email and auto publishing are integrated.
- Database ID 00000000-0000-0000-0000-000000000000 is a deliberately invalid placeholder; no actual Cloudflare database yet.
- Distinct Staging secrets required: TURNSTILE_SECRET, ADMIN_TOKEN (32+ random characters) and IP_HASH_SALT (32+ independent random characters).

## Endpoints
GET /health: environment flags without secrets. Health does not imply deployed service.
POST /v1/requests: exact Staging Origin + server-side Turnstile + Cloudflare client IP + IP rate limit. Persists submission + pending email outbox, not sent.
GET /v1/requests: read-only published-only feed; empty until future vetted publication stage.
GET /v1/admin/requests?status=pending: requires Bearer ADMIN_TOKEN; returns private review queue.
POST /v1/admin/requests/:id/review: Bearer ADMIN_TOKEN, approve/hold/reject. Approved is NOT published. All actions logged.

## SQL durability
- song_requests: canonical normalized title+artist, dedupe counter, private status, creation and last-submitted dates.
- request_submissions: hashed client UUID v4 idempotency and payload digest; retries do not duplicate submissions.
- request_rate_events: salted hashed Cloudflare IP only, limit 5 new submissions/hour; no raw IP stored.
- request_outbox: one unsent pending event per accepted new submission. Sending/retry is later phase.
- request_audit: admin moderation history.
- D1 atomic batch ensures song upsert, submission, outbox and rate-event commit or roll back together.
- Public feed omits private comments, raw source identity, submissions and moderation history.
- URL allowlist: individual Spotify track, Apple Music song/album, YouTube watch URLs only.
- JSON < 10 KB, field length and normalization restrictions, no public direct publication.
- Server-side Turnstile verification checks exact Staging hostname and action song_request, with strict timeout/failure handling.
- Existing song lifecycle/publish schedules and current disabled Web Push notifications remain separate.

## Tests
Run Node 22+ from requests/worker:
  node --check src/index.js
  node --test --experimental-sqlite test/requests.test.mjs
A Staging-only GitHub Action runs the syntax, SQLite API tests and environment isolation automatically. All tests use an actual isolated SQLite database with D1-compatible atomic-batch adapter (not production Cloudflare credentials).

## Remote deployment prerequisites (NOT completed)
1. Create NEW Cloudflare D1 database ipcdj-song-requests-staging, replace only the Staging Wrangler placeholder ID with its real UUID.
2. Apply schema from requests/worker: npx wrangler d1 execute DB --env staging --remote --file=./schema.sql --yes
3. Create Staging-only Turnstile widget allowing staging.worship.ipcdj.org. Provision exact Staging hostname, action and the three secrets with npx wrangler secret put NAME --env staging. Never paste secrets in GitHub or chat.
4. Deploy only with npx wrangler deploy --env staging. Keep INGEST_ENABLED=false. Verify public health flags and private paths.
5. Integrate public form/dynamic feed, reliable email sender/outbox retry, verified metadata enrichment and fully automatic high-confidence card publication. Test full end-to-end staging with real D1 and actual delivered emails before any final Live approval.

Production policy: NO piecemeal deployment of song requests to Live; final release must be complete and seven-profile certified.

## Phase 1 concurrency hardening
D1 also enforces the rolling-hour rate cap in a database trigger so simultaneous accepted submissions cannot evade the pre-check. A second trigger logs real committed administrator status transitions, with compare-and-swap updates to reject stale reviews. JSON is read in bounded chunks; missing Content-Length cannot force unbounded body buffering. Tests cover both constraints.

Provisioning automation and account-side checklist: [PROVISION_STAGING.md](./PROVISION_STAGING.md). Run `npm run provision:staging` only from a locally authenticated Cloudflare environment, not GitHub CI.

## Cloudflare D1 preparation (2026-10-17)
D1 automatically enforces foreign keys, so `schema.sql` intentionally omits `PRAGMA foreign_keys=ON` (not allowed as a D1 migration statement). The Node SQLite test harness enables the pragma locally before applying the identical schema and tests orphan FK rejection. Wrangler v4 verifies configured `secrets.required` at deploy. Before running the guarded Staging marker commit, set `ADMIN_TOKEN`, `IP_HASH_SALT` and the **newly rotated** `TURNSTILE_SECRET` on the existing `ipcdj-song-requests-staging` Cloudflare Worker under Settings → Variables and Secrets, with Secret type. These secret values must never be committed, logged, or pasted into chat. Until then do not trigger the deployment marker.


## 2026-10-17 — Staging v203 user-facing song-request form and published feed (under development)
Staging-only source now includes an accessible Spanish Solicitudes form (required title and artist, optional source URL and comment, no visitor contact info), a read-only D1-backed published list fetched from isolated Staging Worker, newest-first rendering in existing Después-themed cards, stable canonical deduplication, untrusted HTML escaping and safe provider media-host allowlist. Existing Háblame de Cerca Staging pilot retains verified album art / original preview behavior; no release schedule or managed song catalog changes. Unavailable previews have a fallback label; feed outages retain the existing pilot and last-known-good cards. Client: requests/client.js; connected via index.html (v203); sw.js PWA cache v203 and scripts/build-staging-pages.sh now include new asset. monitoring/tests/requests-system.spec.js exercises user form disabled, live-feed ordering, HTML injection safety, dedupe and offline fallback across all seven browser profiles. New Staging preflight validates JS syntax and dist asset. Exact-commit Staging CI results needed before browser certification; real-device audio not yet verified.
IMPORTANT FAIL-CLOSED POLICY: The public form stays disabled unless isolated Worker GET /health reports simultaneously intakeEnabled=true, notificationsEnabled=true, publicationEnabled=true, environment=staging, storageConfigured=true and the Turnstile widget initializes. Current Worker deliberately reports those features FALSE. No current public submission is accepted, no email notification is sent, and automatic publication/matching are NOT implemented. Frontend public Turnstile sitekey is not a private secret. Worker confidential keys reside in Cloudflare.
No changes to Live main. Staging Worker deployed separately under version 81fd9f01-8a7a-4598-953b-c329e3a7697e. This Staging website changeset does NOT trigger a Worker redeploy. Remaining: real delivered admin email and durable outbox retry; high-confidence metadata/artwork/audio matching + safe automatic publication; real Staging end-to-end form tests, full browser and owner physical-device certification; single explicit user-approved complete feature Live promotion. Temporary Cloudflare token broad D1 Write expires 2026-10-24; remove/restrict after bootstrap before long-term automation.


## 2026-10-17 — Administrator email confirmed; isolated Staging email outbox implemented (SOURCE ONLY)
Owner chose ipcdjofficial@gmail.com as the notification destination. No verified sender domain or Cloudflare Email Service binding was configured, so NO actual emails have been sent or claimed delivered. New src/email-outbox.js has private scheduled Worker email queue processor with D1 atomic conditional claims/lease, 8 batch cap, retry/backoff/permanent failure states, crash recovery, plain-text notification and strict authorized recipient + ipcdj.org domain sender guards. New SQLite tests prove disabled transport, acknowledgement, retry, exhaustion, stale leases and two concurrent processor calls; mock provider success is NOT Gmail delivery. Wrangler Staging config adds Cron `*/5 * * * *`, vars EMAIL_NOTIFICATIONS_ENABLED=false, EMAIL_TO=ipcdjofficial@gmail.com and empty EMAIL_FROM. Do not deploy a binding, allow email sends or enable intake without sender/recipient verification and owner confirmation.
Operational browser-only instructions: requests/worker/EMAIL_NOTIFICATIONS_SETUP.md. Next owner action: Cloudflare Compute > Email Service > Email Sending, inspect whether church domain ipcdj.org is onboarded; do NOT blindly change MX/SPF/DKIM or email routing. Separately verify ipcdjofficial@gmail.com under Email Routing > Destination Addresses if unverified. Sender may eventually be solicitudes@ipcdj.org but MUST be confirmed/verified first. Once ready, guarded Staging binding exactly destination_address ipcdjofficial@gmail.com, actual mock-to-provider test with Gmail inbox confirmation, then future separately approved configuration enablement. Whole feature Live release remains prohibited until integrated and user-approved. Temporary token expires 2026-10-24; account-wide D1 Write must be restricted/replaced.

Email setup reference: [EMAIL_NOTIFICATIONS_SETUP.md](./EMAIL_NOTIFICATIONS_SETUP.md).
