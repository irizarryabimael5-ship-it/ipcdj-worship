# IPCDJ Worship — Cloud-only Staging setup (PREFERRED)

Updated 2026-10-16. **User directive: all development, storage, deployment and runtime must remain in the cloud. No MacBook or local terminal is required, including during initial account setup.** The prior `PROVISION_STAGING.md` CLI method is optional/legacy, not the preferred or required path.

## Architecture / ownership
- GitHub `staging`: code, tracked changes, exact SHA, tests, deploy workflow, documentation. GitHub-hosted ephemeral runners execute deployment; nothing runs on a personal machine.
- Cloudflare D1: durable, isolated `ipcdj-song-requests-staging` database. Must never use Web Push D1 `e474b5be-f2a9-4c19-8756-f1adb0a5ef6a`.
- Cloudflare Worker: `ipcdj-song-requests-staging`, separate from existing notification Worker. Its config has `APP_ENV=staging`, `INGEST_ENABLED=false` by default.
- Cloudflare Turnstile: separate Staging widget restricted to `staging.worship.ipcdj.org`. Site key is public, secret is private.
- Email is **not yet implemented**; plan for authenticated Cloudflare email binding or approved provider, sent by the Worker independently of any laptop.
- Live production stays v201 until all three feature components (intake, notifications, automatic verified song cards), failure/recovery tests, seven-profile deployed health and real-device checks are green AND the user explicitly approves a single complete-feature release.

## Recorded provisioned D1 checkpoint (2026-10-16)
Cloudflare dashboard screenshot confirms Staging D1 created as **ipcdj-song-requests-staging**, UUID `62ecdd60-5805-402d-92aa-71269eeb6fd1`. It shows zero tables, which is normal before GitHub-hosted schema installation. The Staging Wrangler binding now contains this exact UUID; existing Web Push DB is independent. Database is not yet initialized, remote Worker not deployed, and no Cloudflare admin integration was executed by ChatGPT. Remaining account-side steps below.

## One-time browser-only Cloudflare account actions (no Terminal)
1. **DONE (owner verified)** — Cloudflare D1 `ipcdj-song-requests-staging` exists with UUID `62ecdd60-5805-402d-92aa-71269eeb6fd1`. Do not recreate it. Existing Web Push DB remains independent.
2. In **Turnstile**, create a managed widget whose permitted hostname is exactly `staging.worship.ipcdj.org`. Record the PUBLIC sitekey; keep the PRIVATE secret in Cloudflare.
3. In Cloudflare's **Account API tokens**, create a narrowly scoped token for this account with the required Workers deployment and D1 database-edit permissions. Do not grant global unrestricted access.
4. In GitHub repository Settings → Environments, create an environment named `ipcdj-requests-staging` and restrict deployment to the **staging branch**. Add approval protection if desired.
5. In the GitHub Environment's **Secrets**, add `IPCDJ_CF_STAGING_ACCOUNT_ID` and `IPCDJ_CF_STAGING_API_TOKEN`. Under **Variables**, add `IPCDJ_REQUESTS_STAGING_D1_ID` set to `62ecdd60-5805-402d-92aa-71269eeb6fd1`. Keep the API token out of files, commits and chat; repository or environment encrypted secrets are the intended storage. Never reuse the existing Web Push credentials.

## Cloud-only deployment pipeline — intentionally MANUAL until integration is complete
After the above browser actions, **do not press Run workflow**; GitHub documents that a manually dispatched workflow must exist on the default branch, whereas we are not modifying `main`. Instead, ask the project maintainer to create the one-file *authorized Staging deployment marker commit* `requests/worker/deploy-control.json` (changed from disabled to enabled, referencing the previously certified parent SHA) with commit message starting `Deploy IPCDJ requests Staging: `. The staging-only workflow triggers on that exact file change; all other pushes are ignored. The GitHub Environment `ipcdj-requests-staging` enforces branch protection and any required human review. The workflow:
- verifies exact branch, Staging Worker name and environment, `INGEST_ENABLED=false`, valid D1 UUID and that the UUID is NOT the existing Web Push D1;
- installs Wrangler on an **ephemeral GitHub-hosted runner**;
- substitutes the GitHub Environment DB UUID into that runner's transient Wrangler config (nothing written to your Mac or committed);
- applies the idempotent Staging SQL schema to that isolated Cloudflare D1;
- deploys only the **Staging requests Worker**. Live is never targeted;
- verifies the actual deployed remote /health endpoint reports intake, email and auto-publication all disabled. A missing/unhealthy URL fails certification.

