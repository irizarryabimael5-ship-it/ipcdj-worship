# FEATURE SPEC — Solicitudes de Canciones
Lane: FEATURES / Request Songs | Created: 2026-10-16 | Status: SPECIFIED / MANUAL-LIVE-PILOT NEEDS SONG / NO BACKEND ENABLED

## User intention (16 Oct 2026)
Three connected deliverables:
1. A public **Solicitudes** tab where requested songs look like the existing **Después** cards: exact artist/title, original album artwork, derived background-gradient palette, a usable preview when available, and a simple **Solicitada** badge; cards stack top-to-bottom.
2. Prompt an administrator by email (preferred initial transport) or SMS when requests arrive.
3. Automatically create and publish verified cards to the Requests tab once the secure intake/review system is proven. The user wants to test one manually added song on Live *before* automatic publishing.

## Live / staging boundaries and present blocker
- 2026-10-16 Live release `96843728ce9227016cfc22c396849bc52d8250a0` certified via GitHub Actions production matrix `38931923748` SUCCESS; post-certification dynamic social-preview commit `8ae6689dffd66242a32eefe7c0f07b7a5055e031` succeeded. Staging's current v201 original motion preview remains separate; reconcile production runtime safety before implementing new features.
- The user has NOT provided the specific **song title / artist / recording** for the first manual Live pilot. **Do not invent a genuine request, infer an artist, duplicate an unrelated existing song as requested, or claim a Live test happened.** Request just the specific song and optional recording URL; artist/recording may be found and verified once song title is supplied.
- Standard Staging -> cross-browser watchdog -> user inspection -> selective approved Live promotion, even for the manual pilot. Production publishing requires explicit authorization for the actual staging version; general approval to investigate a sidebar is not blanket authorization for autonomous public submissions.
- No submission endpoint, email notification, phone number, Cloudflare credentials, live song request, or public tab deployed by this spec alone.
- Do not alter `SONG_CATALOG_SOURCE`, current or TBD song release dates, weekly worship service sets/history, campaign tabs, playlists, notification-platform `enabled:false`, social snapshot workflow, or existing visual-motion preferences.

## Navigation and cards (phase 1, manual pilot)
- Top-level nav sequence: `Inicio`, `Worship semanal`, `Solicitudes` (visible year-round, unlike ephemeral Campaña tab). Preserve tab focus, keyboard arrows, ARIA, mobile 320px wrapping/overflow and responsive third-tab styling.
- `Solicitudes` panel introduces what a request means, then visually groups published cards in a vertical `songs` list. Reuse established `.song-row`, `.future-themed`, `.future-artwork-blur`, `.future-artwork-ghost`, preview UI, theming and player behavior where feasible without duplicating IDs/engines; no fake dates, rehearsals or countdown.
- Card fields: unique request ID, canonical song key, normalized title and artist, verified recording/version, artwork URL + verified attribution/source, safe fallback palette, optional supported preview URL/provider/clip rules, `Solicitada` status, UTC submission/publish timestamps. No made-up preview: show `Adelanto no disponible` where provider lacks a legitimate usable clip.
- Newest accepted requests first, stable secondary ID sort; optionally one card per canonical recording with a numeric request count. Filter duplicates and songs already committed to a live release schedule. The `Solicitada` badge means community suggestion ONLY, not accepted/rehearsed/confirmed for worship.
- Performance: lazy image/audio loading, bounded artwork requests, cached palettes, reduced-motion support, graceful fallback and no cross-tab preview playback regressions.
- First real manual trial uses a user-named track with verified title/version and supported artwork/preview. Site owner approves the exact card in Staging before a controlled one-card Live deployment. This tests card rendering with the full seven-profile matrix and verifies production runtime/OG/notifications isolation.

## Intake and notification flow (phase 2, gated)
- Public form: title (required), artist (required or verified via linked track), optional source URL, optional non-sensitive comment. No visitor phone/email is necessary by default; disclose limited data retention.
- Backend: Cloudflare Worker endpoint, D1 relational database for durable requests/status history, Turnstile server-side verification, origin validation, UTF-8 normalization, length caps, allowlisted source URLs, abuse throttles/rate limits, duplicate and replay/idempotency protections, and escaping for all rendering and email content.
- Initial process: submission -> persisted `pending` state -> mail notification queued/sent -> administrator approval of match/artwork/preview -> `published` -> public read-only feed. On mail failure, persist pending request and retry via durable delivery/outbox; do not lose it or falsely say it was mailed.
- Preferred delivery: Cloudflare Email Service email binding to a **verified** admin destination; requires user-configured provider account, sender verification if required, secret/binding and explicit recipient selection. Alternative Resend Worker integration; SMS optional via Twilio with appropriate sender registration/fees. Do NOT embed recipients, tokens, API keys or access tokens in public HTML or commits. Do not turn on the existing independent Web Push Notifications Sidebar.
- No auto-deployment based on untrusted client input; admin decision is authenticated server side and auditable.

## Automatic enrichment and publication (phase 3, separately authorized)
- On valid request, attempt exact/near-exact matching of title, artist, version from permitted metadata sources. Reject low-confidence variants; ask for correction when ambiguous.
- Background jobs retrieve artwork and optional preview from permitted providers subject to access and rights, derive gradient safely, cache results, and persist a reviewed final record. Do not scrape/republish copyrighted songs or full tracks. Never fabricate a preview or assert wrong artist/artwork.
- Progressive automation: begin with explicit admin approval -> verify duplicate canonical key and deterministic rendering; later permit auto-publication ONLY for high-confidence, fully validated, abuse-screened requests when owner explicitly approves that policy. Unknown/ambiguous content always remains pending.
- Public read-only `GET /requests` feed from D1; client dynamically renders confirmed `published` records, with short cache/ETag and last-known-good fallback. Avoid per-request GitHub commits or changes to main song-release catalog. Keep public statuses `Solicitada` and `Programada` distinct.
- Failure behavior: fall back to stable palette, no preview when unavailable, retry transient metadata/email failures, safeguard empty list, error banner for intake outages, and no inadvertent duplicate insertions.

## Mandatory tests / acceptance
- Existing seven Chromium / Firefox / WebKit desktop/mobile/tablet profile coverage unchanged.
- New tests: third tab navigation click/keyboard/focus and hidden states; responsive 320px; one verified manual card; cover-to-palette binding; preview start/stop/transfer and provider failure; duplicate key handling; newest-first stacking and stable sorting; status label; long titles/accents; reduced motion; malicious HTML injection; idempotent Worker submission; Turnstile failure; throttling; admin-only approval; outbox failure and retry; no client-side secret leakage; no release scheduling side effects.
- Production verification: exact main SHA, public `index.html` & `sw.js` bytes, site-health matrix, requests tab content/card, correct production OG snapshot/indexing, notifications still disabled, rollback SHA and staging isolation. Never claim a green matrix until the exact commit run finishes.

## Current state
Only engineering scope/spec captured. First manual pilot song is still needed to implement an authentic Live-requested card. No external service credentials have been configured and no public request intake is active.

## Provider docs checked (2026-10-16)
- Cloudflare Turnstile: https://developers.cloudflare.com/turnstile/get-started/server-side-validation/
- Cloudflare Email Service Workers binding: https://developers.cloudflare.com/email-service/api/send-emails/workers-api/
- Cloudflare Email Service pricing: https://developers.cloudflare.com/email-service/platform/pricing/
- Cloudflare Worker / Resend alternative: https://developers.cloudflare.com/workers/tutorials/send-emails-with-resend/
- Twilio US SMS: https://www.twilio.com/en-us/sms/pricing/us
