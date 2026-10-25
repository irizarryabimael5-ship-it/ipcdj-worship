# IPCDJ Worship — mandatory self-contained Markdown handoff protocol
Version: 3 | Established: 2026-10-15 | Owner interaction rule updated: 2026-10-24 | Applies to this chat and all successor chats.

## Permanent owner interaction rule — GitHub access unavailable (2026-10-24)
- The owner does **not** work in GitHub and will **never** manually run repository commands, scripts, patches, copy/paste code, or developer-console steps on behalf of this project. ChatGPT is the responsible GitHub operator when its connected tools are available.
- If the GitHub connector, authorization, write access, or required repository tool is unavailable or fails, **do not claim an edit, commit, deployment, or QA was performed**. Give one brief, direct status: **"GitHub access is unavailable right now, so I couldn't make this change. Ask me to try again when you're ready."**
- **Stop there and await a new explicit user request to retry.** Do not send command blocks, patches, scripts, setup instructions, manual workarounds, repeated connection attempts, or offers to have the user perform the work. Do not fill the conversation with proposed implementation when blocked.
- After a user explicitly requests a retry, check current connector access and current branch HEAD before resuming the original change. Never assume an earlier failed attempt executed. Preserve staging-first and separately approved Live promotion boundaries.
- Carry this owner preference verbatim in future handoff/continuity packages so it survives chat migration. It is a conversational/operational rule and does not require any browser, website, or production runtime modification.

## Always-on capture
After each substantial task and before switching lanes:
- Update the specific lane file (`MAIN_LANE.md`, matching `SIDE_LANES/*.md` or matching `SIDEBARS/*.md`), including recent decisions, last action, status, blocker, next precise task, tests and source files.
- Update `CHANGELOG.md` with date, active lane, exact paths, commit(s), evidence and whether staging or live was touched.
- Update `HANDOFF_CURRENT.md` with active lane, all other sidebar states and any new branch/commit/test or unresolved issue.
- Update `CONTENT_TREE.md` if files, folders, assets or controls move.
- Update top `README.md` if a sidebar is added/removed or its state transitions materially.
- Keep user choices and denials separate from inferred ideas. State facts versus open hypotheses clearly.

## Migration trigger
When the user asks for a new room/chat, conversation becomes too long, or a handoff is requested:
1. Read the latest `PROJECT_WORKSPACE` README, MAIN_LANE, all SIDE_LANES and all SIDEBARS, current handoff, changelog, content tree, `SITE_STANDARDS.md`, `STAGING_POLICY.md`, `monitoring/WATCHDOG_POLICY.md`.
2. Verify live/main and staging HEAD SHAs and relevant GitHub Actions on the exact head. Record latest statuses; don't overclaim queued/running/cancelled tests.
3. Build **one standalone** `IPCDJ_WORSHIP_HANDOFF_YYYY-MM-DD.md`, preferably commit an archival copy under `PROJECT_WORKSPACE/HANDOFF_ARCHIVE/`, and give the user its downloadable .md copy when file tooling can create and verify the path. That file is self-contained enough for a new chat to restart without reviewing prior conversation history.
4. The handoff MUST contain:
   - product and domain, canonical repository and environment boundaries;
   - *active* lane and why it is active;
   - exact live/staging refs, latest user-approved presentation and unpromoted staging-only changes;
   - current visual, song-lifecycle, audio, PWA and archive invariants;
   - **Worship Semanal** (ongoing Side Lane): exact verified Friday/Sunday current sets, published state, historic archives, member resources, pending content and rollover expectations, without inventing songs;
   - summary and explicit status of **every Side Lane and every Sidebar**, even paused/future ones;
   - notification system gate, config state, backend state and links to original source;
   - iPhone app/PWA goals and native signing constraints;
   - recent changes, tests/run links, failed experiments and backups;
   - unresolved bugs, user-reported behavior vs code-derived hypothesis;
   - immediate next steps for each lane, deployment approval requirements and outstanding decisions;
   - repository content tree and paths to all relevant docs;
   - evidence dates and a clear `WHAT MUST NOT CHANGE` section.
5. Validate the archived file and file paths before telling the user handoff is complete.
6. In the next room, read the Markdown archive and source paths; reconnect GitHub; verify actual heads and status; resume the **active** lane unless the user explicitly switches.
7. **Do not access Google Drive** as a prerequisite: user explicitly scoped this project workspace to its own GitHub repository.

## Safety and completeness rules
- No shared secrets or user-specific push subscriptions in handoffs.
- No claims of background activity, unseen test passes or completed promotion.
- Never turn a previous user's visual approval into release approval.
- Do not include unapproved speculative sidebars as if implemented.
- Do not overwrite production just to make staging match; preserve environment isolation.
- Handoff is a snapshot; repository code plus recent GitHub Actions remain authoritative.

## Side Lanes are recurring and parallel
MAIN remains responsible for UI/UX/performance. [WEEKLY](SIDE_LANES/WORSHIP_SEMANAL.md) remains active for member-facing Friday/Sunday sets even while the current conversation focuses MAIN. Every new chat must resume MAIN and be ready to update WEEKLY immediately; read its file and source. Sidebars remain separate, optional and typically paused. One migration Markdown must include ALL workstream classes and their last checkpoints.