**The presence of this workflow does NOT create a Cloudflare database, token, secret or Worker by itself. The initial marker is disabled and cannot deploy. An intentional staging-only marker commit is required, and the job verifies that only this file changed and the approved parent SHA matches.** It does not run automatically, and cannot run successfully until the above browser-only account setup is completed. Owner authorization to develop is NOT authorization to publish to Live.

## Worker secrets (browser-only, after Worker exists)
In Cloudflare Dashboard → Workers & Pages → `ipcdj-song-requests-staging` → Settings → Variables and Secrets, create:
- `ADMIN_TOKEN`: independently generated, securely random ≥32-character admin authorization token.
- `IP_HASH_SALT`: different securely random ≥32-character salt.
- `TURNSTILE_SECRET`: exactly the secret from the Staging Turnstile widget.

Select the **Secret** type, not plain-text public variables. A trusted password manager's built-in generator in the browser can create the first two values. Never paste these secrets into ChatGPT, into GitHub workflow logs, or into the repository. Future email provider secrets must also remain on Cloudflare.

Check that GET `/health` on the Staging Worker reports `intakeEnabled:false`, `notificationsEnabled:false` and `publicationEnabled:false`. The /v1/requests public feed may be empty. Do not enable actual submission intake until the form, notification delivery and safe publication system are tested together.

## Cloud-only ongoing maintenance (no personal machine dependency)
- Edit via GitHub or other browser-native cloud tools; run CI on GitHub-hosted runners; publish Workers to Cloudflare after tests. MacBook may be off indefinitely.
- Record every change's exact Git SHA, test run and deployment version; preserve production rollback tags/branches when ultimately publishing. `PROJECT_WORKSPACE/HANDOFF_CURRENT.md` and `PROJECT_WORKSPACE/SIDEBARS/FEATURES_SONG_REQUESTS.md` retain operational continuity.
- **Rollback distinction:** Git SHA restores source code, NOT Cloudflare D1 database contents. Use versioned forward SQL migrations, a deployment audit, and D1 point-in-time recovery or documented backups when the real DB is provisioned. Cloudflare D1 Time Travel retention depends on plan (currently 7 days on Free, 30 on paid). Restoration can overwrite data; obtain explicit approval and confirm restore point before execution. The database does not yet exist or have any verified backup.
- Keep a separate cloud-only Staging D1 and, upon final release, a distinct Production D1, never shared between sites.

## References
- [Cloudflare's official GitHub Actions guide](https://developers.cloudflare.com/workers/ci-cd/external-cicd/github-actions/)
- [Cloudflare D1](https://developers.cloudflare.com/d1/get-started/)
- [Cloudflare Worker secrets in dashboard](https://developers.cloudflare.com/workers/configuration/secrets/)
- [D1 Time Travel](https://developers.cloudflare.com/d1/reference/time-travel/)

## GitHub Actions default-branch nuance (2026-10-16)
Official GitHub documentation requires a `workflow_dispatch` workflow to be on the default branch to appear as a manually runnable workflow. A prior setup plan incorrectly assumed a Staging-only workflow would appear in the Actions `Run workflow` menu. This has been corrected: Staging-only `push` trigger scoped to a control-file change **and** a special commit message, with environment protections, explicit disabled marker, approved parent-SHA guard, backend test gate, an actual remote health check, and production untouched. A regular Staging code or docs commit cannot deploy this Worker. Source: https://docs.github.com/en/actions/how-tos/manage-workflow-runs/manually-run-a-workflow

### 2026-10-17 — Deployment failure note / token scope
First guarded GitHub rollout installed SQL schema but failed to deploy Worker code because Wrangler could not fetch Worker bindings/routes/metadata. The initial deploy step lacked `pipefail` and falsely reported success; fixed in latest workflow. Possible cause: per-worker Editor may not suffice for Wrangler's Worker metadata discovery in new granular permissions. Cloudflare's official Workers roles page documents account Workers product **Metadata Read-Only** plus specified-worker Editor as the least-privilege combination for visibility with edit limited to one Worker. Do not grant all-Worker Edit/Admin. The initial Worker is still presumed Hello World, not functioning song requests. Verify actual cloud Worker, request no public intake. Note D1 SQL schema now initialized by the first GitHub run. Next deploy requires a new exact parent-SHA marker commit; never force a rerun of stale authorized marker after Staging advances.
