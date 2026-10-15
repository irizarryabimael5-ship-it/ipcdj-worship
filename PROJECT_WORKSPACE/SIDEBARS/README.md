# IPCDJ Worship — Sidebars

Sidebars are optional/on-demand workstreams **within the same IPCDJ Worship website**, distinct from important [SIDE LANES](../SIDE_LANES/README.md) that may continue alongside MAIN. **Worship Semanal** is an active Side Lane, not an elective Sidebar. They are not separate websites, repository forks, external Drive folders or alternate song data stores.

| Name to say | Sidebar file | Current state |
| --- | --- | --- |
| "Sidebar Additional Features" | [ADDITIONAL_FEATURES.md](./ADDITIONAL_FEATURES.md) | Standby, scope on request |
| "Sidebar Notifications" | [NOTIFICATIONS.md](./NOTIFICATIONS.md) | Previously built, now paused and publicly disabled |
| "Sidebar iPhone App" / "Sidebar App Installation" | [IOS_APP.md](./IOS_APP.md) | Planned technical research |

## Sidebar entry protocol
1. User explicitly names a sidebar. Switch active context for the conversation, while retaining the MAIN lane checkpoint.
2. Read this sidebar's file, its primary source paths from [CONTENT_TREE](../CONTENT_TREE.md), last accepted decisions, unresolved work and latest actual repository/test state.
3. Present the sidebar's **status, last completed step, next step and boundaries** before implementing changes.
4. Keep a sidebar-specific mini-log and a `Next resumption` paragraph. Only change that sidebar or shared documents as the task requires.
5. Before switching out, write down the exact work achieved, current branch and commit, verification evidence, blockers and next actions. Update [HANDOFF_CURRENT](../HANDOFF_CURRENT.md) too.
6. Returning to MAIN restores its last scope; no sidebar continues running in the background.

## Shared principles
- The website codebase, catalog, tabs, SW and assets remain shared, not copied for each sidebar.
- A sidebar can be scoped and documented without being active or deployed.
- Staging first; preserve production; user approval required for Live release.
- Don't enable notifications, buy a Developer account, publish an app, issue distribution certificates, or change production by merely switching to a sidebar.
- Handoff must include all sidebars whether active or paused.
