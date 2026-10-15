# IPCDJ Worship — mandatory self-contained Markdown handoff protocol
Version: 1 | Established: 2026-10-15 | Applies to this chat and all successor chats.

## Always-on capture
After each substantial task and before switching lanes:
- Update the specific lane file (`MAIN_LANE.md` or matching `SIDEBARS/*.md`), including recent decisions, last action, status, blocker, next precise task, tests and source files.
- Update `CHANGELOG.md` with date, active lane, exact paths, commit(s), evidence and whether staging or live was touched.
- Update `HANDOFF_CURRENT.md` with active lane, all other sidebar states and any new branch/commit/test or unresolved issue.
- Update `CONTENT_TREE.md` if files, folders, assets or controls move.
- Update top `README.md` if a sidebar is added/removed or its state transitions materially.
- Keep user choices and denials separate from inferred ideas. State facts versus open hypotheses clearly.

## Migration trigger
When the user asks for a new room/chat, conversation becomes too long, or a handoff is requested:
1. Read the latest `PROJECT_WORKSPACE` README, MAIN_LANE, all SIDEBARS, current handoff, changelog, content tree, `SITE_STANDARDS.md`, `STAGING_POLICY.md`, `monitoring/WATCHDOG_POLICY.md`.
2. Verify live/main and staging HEAD SHAs and relevant GitHub Actions on the exact head. Record latest statuses; don't overclaim queued/running/cancelled tests.
3. Build **one standalone** `IPCDJ_WORSHIP_HANDOFF_YYYY-MM-DD.md`, preferably commit an archival copy under `PROJECT_WORKSPACE/HANDOFF_ARCHIVE/`, and give the user its downloadable .md copy when file tooling can create and verify the path. That file is self-contained enough for a new chat to restart without reviewing prior conversation history.
4. The handoff MUST contain:
   - product and domain, canonical repository and environment boundaries;
   - *active* lane and why it is active;
   - exact live/staging refs, latest user-approved presentation and unpromoted staging-only changes;
   - current visual, song-lifecycle, audio, PWA and archive invariants;
   - summary and explicit status of **every sidebar**, even paused/future ones;
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
