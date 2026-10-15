# SIDEBAR — iPhone App / Installed Experience
Lane ID: IOS_APP | State: **FUTURE PROJECT — RESEARCH AND SCOPING** | Updated: 2026-10-15

## User's target
Provide IPCDJ Worship to church/team members on iPhone as a polished, reliable, true-feeling installed app, ideally **without App Store fees or a public App Store listing**. User recalled a potential "certificate" approach for team installation. **Do not assume a signing certificate alone permits free native app distribution to arbitrary iPhones.** Keep the decision open for evaluation.

## Current implemented foundation (verified repo)
- `manifest-v9.webmanifest`: `name=IPCDJ Worship`, `short_name=CDJ Worship`, `display=standalone`, start URL and scope `./`, icons, dark theme, app identity.
- `index.html`: Apple Web App metadata, startup/launch assets, status-bar and Home Screen support; critical launch animations and refresh controller.
- `sw.js`: service worker/PWA offline and freshness architecture.
- `apple-touch-icon.png`, `icon-192.png`, `icon-512.png`, `app-icon-safe.svg`: launch and install icons.
- `ios-launch/`: 13 size-specific startup-image PNGs.
- `notifications/test.html` and `notifications/ui.js`: browser notification capability test and Home Screen instructions. **Push remains disabled** until the NOTIFICATIONS sidebar authorizes a release.

## Feasible distribution choices — do not pre-decide
### A. No-fee Home Screen web app (PWA) — primary avenue
Team members add the live HTTPS site using Safari's Share > Add to Home Screen; the existing manifest requests standalone web app behavior, with a launcher icon and its own app-like window. No Apple distribution certificate, TestFlight or App Store membership is necessary for that web-app installation. On supported iOS versions (WebKit documents iOS/iPadOS 16.4+) installed Home Screen web apps can support standards Web Push and Badging when the feature is built, available and users opt in. Test current device capabilities rather than promising native-only APIs.

### B. Signed native iOS wrapper / internal distribution — separate, potentially paid
A real signed iOS binary, ad hoc provisioning, TestFlight or Apple Business distribution has Apple Developer Program / device-registration / signing / eligibility and cost requirements. The enterprise program is for eligible organizations and internal employees, not a generic free church-member install shortcut. Regional alternative app distribution has separate geographic/eligibility constraints. Creating or asking anyone to trust an arbitrary self-signed certificate or profile is **not** a safe or generally sufficient distribution strategy.

Official background (reviewed 2026-10-15):
- WebKit PWA + Home Screen Web Push: https://webkit.org/blog/13878/web-push-for-web-apps-on-ios-and-ipados/
- Apple Developer membership and testing: https://developer.apple.com/get-started/
- Apple Enterprise eligibility: https://developer.apple.com/programs/enterprise/
- Registered-device app builds: https://developer.apple.com/documentation/xcode/distributing-your-app-to-registered-devices
- Apple regional alternate distribution: https://developer.apple.com/distribute/

## Evaluation topics when user opens this sidebar
1. Confirm exact desired distinction: icon/standalone window and native-feeling UI versus true native iOS binary, native entitlements, file access or OS integrations.
2. Audit live PWA installation on current iPhones: Add to Home Screen steps, icons, startup/transition, update/reopen, app switching, offline handling, navigation/links, safe areas, install guidance.
3. Verify no unwanted reload/black screen, failed SW refresh or forced cache control.
4. Determine if any desired feature **requires native APIs** beyond the PWA. Most current worship-site flows appear web-app capable, but device testing is required.
5. Compare free PWA against paid or eligibility-limited native distribution before choosing a route.
6. Coordinate Web Push with the NOTIFICATIONS sidebar rather than enabling it here.
7. Add explicit installation/PWA watchdog cases and run real-device tests before any team-wide guidance or rollout.

## Cost/consent boundary
No payment, Apple Developer enrollment, issuance/import of certificates/profiles, trust-setting change, team enrollment or Live code change has been approved. User's preference is to avoid fees if possible.

## Last completed / next resumption
2026-10-15 — Inventoried existing PWA assets; validated core WebKit/Apple distribution constraints; created scoped sidebar with options but no implementation. On "switch to sidebar iPhone App", begin a device-specific PWA installation experience audit; research native distribution only where justified by the feature requirement.
