# IPCDJ Worship Staging Policy

## Environments

- Production branch: `main`
- Production URL: `https://worship.ipcdj.org/`
- Staging branch: `staging`
- Staging URL: `https://staging.worship.ipcdj.org/`

## Non-negotiable deployment rule

When the user asks for work "in staging", "in test", "in the test environment", or equivalent language:

1. Do not modify `main`.
2. Make all runtime/code/watchdog changes on `staging` only.
3. Validate the staging deployment and its watchdogs.
4. Keep production unchanged until the user explicitly approves promotion.

Promotion language may include:
- "approved, push it live"
- "promote staging"
- "this can go live"
- another explicit statement that the tested staging feature is approved for production.

Do not infer production approval from positive feedback alone.

## Staging isolation

Staging must remain isolated from production side effects:

- Search indexing blocked by HTML robots metadata, `robots.txt`, and Cloudflare `X-Robots-Tag`.
- Production push subscription/reconciliation disabled on staging and Pages preview hostnames.
- Notification catalog sync remains production-only and must never run from a staging health pass.
- Production social-preview verification remains production-only.
- Service workers and browser caches are naturally origin-separated by the staging hostname.

## Watchdogs

Every substantive staging feature must receive the same watchdog co-development treatment as production.

The staging watchdog must:
- verify `meta[name="ipcdj-environment"]` is `staging`;
- verify the staging noindex contract;
- compare exact deployed `index.html` and `sw.js` bytes with the staging branch;
- run the complete Chromium / Firefox / WebKit desktop/mobile/tablet matrix;
- use a separate `IPCDJ Staging Health Alert` issue and never mutate the production health alert.

If the staging endpoint has not been connected yet, the staging workflow should skip certification without marking production unhealthy.

## Promotion procedure

Once the user explicitly approves a staging version:

1. Confirm staging watchdogs are green on the exact approved staging commit.
2. Fetch the current `main` head again.
3. Create a production rollback branch from that exact `main` head.
4. Promote only the approved runtime/feature/watchdog changes.
5. Do not promote staging-only isolation files/settings.
6. Deploy `main`.
7. Run and require the production watchdog suite to pass on the exact deployed head.
8. Report the production commit and rollback branch.
9. Reconcile/reset staging from the new production baseline while restoring staging isolation.

## Staging-only infrastructure

These must not be copied into production as feature changes:

- `_headers` staging noindex/environment headers
- staging-only `robots.txt`
- staging-only notification configuration/guards
- `.github/workflows/staging-health.yml`
- `meta[name="ipcdj-environment"]` and staging-only robots metadata
- staging-specific watchdog expectations

The objective is production-equivalent behavior with staging-only safety boundaries.
