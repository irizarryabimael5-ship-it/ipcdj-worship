# IPCDJ Worship — Project Workspace (canonical navigation)
Updated: 2026-10-15 | Repository: irizarryabimael5-ship-it/ipcdj-worship | Authoring branch: staging

## Purpose and scope
This is the project-specific working folder and durable written state of the IPCDJ Worship engineering chat. All project coordination and the future handoff live here **inside this GitHub repository**, not in Google Drive or any other project's files. Source code remains in its existing locations; this folder contains workstream state, boundaries and navigation, not copies of production data.

## Main Lane, Side Lanes, and Sidebars
**MAIN:** continuous site-wide UI, UX, performance, reliability and functionality.
**SIDE LANES:** important recurring operational work that can run concurrently with MAIN. **WEEKLY / Worship Semanal** is ACTIVE for current Friday/Sunday sets and team resources; use [SIDE_LANES/README.md](SIDE_LANES/README.md) and [WORSHIP_SEMANAL.md](SIDE_LANES/WORSHIP_SEMANAL.md).
**SIDEBARS:** optional, paused or exploratory feature development (Additional Features, Notifications, iPhone App), normally entered only by request.

"Update Worship Semanal" routes to WEEKLY and leaves MAIN available; "MAIN + WEEKLY" tracks both simultaneously. Returning focus to MAIN never pauses WEEKLY. All workstreams share a codebase and are included in each Markdown handoff.

## Lane dashboard
| ID | Lane | Status | Canonical file |
| --- | --- | --- | --- |
| MAIN | **Main Lane — platform-wide UI, experience, performance, stability and functionality** | ACTIVE | [MAIN_LANE.md](./MAIN_LANE.md) |
| SIDE LANE / WEEKLY | **Worship Semanal — current Friday/Sunday worship sets and history** | ACTIVE / PARALLEL | [SIDE_LANES/WORSHIP_SEMANAL.md](./SIDE_LANES/WORSHIP_SEMANAL.md) |
| FEATURES | Sidebar — additional features | STANDBY / INTAKE | [SIDEBARS/ADDITIONAL_FEATURES.md](./SIDEBARS/ADDITIONAL_FEATURES.md) |
| NOTIFICATIONS | Sidebar — notification platform | PAUSED / IMPLEMENTED-BUT-DISABLED | [SIDEBARS/NOTIFICATIONS.md](./SIDEBARS/NOTIFICATIONS.md) |
| IOS_APP | Sidebar — installed iPhone/iPad experience and potential native-app path | RESEARCH BACKLOG | [SIDEBARS/IOS_APP.md](./SIDEBARS/IOS_APP.md) |

**Primary focus: MAIN, with active ongoing parallel Side Lane WEEKLY.** Optional Sidebars stay on hold until requested. The same website and codebase may contain features associated with several lanes. Do not fork or duplicate the song schedule, notification config, app manifest or working code merely to create a lane.

## How to switch
- "Switch to sidebar Notifications" -> read the NOTIFICATIONS sidebar, its original linked source files and latest decisions; explicitly report the active lane.
- "Switch to sidebar Additional Features" -> FEATURES.
- "Switch to sidebar iPhone App" -> IOS_APP.
- "Back to main lane" -> MAIN, restoring its last checkpoint.
- "Status of all lanes" -> this dashboard plus each lane's state, with no implicit switch.
- If a request spans lanes, identify the owning lane, dependencies and shared files. Update each affected sidebar's notes, but do not silently switch workstreams.

## File ownership and boundaries
- Each lane's Markdown is **owned by that lane**. Edit it for facts, decisions, tasks, test results and resume position relating to that work.
- Main Lane owns cross-platform layout, motion, rendering, performance, current-song experience, content presentation and watchdog core.
- FEATURES owns the backlog/scoping of user-requested extras, not the implementation of notifications or iOS packaging.
- NOTIFICATIONS owns scheduling, permission prompts, Web Push, push backend, subscriptions, push delivery and notification-specific testing.
- IOS_APP owns installability, Home Screen behavior, iOS PWA polish, native/signed-app distribution research and team rollout.
- Shared application source is **not** partitioned: all source changes still require the standards, staging policy and watchdog.
- A new topic requested as a sidebar gets its own `SIDEBARS/<SLUG>.md` and index entry. Never invent approvals or start an inactive sidebar without direction.
- Do not search, read, organize, edit, or create Google Drive files for this workspace without a separate explicit instruction.

