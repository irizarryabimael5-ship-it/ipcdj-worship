# IPCDJ Worship — Song Request Email Notifications (STAGING ONLY)

**Destination (owner-chosen 2026-10-17):** `ipcdjofficial@gmail.com`.
The destination is in isolated Worker server-side settings only, not in public website JavaScript.
**Current status:** Cloudflare Email Service binding/sender domain NOT YET CONNECTED; no email delivery claimed or enabled. Main/Live unchanged.

## Intended transport
Cloudflare Email Service (Workers native `send_email` binding, structured `env.EMAIL.send`).
Cloudflare official references:
- https://developers.cloudflare.com/email-service/get-started/send-emails/
- https://developers.cloudflare.com/email-service/configuration/send-bindings/
- https://developers.cloudflare.com/email-service/api/send-emails/workers-api/
- https://developers.cloudflare.com/email-service/configuration/email-routing-addresses/

1. Owner: Cloudflare dashboard → **Compute → Email Service → Email Sending**, inspect the existing account setup and domains. Select the owned `ipcdj.org` zone **only if present**. If onboarding would create or change existing domain DNS, pause for owner review before applying; do not interrupt current church MX/routing.
2. Set up a verified sender on an Email Service domain (`solicitudes@ipcdj.org` is a candidate **not yet approved or verified**; do not use gmail.com as the outbound From address without owning Google's domain).
3. Owner: Cloudflare dashboard → **Compute → Email Service → Email Routing → Destination Addresses**, add `ipcdjofficial@gmail.com` and complete the verification link emailed there if not already verified. Do not create routing rules just to verify a destination.
4. After domain/sender and recipient verification, configure **only the isolated Staging Worker** via Wrangler `env.staging.send_email: [{"name":"EMAIL","destination_address":"ipcdjofficial@gmail.com"}]`. If an exact supported `allowed_sender_addresses` restriction can be combined, set it to the verified sender. **Do not add this binding in current release before Cloudflare setup is confirmed.**
5. Set `EMAIL_FROM` to the confirmed domain sender. It is not a secret; do not invent it. Maintain `EMAIL_NOTIFICATIONS_ENABLED=false` until after a controlled Staging smoke test proves actual receipt in the intended Gmail inbox.
6. Staging Worker Cron Trigger: `*/5 * * * *`. Each run checks its environment flags before touching D1/outbound email. The cron must not be copied to Live until owner authorizes final complete release.
7. After successful controlled testing, enable sending in Staging ONLY by a reviewed configuration change. Real requests still require the independent `INGEST_ENABLED` flag; frontend keeps the form disabled until intake, email, and publishing are all verified.
8. Once tests are complete, replace the current temporary Cloudflare deployment token (expires 2026-10-24 with account-wide D1 Write) with least-privileged Worker deploy credentials and separately scoped migration policy.

## Durable outbox behavior (code in src/email-outbox.js)
- The request POST transaction already persists one `request_outbox` event per new submission alongside the record.
- Cron claims due `new_submission` events with a conditional atomic UPDATE, increments attempt number, and leases the record for five minutes. At most 8 messages per batch.
- A valid Cloudflare Email Service `messageId` is accepted-provider acknowledgement and transitions that event to `sent`; **this is not proof that Gmail delivered it**. Human Gmail mailbox receipt and delivery logs must be inspected before calling transport certified.
- Transient failures update the D1 row to `retry` with exponential backoff; permanent recipient suppressions fail safely. A stale `sending` lease is reclaimed when due. Exhausted leases are marked `failed` rather than silently stuck.
- The message is **plain text** and only contains title, artist, a request ID and moderation reminder. No arbitrary external links, no contact details, no private admin token in email.
- This provides **at-least-once** notification semantics. A Worker can crash after the email provider accepts a message but before D1 records success; a retry in that narrow interval may produce a duplicate email. Never claim exactly-once delivery without provider-supported idempotency.
- No external user can invoke the Cron handler over HTTP; protected ADMIN_TOKEN API and existing origin controls remain independent.
- Do not log source secrets, recipient verification tokens, or mail-provider sensitive error messages. D1 stores safe machine-readable failure codes only.

## Release and testing
- Unit/SQLite tests mock `env.EMAIL.send` to prove disabled state, exact recipient binding guard, provider acknowledgement, temporary retry, permanent failure, stale lease recovery, concurrency race protection and max attempts. All tests must pass in GitHub Actions.
- Do not mistake mocked delivery for actual email. First real end-to-end test requires Cloudflare account sender configuration + owner approval and Gmail reception confirmation.
- No unfinished song-request sidebar may be promoted to Live, per explicit owner instruction.
