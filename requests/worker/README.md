# IPCDJ Worship — Song Requests Backend (Phase 1)

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