## Permanent owner interaction rule — GitHub access unavailable (2026-10-24)
- The owner does **not** work in GitHub and will **never** manually run repository commands, scripts, patches, copy/paste code, or developer-console steps on behalf of this project. ChatGPT is the responsible GitHub operator when its connected tools are available.
- If the GitHub connector, authorization, write access, or required repository tool is unavailable or fails, **do not claim an edit, commit, deployment, or QA was performed**. Give one brief, direct status: **"GitHub access is unavailable right now, so I couldn't make this change. Ask me to try again when you're ready."**
- **Stop there and await a new explicit user request to retry.** Do not send command blocks, patches, scripts, setup instructions, manual workarounds, repeated connection attempts, or offers to have the user perform the work. Do not fill the conversation with proposed implementation when blocked.
- After a user explicitly requests a retry, check current connector access and current branch HEAD before resuming the original change. Never assume an earlier failed attempt executed. Preserve staging-first and separately approved Live promotion boundaries.
- Carry this owner preference verbatim in future handoff/continuity packages so it survives chat migration. It is a conversational/operational rule and does not require any browser, website, or production runtime modification.

## Operating contract
1. Before any code change, consult `SITE_STANDARDS.md`, `STAGING_POLICY.md`, and `monitoring/WATCHDOG_POLICY.md`.
2. Work in `staging` first; don't update `main` without explicit user approval after testing. Do not infer approval from "looks good."
3. Preserve production-specific Open Graph/social preview, robots/indexing, notification activation and deployment configuration.
4. The current top visible Prep song always owns the animated ambient-background album-art palette.
5. Annotate each lane action with status and explicit evidence: `PLANNED`, `IN_PROGRESS`, `BLOCKED`, `TESTING`, `VERIFIED`, `PAUSED`. Distinguish live observations, source inspection, test runs and hypotheses.
6. An inactive lane can accumulate notes, but may not make production changes or interfere with another lane.
7. After a change, update that lane file, [CHANGELOG.md](./CHANGELOG.md), and [HANDOFF_CURRENT.md](./HANDOFF_CURRENT.md). Update [CONTENT_TREE.md](./CONTENT_TREE.md) if paths change.

## Continuity and handoff
- [Handoff protocol](./HANDOFF_PROTOCOL.md) — complete rules for generating a single self-contained migration Markdown file.
- [Current handoff source](./HANDOFF_CURRENT.md) — continuously maintained project-wide factual snapshot, all lanes included.
- [Content tree](./CONTENT_TREE.md) — source and document locations necessary for a new chat to orient itself.
- [Chronological log](./CHANGELOG.md) — what was done and where work stopped.
At chat migration, compile `IPCDJ_WORSHIP_HANDOFF_YYYY-MM-DD.md` from these files, include source paths/commit IDs/CI evidence and unfinished tasks in all lanes. Archive it in the repository and share a copy with the new chat. Do not rely on chat memory alone.

## Reference URLs
- Live: https://worship.ipcdj.org/ (main)
- Staging: https://staging.worship.ipcdj.org/ (staging)
- Approved Mac visual trial: https://staging.worship.ipcdj.org/?visual=original
- Repository: https://github.com/irizarryabimael5-ship-it/ipcdj-worship


## Active song-request sidebar and permanent migration checkpoint (2026-10-17)
Most recent owner-directed active workstream is FEATURES / Solicitudes de Canciones, integrated within same IPCDJ Worship product; MAIN and WEEKLY remain active in parallel, Web Push sidebar paused, iOS-app sidebar future. Latest complete migration archive [IPCDJ_WORSHIP_HANDOFF_2026-10-17.md](HANDOFF_ARCHIVE/IPCDJ_WORSHIP_HANDOFF_2026-10-17.md) supersedes historical v190-v202 status claims. The owner verified one actual controlled Gmail email was delivered from solicitudes@ipcdj.org to ipcdjofficial@gmail.com. One-time probe and automatic notifications/public intake remain OFF. Staging backend tests passed 39054643026, but seven-browser v203 website certification FAILED 39054643025 (9 cases); no feature-complete release authorization. Next chat FIRST answer deferred Cloudflare Free sending limits question for verified destination and projected ~100 requests across two years. Then continue safe Staging development; no partial Live promotion.

## Migration checkpoint — 2026-10-24
**Current owner-directed primary workstream: Solicitudes de Canciones (Staging-only)**, while WEEKLY continues as high-priority parallel operations and MAIN retains cross-site reliability ownership. Latest standalone handoff: [IPCDJ_WORSHIP_HANDOFF_2026-10-24.md](./HANDOFF_ARCHIVE/IPCDJ_WORSHIP_HANDOFF_2026-10-24.md). The two newly added Elevation Español request cards are already committed; no duplicate inserts. Production does NOT contain request tab. Live browser issue #36 remains open despite successful Pages deploy; see migration archive and fresh Actions. Legacy Oct15/Oct17 statuses elsewhere in this README are historical and not the current HEAD.
