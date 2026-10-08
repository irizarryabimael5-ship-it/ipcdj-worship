# IPCDJ Worship — One-Time Staging Connection

The repository-side staging environment is already prepared.

## Cloudflare Pages project

Create one Cloudflare Pages project dedicated only to staging.

Recommended project name:

`ipcdj-worship-staging`

Use these settings:

- Git provider: GitHub
- Repository: `irizarryabimael5-ship-it/ipcdj-worship`
- Production branch for this Pages project: `staging`
- Framework preset: None
- Root directory: repository root
- Build command: `bash scripts/build-staging-pages.sh`
- Build output directory: `dist`

This Cloudflare Pages project's "production" branch is only the staging website. It does not replace the real IPCDJ production site, which remains GitHub Pages from `main`.

## Custom staging domain

After the first successful Pages deployment, add:

`staging.worship.ipcdj.org`

as the custom domain for the staging Pages project.

Cloudflare DNS already manages the IPCDJ domain, so complete the custom-domain activation in the Pages dashboard.

## Expected staging safety contract

Once connected, the staging deployment must return:

- `X-IPCDJ-Environment: staging`
- `X-Robots-Tag: noindex, nofollow, noarchive, nosnippet`

The HTML must include:

- `meta[name="ipcdj-environment"] = staging`
- `meta[name="robots"]` containing `noindex`

The staging notification config must remain:

- `enabled: false`
- `apiOrigin: ""`
- `siteOrigin: https://staging.worship.ipcdj.org`

## Automatic verification

Every push to `staging` runs `IPCDJ Staging Health`.

Before the custom domain is connected, its preflight exits successfully and skips the browser matrix.

After the custom domain is connected, the workflow must:

1. verify the staging isolation contract;
2. compare exact deployed `index.html` and `sw.js` bytes against the `staging` branch;
3. run the complete seven-profile Playwright health matrix;
4. use the separate `IPCDJ Staging Health Alert` issue on failure.

## Day-to-day workflow

User instruction:

`Make this change in staging.`

Result:

- only `staging` changes;
- `main` and `https://worship.ipcdj.org/` remain untouched;
- staging watchdogs run;
- the user tests `https://staging.worship.ipcdj.org/`.

Production promotion requires explicit approval such as:

`Approved. Promote staging to live.`

Follow `STAGING_POLICY.md` for the production promotion and rollback procedure.

## Confirming a new staging release

A Git commit is not proof that Cloudflare Pages deployed it. After each staging update, compare the SHA of `staging` to the exact SHA of the Cloudflare Pages deployment and of the `IPCDJ Staging Health` run. Both should correspond to the current branch head. If no GitHub Actions or Cloudflare check is created for a new commit, investigate Git webhook delivery/Pages repository connectivity and branch controls rather than blaming browser cache or reporting the release as deployed.

Keep `main` unchanged until the staging deployment is confirmed and the user explicitly approves production promotion.
