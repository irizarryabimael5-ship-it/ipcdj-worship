# IPCDJ Worship — Optional local provisioning (NOT THE ACTIVE WORKFLOW)

> **CLOUD-ONLY DIRECTIVE (2026-10-16):** The user requires everything to reside in the cloud and does not want local Terminal or laptop-dependent operations. Use [CLOUD_ONLY_SETUP.md](./CLOUD_ONLY_SETUP.md) and the manually gated GitHub-hosted Cloudflare deployment workflow instead. All Mac/CLI steps below are merely an archived, optional fallback; **do not instruct the user to run them** as part of the active project.


Status: account-side actions required. This is for the new isolated song requests Worker and database, never the existing Web Push platform. No song-request functionality can be promoted to Live until the entire feature is finished and certified.

## 1. Authenticate from your Mac

From an up-to-date local clone of the IPCDJ repo, with the staging branch checked out:

    git switch staging
    git pull --ff-only
    cd requests/worker
    npm install --no-audit --no-fund
    npx wrangler login
    npm test

This opens Cloudflare authentication in your own browser. Never send credentials or secret tokens to ChatGPT or GitHub.

## 2. Provision the separate Staging database automatically

    node scripts/provision-staging.mjs

The script checks Staging-only config, lists existing D1 databases, creates ipcdj-song-requests-staging only if it does not already exist, validates its UUID, updates the local Wrangler config after creating a backup, and applies the SQL schema idempotently.

It refuses the existing ipcdj-worship-push database, ambiguous/multiple matching databases, unexpected environment changes, and a mismatching existing D1 binding. It does NOT deploy a Worker, enable submissions, update Live, or send an email.

Do not commit the local wrangler.jsonc.before-staging-d1 backup. The actual Staging database ID is a nonsecret resource identifier, but should be reviewed before committing a config change.

## 3. Create a separate Staging Turnstile widget

Open Cloudflare Dashboard > Turnstile, create a new widget for the hostname staging.worship.ipcdj.org only, and keep its public sitekey for website integration. Its secret must remain confidential. The backend validates both hostname and action song_request using the server-side Siteverify endpoint.

References:
https://developers.cloudflare.com/turnstile/get-started/
https://developers.cloudflare.com/turnstile/get-started/client-side-rendering/

## 4. Create isolated Worker secrets

From requests/worker in your own terminal:

    openssl rand -hex 32 | npx wrangler secret put ADMIN_TOKEN --env staging
    openssl rand -hex 32 | npx wrangler secret put IP_HASH_SALT --env staging
    npx wrangler secret put TURNSTILE_SECRET --env staging

For TURNSTILE_SECRET, paste the confidential value at the terminal prompt, never into a chat or public repository. If values are already configured, don't rotate them on reruns. Each secret belongs to the new requests Worker, not the push Worker. Cloudflare notes that secret put can create a Worker version/deployment, so the config must continue to have INGEST_ENABLED=false.

## 5. Deploy the isolated Staging Worker, after verifying bindings

    npx wrangler deploy --env staging
    npx wrangler secret list --env staging

Save the public workers.dev origin shown by Wrangler. Fetch /health on that origin. It must report APP_ENV staging, intakeEnabled false, notificationsEnabled false, publicationEnabled false, and storageConfigured true. GET /v1/requests should show an empty published list. POST /v1/requests should refuse submissions with intake-unavailable (503) until all the form, email, enrichment, publication, and safety checks are in place.

## 6. Resume integrated feature build

Share only the *public* workers.dev URL and Turnstile *public* sitekey with this conversation, plus a redacted success/error log if needed. Never send ADMIN_TOKEN, IP_HASH_SALT, TURNSTILE_SECRET, Cloudflare password or API tokens.

Once the real isolated D1 and Turnstile services exist, integrate site form and dynamic public feed with Staging, implement outbox email delivery and retries, then automatic exact-match metadata enrichment and card rendering. Verify actual submissions, delivered emails, Web Audio playback, and all seven browser profiles before final approval to promote one complete feature to Live.

Cloudflare CLI docs:
https://developers.cloudflare.com/workers/wrangler/commands/d1/
https://developers.cloudflare.com/workers/wrangler/commands/workers/
