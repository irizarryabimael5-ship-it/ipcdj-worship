# SIDEBAR — Additional Features
Lane ID: FEATURES | State: **ACTIVE / SONG REQUESTS INTEGRATED BUILD** | Updated: 2026-10-16

## Purpose
Optional new features to extend IPCDJ Worship beyond the core Main Lane's UI, animation, reliability, established tabs and normal lifecycle. Changes originate from the user's request, not from automatic ideation or exploratory installation.

## Scope and routing
- New website utilities, additional navigation capabilities, content-facing conveniences and feature concepts belong here **unless** they primarily concern Web Push or app installation; those have dedicated sidebars.
- Improvements to an existing core component's look, performance or stability stay MAIN unless user specifies this sidebar.
- Each approved feature receives a child folder or linked spec when it becomes a real project, with proposal -> constraints -> design -> implementation -> watchdog -> staging review -> production promotion.
- Do not change `index.html` tabs, history, song information, live playlists or audio systems merely because the sidebar exists.

## Existing authoritative features (not new requests)
`index.html`: En Preparación, Semanal (Viernes/Domingo), Campañas/history, current song countdown and preview, upcoming and introduced songs. `sw.js`: offline/PWA shell. These remain owned by Main Lane or existing code, not cloned here.

## Queue
| Feature | State | Decision |
| --- | --- | --- |
| **Solicitudes de Canciones** | **V202 PROTOTYPE CERTIFIED / FULL BACKEND PENDING** | [Dedicated song-requests spec](./FEATURES_SONG_REQUESTS.md): owner approved design; NO piecemeal Live launch. Complete intake + email + automatic validated publication + full Staging certification before one combined release |
| **Archivo mensual de Worship Semanal** | **Documented / Deferred / No runtime change** | [Monthly archive spec](../SIDE_LANES/WORSHIP_MONTHLY_ARCHIVE_SPEC.md): current month's weekends remain individually accessible until next month's first set becomes next-up; prior month grouped as month -> weekend -> service. Owner has NOT authorized implementation or Live release. |
| **Carátulas y previews en filas de canciones Worship Semanal** | **Documented / Deferred / No runtime change** | [Compact song-card media spec](../SIDE_LANES/WORSHIP_SONG_CARDS_ARTWORK_PREVIEWS_SPEC.md): reuse Después-style official song art, matching gradients and right-side previews WITHOUT making weekly rows bigger; generalized to any verified song. Owner explicitly requested documentation only, pending Solicitudes completion. |

## Execution checklist for any feature
- User's exact intention and acceptance criteria.
- Paths to be changed and intended cross-lane dependencies.
- Visual compatibility across phone/tablet/desktop and accessibility.
- Existing data and automatic release-cycle preservation.
- `SITE_STANDARDS.md` and `monitoring/WATCHDOG_POLICY.md` coverage disposition.
- Staging deployment/run URL, real-device result, explicit live approval, final status.

## Last completed
2026-10-15 — Created this dedicated sidebar and registered it in the workspace without changing runtime.

## Next resumption
When user says "switch to sidebar Additional Features", confirm current backlog is empty and proceed with their concrete feature request. MAIN remains the default active lane.

## 2026-10-16 — Active feature: Solicitudes de Canciones
User requested three coordinated modules: website request tab with Despues-style cover/palette/preview cards and "Solicitada" status; admin email or SMS alert; automatic verified song enrichment and stacking. Detailed scoped plan, strict no-untrusted-auto-publication safety, backend/DB/notification options and coverage in [FEATURES_SONG_REQUESTS.md](./FEATURES_SONG_REQUESTS.md). Live v201 is fully certified; do not disturb while configuring this feature. **No song specified for the initial manual Live pilot yet**, no preview invented, no runtime/backend code changed. Next: get the exact song (and preferred recording/version), prototype on isolated staging, certify, review then selectively publish to Live.

## 2026-10-16 — User changes release scope (authoritative)
Visual format approved; Staging v202 exact-SHA watchdog run 38940435585 SUCCESS. **No approval to promote any portion to Live.** A fully functional end-to-end request form, admin email, durable data, automatic safe song-card publication, security/failure paths, and platform-wide/real-device testing must all be finished before requesting one final Live authorization. Detailed plan and gates in [FEATURES_SONG_REQUESTS.md](./FEATURES_SONG_REQUESTS.md); next task is isolated request Worker/D1 architecture and API, not another Live promotion.


## 2026-10-17 verified feature transition and handoff
Solicitudes de Canciones remains ACTIVE on Staging only (v203 form/feed and approved Háblame de Cerca style); NOT a finished Live feature. Cloudflare/Gmail one-time notification test actually arrived at owner's verified ipcdjofficial@gmail.com from approved solicitudes@ipcdj.org. Probe cleaned/off; normal email, intake and publication still off. Backend green 39054643026, full Staging browser FAIL 39054643025 (9 failing cases). Automated song matching/correct artwork & preview, approval/publish workflow and real requester email path still outstanding. Owner reserves Cloudflare Free verified-recipient sending limits (~100 total requests in two years) for NEXT CHAT FIRST ANSWER. Preserve whole-feature-only Live authorization. Full archive under PROJECT_WORKSPACE/HANDOFF_ARCHIVE/IPCDJ_WORSHIP_HANDOFF_2026-10-17.md.
