# IPCDJ Worship — Site Standards

These are protected implementation standards for all future changes to the IPCDJ Worship website.

## Core invariant

Every future change must preserve the existing visual identity, responsive behavior, current-song countdown, calibrated time source, progress bar, automatic phase transitions, automatic Monday rollover, upcoming-song rendering, introduced-song history, pull-to-refresh behavior, PWA behavior, and custom-domain operation unless a change is explicitly requested.

Adding or editing a song must not require manually redesigning or rebuilding the page state. Song lifecycle changes are date-driven from the song pipeline.

## Canonical domain

Primary public URL: https://worship.ipcdj.org/

The GitHub Pages URL remains a technical hosting fallback. Canonical, Open Graph, and other public-facing metadata should use the worship.ipcdj.org hostname.

## Maximum platform and size compatibility

Compatibility target:
- Current stable Safari, Chrome, Firefox, Edge, Samsung Internet, iOS/iPadOS webviews and Home Screen mode, Android browsers/PWAs, macOS, Windows, phones, tablets, laptops and desktops.
- Graceful fallbacks should also cover somewhat older WebKit/Blink versions where practical without compromising the modern design.

Required rules:
- Preserve classic viewport fallbacks before svh/dvh values.
- Provide explicit top/right/bottom/left fallbacks before CSS inset where fixed full-screen layers are used.
- Keep -webkit-backdrop-filter alongside backdrop-filter on glass surfaces that rely on blur.
- Avoid background-attachment:fixed on the main document because it can cause repaint/jank issues on iOS Safari.
- Layout children in flex/grid containers must tolerate narrow widths with min-width:0.
- At <=390px, the countdown becomes a 2x2 grid.
- At <=340px, reduce card/hero spacing and typography enough to remain usable without horizontal overflow.
- Landscape layouts with very short heights must preserve ambient coverage and safe-area padding.
- Coarse-pointer devices retain comfortable touch targets.
- Provide font-size fallbacks when clamp() is unavailable.
- Unsupported backdrop-filter browsers receive more opaque readable surfaces rather than broken glass.
- Experimental accessibility media queries such as prefers-reduced-transparency may enhance supported browsers, but core usability must not depend on them.
- Decorative animation remains transform/opacity based for compositor-friendly performance.
- Every compatibility pass must preserve native browser Find on Page, text selection, zoom, screen-reader semantics, countdown timing, song automation, refresh logic, and the live ambient background.

## Browser and device compatibility

Target current stable versions of Safari, Chrome, Firefox, Edge, Samsung Internet, iOS/iPadOS web views and Home Screen web apps, Android browsers/PWAs, macOS, Windows, iPhone, iPad, Android phones/tablets, and normal desktop/laptop viewport sizes.

Use progressive enhancement:
- Start with broadly supported HTML/CSS behavior.
- Advanced CSS must have a usable fallback when unsupported.
- Use both standard and WebKit-prefixed behavior where Safari still requires it.
- Keep viewport-fit=cover and safe-area insets for notched/rounded displays.
- Keep vh fallback before svh/dvh units.
- Preserve portrait and landscape behavior.
- Never rely on hover for required functionality.
- Keep touch targets usable on phones.
- Respect reduced motion, reduced transparency/data where supported, increased contrast, and forced-colors/high-contrast environments.

## Native browser functionality

All user-visible song names, artists, dates, statuses and page copy must remain normal selectable DOM text. Do not convert meaningful page text into canvas, background images, inaccessible SVG-only text, or closed Shadow DOM.

This preserves normal browser features such as:
- Find on Page / Ctrl+F / Command+F
- text selection and copy
- browser zoom
- Reader/accessibility tooling where applicable
- screen-reader text access
- built-in translation/search behavior

Do not use content-visibility, display:none, or other optimization techniques on active user-visible song content if they could make browser text search unreliable.

## Accessibility and input

- Keep semantic HTML structure.
- Preserve keyboard navigation and visible focus.
- Do not announce the live seconds counter every second to screen readers.
- Expose progress through ARIA progressbar values as well as visually.
- Do not encode important status only by color; retain text/borders/dots/pills.
- Do not globally disable text selection or browser zoom.

## PWA and icons

- Keep web manifest, service worker, Apple Home Screen metadata and browser favicons working independently.
- Preserve the supplied CDJ Worship favicon artwork.
- Mobile launcher icons must retain adequate safe-zone padding for platform masking.
- Installed-app changes must use versioned assets/cache updates when needed.

## Freshness-loop safety

The canonical-domain freshness checker must never hard-code a historical build ID.

Required rules:
- Read the current build ID from the live page's `meta[name="ipcdj-build"]`.
- Compare that value against the fetched deployed build.
- A cache-busted `fresh` navigation is a one-shot recovery path; clean its query flag and do not immediately trigger another redirect.
- Never create a self-reloading loop when the site's build marker changes.
- Freshness logic must be tested whenever the build marker is bumped.

## Always-latest canonical-domain loading

Opening https://worship.ipcdj.org/ must aggressively prefer the newest deployed website version.

Required behavior:
- Canonical-domain page loads run an immediate same-origin freshness probe with a unique cache-busting query.
- The probe compares the deployed build marker with the currently loaded build.
- If a newer deployed build exists, the page replaces itself with a cache-busted navigation automatically.
- Service-worker navigations use network-first behavior with cache bypass semantics.
- Browser/proxy caches must never be the sole authority for the canonical page.
- Offline fallback remains available only when the network cannot provide a working page.
- Do not destroy the last known-good offline copy before a successful newer response exists.
- GitHub Pages deployment propagation time cannot be eliminated; once the new build is actually available at the host, the freshness check should adopt it automatically.

## Refresh and caching

Pull-to-refresh must seek the newest deployed version quickly without destroying the last known-good page first.

Rules:
- Navigation is network-first.
- Never erase the only working offline/app-shell copy before a new response succeeds.
- Service worker updates must be versioned.
- Refresh UI remains centered, crisp and visible long enough to communicate activity.
- Network failure must fall back safely rather than produce a blank/black page.

## Current-card ambient edge integrity

The current-song card must not contain a fixed-color decorative glow that visually blocks or contradicts the live ambient background.

Rules:
- Any decorative glow inside the current-song card must be neutral/translucent.
- The right edge of the current-song card must allow the active ambient hue to read through the glass.
- Do not hard-code a blue, red, green, or other accent orb into the card surface itself.
- Semantic accents may remain on status/timeline/progress elements, but not as a large fixed background glow.

## Ambient-through-glass integration

The animated ambient background should remain visually present through the site's cards and nested panels.

Required behavior:
- Main cards are translucent glass, not opaque dark blocks.
- The current ambient hue should subtly pass through cards, platform buttons, song rows, timeline rows, countdown panels, recent/introduction rows, and other nested surfaces.
- Semantic tinting (red estreno, green introduced/progress, blue active states) remains, but at low enough opacity that the current ambient field is still visible behind it.
- Backdrop blur should be moderate rather than so strong that it erases the moving color field.
- Preserve sufficient contrast and legibility for all text.
- Reduced-transparency and unsupported-backdrop-filter fallbacks may remain more opaque for accessibility and compatibility.
- Future surface styling must not isolate cards visually from the animated background unless explicitly requested.

## Faster initial ambient appearance

On a fresh page open, the first ambient color should begin appearing almost immediately while preserving the established phase speed and motion.

Rules:
- Keep the same 28-second phase cadence and the same blob motion/breathing behavior.
- Do not accelerate the ongoing color cycle.
- Only shorten the initial dead-black delay before the first fade-in begins.
- Preserve the same fade-in duration so the appearance still feels soft and premium.

## Professional same-hue blob field

The ambient background uses a fixed near-black base plus multiple soft concentrations of one current accent color.

Required behavior:
- Black never moves and remains the permanent base.
- The active accent is represented by several small-to-medium soft radial concentrations ("orbs"/blobs) in different locations.
- Every visible concentration in a phase uses the exact same hue family.
- Blobs move independently and slowly, with different paths, scales, and intensity breathing.
- No second accent hue is visible at the same time.
- The current hue dwells long enough to feel ambient and alive.
- After the dwell, the entire colored field softly fades fully to black.
- Only while fully black may the field hue change to the next palette color.
- Then the next color fades in and repeats.
- Avoid a single giant whole-screen orb.
- Avoid animating gradient stops or crossfading two hues.
- Use compositor-friendly transform and opacity animation.
- Preserve subtle dithering to minimize visible gradient banding.
- Reduced-motion/data users receive a static deep-blue fallback.

## Ambient performance safety

The ambient background must use only one active colored composited orb layer at a time.

Rules:
- Do not render five simultaneous oversized animated gradient layers.
- Do not keep hidden off-screen/transparent color layers continuously animating.
- Color sequencing is controlled by one reusable orb whose RGB value changes only while its opacity is zero.
- The orb uses transform animation plus opacity only.
- This avoids excessive GPU memory/compositing pressure on Safari, mobile browsers, and lower-power devices.
- If a decorative background change causes flicker, page tearing, black flashes, scroll jank, or compositor instability, performance safety takes priority over visual complexity.

## Ambient orb dwell behavior

Each color phase must feel like a deliberate ambient scene, not a quick flash.

Required behavior:
- Each color gets a long dwell window before transitioning away.
- While active, the color moves around the viewport as one large smooth orb.
- The orb subtly breathes between several intensity levels while remaining the only visible accent hue.
- Movement and intensity changes happen continuously during the dwell.
- The active orb fades fully to the black base before the next color begins.
- Preserve the five-color sequence: deep blue, accent blue, green, red, pure white.
- Use one large radial orb per phase with broad feathered falloff rather than multiple differently colored blobs.
- Keep the orb large enough to influence the whole viewport while still making its movement perceptible.
- Preserve subtle dithering to reduce banding.
- Reduced-motion and reduced-data users should receive a static dark-blue fallback.

## Pure-white phase and black fade quality

The white ambient phase uses true neutral white (255,255,255), not blue-white or gray-white.

Fade rules:
- Entry from black and exit back to black must use soft ease-in-out opacity transitions.
- The fade should feel gradual and subtle rather than abrupt.
- The active color still fully disappears before the next accent begins.
- White may be visually stronger than the other accents, but must remain a gradient over the constant black base rather than a flat white screen.
- Preserve dithering and large radial falloffs to avoid banding.

## Full-page single-color ambient phase

At any moment, the animated background may display only one accent color family over the constant near-black base.

Required behavior:
- The active color must read across the whole viewport, not as a small isolated blob.
- All gradient components within an active phase must use the same hue family at different opacities.
- No second accent hue may visibly overlap the current one.
- Every color phase must fade fully to black before the next hue begins.
- Black remains the permanent base and the transition separator.
- Use full-screen gradients plus same-hue radial depth, never cross-hue blending.
- Keep visible motion obvious but smooth through transform-only movement.
- Use opacity for phase entry/exit; do not animate gradient color stops.
- Preserve subtle dithering to suppress visible gradient banding.
- Prefer composited transform/opacity animation for performance and smooth frame pacing.

## Sequential ambient color cycle

The background color system must be sequential, not blended between accent families.

Required sequence behavior:
- Start with one active accent family.
- Let that color visibly move while it is active.
- Fade that color completely to the constant near-black base.
- Hold a brief full-black interval.
- Only then introduce the next accent family.
- Repeat this sequence continuously through deep blue, accent blue, green, red, and soft white.
- Never overlap two colored phases strongly enough that one visually mixes into the next.
- Black is the constant base state between every color phase.

Gradient quality rules:
- Avoid visible gradient banding / contour lines as much as browsers and displays allow.
- Do not animate gradient stops, gradient colors, filter brightness, or saturation between colors.
- Each color layer keeps a fixed gradient and transitions only through opacity.
- Use broad soft radial falloffs, blur, and a subtle dither/noise layer to reduce 8-bit banding.
- Keep dither subtle enough that it reads as smoothness, not visible grain.
- Maintain oversized transform layers so movement never exposes an edge.
- Movement should be clearly noticeable while remaining smooth and premium.
- Respect reduced-motion and reduced-data preferences.

## Expanded accent background palette

The animated background may cycle through the website's established accent colors while remaining dark-first and visually cohesive.

Allowed accent family:
- IPCDJ accent blue (#89a9ff family)
- progress green (#35b75c / #65dc83 family)
- estreno red (#ff5a5a family)
- soft white glow
- deep blue and near-black remain the dominant base

Rules:
- Accent colors must appear as restrained radial glows, never as full-page flat washes.
- Deep blue and black must remain visually dominant so cards, text and hierarchy stay readable.
- White is a soft luminous accent only, not a bright background state.
- Red and green remain subtle enough not to override their semantic meanings inside the UI.
- Multiple accent layers may overlap organically, but the result must remain premium, smooth and non-distracting.
- Movement should be clearly noticeable, with larger transform travel and independent timing between layers.
- Preserve transform-driven motion and avoid layout-triggering animation.
- Reduced-motion mode must disable all drift and color cycling.

## Background color cycle

The animated background should loop through the site's established visual language rather than remain a single static hue.

Required color sequence:
- deep IPCDJ blue
- near-black / black transition
- the site's existing accent blue (#89a9ff family)
- return smoothly into deep blue

Rules:
- The accent color must emerge subtly through the existing radial-gradient motion rather than becoming a bright flat wash.
- The black portion should remain dark enough to preserve contrast and the premium glass-card aesthetic.
- Color cycling and positional drift should run independently enough to avoid an obvious repetitive loop.
- Preserve smoothness, readability and performance on mobile and desktop.
- Respect prefers-reduced-motion by disabling both drift and color cycling.
- Future palette changes should derive this background accent from the website's established accent-color family rather than introducing unrelated colors.

## Animated background motion

The dark blue background gradient is intentionally animated and should remain visibly alive without distracting from content.

Required behavior:
- Motion must be smooth, slow-to-moderate, and continuous.
- Movement should be noticeable on both desktop and mobile without looking like a looping gimmick.
- Use transform-based animation for performance; avoid layout-triggering animation.
- Preserve the existing blue/black palette and glass-card readability.
- Keep landscape coverage oversized enough to avoid exposing edges during movement.
- Respect prefers-reduced-motion by disabling the background animation.
- Future visual changes must not accidentally remove or freeze the animated background.

## Phase-aware progress color system

The progress bar is time-driven and phase-aware. It must continuously inherit its visual state from each song's own pipeline dates rather than hard-coded calendar dates.

Required color semantics:
- Early/active learning uses the existing green progress language.
- Learning matures toward a brighter green.
- Transition into final preparation moves smoothly toward IPCDJ blue.
- Final preparation remains in the blue family.
- The last stretch before estreno transitions from blue toward the established estreno red.
- Estreno resolves to the established red state.
- Color changes must be gradual, repeatable for every future song, and derived from activeFrom, learningStart/end, finalStart/end and releaseAt.
- Important phase meaning must still be conveyed by text/ARIA and not by color alone.
- Reduced-motion users must not receive unnecessary animated transitions.
- Future song additions must inherit this behavior automatically without per-song styling.

## Countdown timing integrity

The countdown is an absolute-time system, not a decrementing counter.

Required rules:
- Never implement the countdown by subtracting one second from a stored value.
- Every displayed value must be recalculated from the absolute estreno timestamp minus calibrated current time.
- Delayed JavaScript callbacks, background-tab throttling, device sleep, refreshes, or dropped frames must never accumulate countdown drift.
- Preserve a short-lived calibrated time seed through same-tab refresh/navigation so the timer resumes immediately instead of visually restarting from an older value.
- Recalibrate against the live server clock in the background without blocking countdown rendering.
- Small sub-second backward corrections from low-precision HTTP Date headers must not make the countdown visibly pause or gain time.
- Returning from the background/pageshow must immediately recalculate from absolute time.

## Song automation

For each scheduled song, keep one pipeline record containing the title, artist, learning period, final-preparation period, estreno time and rollover time.

The website must automatically:
1. Render the correct current song.
2. Run the calibrated countdown.
3. Advance the progress bar with real elapsed time.
4. Highlight the correct phase.
5. Move the completed song into Introducciones recientes with its introduction date.
6. Promote the next song without manual intervention.
7. Preserve chronological introduced-song ordering.
8. Continue expanding vertically as additional songs accumulate.

## Change procedure

Before substantial changes:
1. Fetch the current file/version.
2. Create a backup branch when practical.
3. Make the smallest compatible change.
4. Do not overwrite unrelated current functionality.
5. Verify countdown/pipeline/refresh/PWA/mobile behavior still exists after the change.
6. Bump service-worker/app-shell cache only when deployment freshness requires it.

The visual aesthetic is a protected system: dark blue/black animated background, blue identity accents, the documented red → orange → amber → green preparation progression, gold estreno states, glass cards, responsive typography and existing spacing/radius hierarchy.


## Song preparation status palette

The preparation-stage color system communicates movement from early preparation toward readiness while preserving text labels and other non-color cues.

Required progression:
- Earliest/upcoming and early learning begin in a restrained warm red.
- Learning matures through orange.
- Transition toward final preparation uses amber/gold.
- Final preparation resolves into green to communicate readiness.
- Estreno is a separate celebratory milestone and uses gold rather than red.
- The current-phase timeline tab and current-song status pill inherit the live stage color; they must not default to a distracting fixed blue.
- Countdown surfaces stay mostly neutral so they do not compete with the stage signal.
- Future release-date badges use the estreno gold family, not red.
- Brand blue remains available for IPCDJ branding, links/focus, and non-stage identity, but not as the default current preparation-stage indicator.
- Status meaning must never rely on color alone: phase names, labels, timeline position, and text remain present.
- Maintain strong text/background contrast and subdued translucent fills suitable for the site's dark glass interface.
- The animated ambient gradient background is independent and must remain untouched by stage-palette changes.


## Album-art adaptive active-song card

The current-song preparation card may derive a restrained atmospheric palette from the active song's official album/single artwork while keeping semantic stage colors independent.

Required behavior:
- The animated page-wide ambient gradient is untouched and remains independent.
- Album-art color only affects the current-song card atmosphere and subtle inactive timeline surfaces.
- Red → orange → amber → green preparation semantics remain authoritative for status, active phase and progress. Estreno remains gold.
- When a song becomes current, resolve its artwork from the music catalog, extract a small palette client-side, cache it locally, and apply it automatically.
- Prefer ID-based catalog lookup when a known collection ID is available; otherwise use a narrow title + artist search and score matches.
- Downsample artwork before pixel analysis for performance. Ignore extreme near-black/near-white pixels and select visually distinct swatches.
- Every known pipeline song has a curated fallback palette so network, catalog or CORS failure never breaks the card.
- Future songs inherit the automatic artwork lookup without needing custom CSS; an optional artworkQuery/itunesCollectionId can improve ambiguous matching.
- Never let album colors reduce text legibility or replace semantic color meaning.
- The current-song card may display the official artwork only in the separately requested heavily blurred atmospheric treatment; never show a crisp distracting cover behind text.


## Blurred official-cover active-song background

The current-song card uses the active song's official album/single artwork as a heavily blurred atmospheric background.

Required behavior:
- Only the current-song card receives the artwork; the page-wide moving ambient gradient is untouched.
- Resolve official artwork through a stable catalog ID whenever one is known; otherwise use title/artist matching.
- Request a high-resolution artwork variant when the catalog supports it.
- The artwork layer is cover-sized, strongly blurred, slightly scaled, and saturated enough to preserve the cover's identity without exposing distracting text/details.
- A dark scrim sits above the artwork so all card text remains readable.
- A restrained extracted-palette overlay may reinforce the cover colors.
- Semantic preparation colors remain independent: red → orange → amber → green, with gold for Estreno.
- Cached palette data must never prevent the actual artwork layer from loading.
- Catalog/artwork/CORS failures fall back gracefully to the curated palette and must never affect countdown, rollover, preparation phases, or card readability.
- When the active song changes, the card automatically resolves and applies that new song's official cover.


## Selective official-art detail fade

The current-song card may allow small portions of the official album artwork to become softly recognizable in low-content regions while the main card remains a blurred atmospheric treatment.

Required behavior:
- Keep the full-card artwork layer heavily blurred as the primary atmosphere.
- Add only a low-opacity, lightly blurred detail layer from the same official cover.
- Reveal that detail through feathered masks concentrated near card edges/corners where it is least likely to compete with text.
- On narrow/mobile layouts, reduce the detail opacity and tighten the masks because text occupies more of the card width.
- Never place crisp artwork directly behind primary title, artist, countdown, progress, or timeline text.
- Semantic stage colors remain independent of artwork.
- The page-wide moving ambient background remains untouched.
- If reduced-transparency is requested, substantially reduce the detail layer.


## Dense but non-distracting album-art presence

The active-song card should make meaningful use of nearly every area that is not occupied by text, without allowing album art to compete with content.

Required behavior:
- Preserve the heavily blurred full-card artwork layer as the base atmosphere.
- Use a second lightly blurred detail layer with multiple feathered reveal zones around corners, side gutters and low-content bands.
- Favor empty margins, outer edges, gaps between content groups and unused portions of nested panels.
- Do not deliberately reveal high-detail imagery directly beneath the song title, artist, countdown labels/numbers, progress labels or timeline text.
- Nested panels inside the current-song card should remain translucent enough for the artwork atmosphere to pass through, with only mild local blur for readability.
- Desktop can show more recognizable cover detail than mobile; narrow layouts must use lower opacity and tighter reveal zones.
- The result should be clearly noticeable at a glance but never become a crisp full-cover background.
- Semantic stage colors and the page-wide animated ambient background remain independent and unchanged.


## Centered active-song cover framing

The official artwork used by the current-song card must remain centered within that card on every viewport size.

Required behavior:
- Both the heavily blurred atmosphere layer and the lightly blurred detail layer use the same centered 50% / 50% crop by default.
- Mobile and narrow-screen rules must not shift the artwork horizontally or vertically.
- All strategic reveal masks operate over that centered source image; masks may change by viewport, but the artwork itself remains centered.
- Future songs automatically inherit centered cover framing.
- Shared CSS variables control cover positioning so a deliberate per-song focal-point override can be added later without changing the default.
- The page-wide moving ambient background, semantic stage palette, countdown, progress system, and song automation remain unchanged.


## Unmistakable centered album-cover presence

The active-song card must visibly read as being built from the official centered album artwork, not merely as a generic color tint.

Required behavior:
- The official cover remains centered at 50% / 50% and is the single source image for all card-art layers.
- Preserve the heavily blurred full-card atmosphere layer.
- Preserve strategic lightly blurred detail reveals in low-content regions.
- Add a dedicated perimeter-detail layer that reveals noticeably more recognizable artwork toward all four edges and corners while fading inward before it competes with primary content.
- The outer perimeter should make the cover unmistakable at a glance, while the central content region stays calmer and darker.
- Mobile keeps the same centered crop and a slightly softer perimeter reveal.
- Text, countdown, progress, timeline, semantic stage colors, and the page-wide animated ambient background remain independent and readable.


## Person-aware album-art emphasis

The active-song card keeps the established centered official-cover treatment as its permanent base. When a human face can be detected in the artwork, the system may add a separate detail-only emphasis layer that gently biases that person toward the nearest low-conflict outer edge.

Required behavior:
- Never replace, crop-shift, or disturb the centered 50% / 50% base artwork layers.
- Person emphasis is an additional progressive-enhancement layer only.
- Detection runs locally in the browser through the native FaceDetector API when available; artwork is not uploaded to a third-party recognition service.
- If detection is unavailable, fails, or finds no face, the established v40 centered/perimeter artwork treatment remains exactly intact.
- The largest detected face is treated as the primary visual subject; the extra detail layer may shift by a tightly capped amount toward the nearest outer edge.
- The detail mask follows the shifted subject and stays feathered, lightly blurred, and subordinate to text.
- Subject opacity is capped so the enhancement remains noticeable but non-distracting.
- Detection results may be cached locally per song to avoid repeated work.
- A future song may optionally define subjectFocus:{x,y,confidence} as a manual override if native detection is unavailable or a cover needs art-direction correction.
- Semantic stage colors, countdown/progress logic, the centered base cover, perimeter reveal, and page-wide animated ambient background remain independent and unchanged.


## Current-cover person art-direction trial

Before enabling automatic person detection globally, test and visually approve the treatment on the currently active song.

Current trial behavior:
- Preserve the centered official-cover atmosphere, selective empty-space reveals, and strong perimeter artwork exactly as the established base treatment.
- Add one separate near-crisp subject-detail copy only for the current Dios De Milagros cover.
- Shift that extra copy slightly toward the right edge and reveal it through a broad feathered right-edge mask so a person from the cover can read almost fully without covering primary text.
- Keep the central/title/countdown/progress/timeline content treatment unchanged.
- Do not enable generic automatic face/person detection until the visual result is approved.


## Current-cover top-edge person isolation trial

For visual approval on the current Dios De Milagros cover, preserve the established centered-cover, empty-space reveal, and perimeter artwork treatment exactly as the base. The temporary subject layer should isolate only a person-shaped region of the duplicate artwork and place that person near the empty top-right edge of the current-song card. No broad second-cover strip or obvious duplicated album background should be visible from the subject layer. The person may be near-crisp and nearly fully opaque, with feathered head/torso masks, while all normal content zones remain untouched. Do not generalize this behavior to future songs until the result is visually approved.


## Current-cover isolated top-band person trial v44

For the current Dios De Milagros approval trial, the established centered official-cover atmosphere, strategic empty-space reveals, and perimeter-detail treatment remain the base and must not be altered. The extra duplicate artwork layer is confined to the empty top band and masked tightly around the intended person so no obvious second album strip or duplicated non-person artwork should read as a separate layer. The person treatment is near-crisp and nearly fully opaque at the top-right edge. This remains a current-song-only approval trial; do not generalize it to future songs until visually approved.


## Current-cover isolated-person trial v45

For the current Dios De Milagros approval trial, preserve the centered official-cover atmosphere, strategic empty-space reveals, and perimeter-detail system as the permanent base. The additional subject layer is a tightly cropped top-right window intended to show only the selected person from the same cover, with near-crisp detail and strong opacity, while suppressing surrounding duplicate artwork. This is still a current-song-only art-direction trial and must not be generalized to future songs until visually approved.


## Automatic person-aware album-cover treatment v46

The base treatment is permanent for every current song, whether people are present or not: use the official album cover centered at 50% / 50%, preserve the heavily blurred full-card atmosphere, and noticeably reveal the centered cover through low-content areas and the perimeter without compromising text readability.

When a cover contains a detectable person, add the approved top-right person treatment on top of that base. The person layer must be isolated from the same cover, near-crisp, strongly visible, and smoothly feathered into the existing cover atmosphere with no rectangular crop line, hard seam, or visible layer boundary on desktop, mobile, tablet, PWA, or other supported layouts. Native FaceDetector detection is used only when available in a secure context; detection failure or unsupported browsers must simply fall back to the universal centered-cover base without changing layout or functionality. Detection results may be cached locally. Manual coverSubjectFocus / subjectFocus overrides remain supported for art-direction correction, and the approved Dios De Milagros framing remains the reference implementation.


## Person visibility and seamless blending v47

The approved person treatment must keep the person as visible and prominent as the approved v45 framing. Do not solve seams by enlarging, relocating, or washing out the subject layer. Preserve the approved subject crop/placement and remove visible separation only through soft alpha feathering around the isolated person. No hard clip-path, rectangular crop edge, or abrupt layer boundary may be visible on desktop, mobile, tablet, PWA, or narrow layouts. Mobile may use its approved crop dimensions, but the person must remain clearly visible and dissolve smoothly into the centered album-cover atmosphere.


## Person layer stacking v48

When a person emphasis layer is active, that isolated person must visually sit on top of the current song's centered blurred/detail/perimeter album-art layers while remaining underneath all readable UI content. The subject must therefore read as a foreground extension of the same album cover rather than as imagery buried behind the base treatment. Preserve the approved v47 placement, visibility, and seam feathering; only the stacking relationship changes. Text, status, countdown, progress, and timeline content must remain above the person layer.


## Foreground-person isolation v49

Keep the isolated person above the centered album-art background stack, but do not let the foreground subject layer reintroduce a bright or obvious duplicate of the right side of the cover. Preserve the approved person placement and visibility while tightening the alpha mask around the head, torso, and any necessary limb extension. The duplicate source image outside the person must fall away into transparency so the universal centered-cover treatment remains visually dominant. The person should read as a foreground extension of the same image, not as a brighter rectangular or right-side duplicate.


## Foreground person treatment v50

When a cover person is emphasized, the centered album artwork remains the permanent base. The isolated person must render above every album-art background layer (blurred atmosphere, selective detail reveal, perimeter detail, and palette scrim) while all readable UI remains above the person. Preserve the approved person placement and strong visibility; use broad alpha feathering around the subject layer itself so it merges smoothly into the base cover without a rectangular seam or an over-bright duplicated right-side patch. Desktop and mobile must maintain the same foreground relationship.


## Seamless person composite v51

The isolated person overlay must use the same visual principle as a professional feathered layer mask: the foreground subject remains readable, but the edge of its source rectangle must never be visible. The left transition into the centered base artwork uses one continuous, wide alpha-gradient mask rather than several additive masks. This prevents a hard vertical seam and avoids browser differences in multi-mask compositing. Desktop and mobile both keep a long feather zone, with mobile slightly wider. The base centered album-cover atmosphere remains unchanged underneath.


## Eraser-style subject seam v52

The isolated person overlay uses a deliberately low-opacity feather across most of its blend boundary, mimicking a soft eraser pass. The duplicate artwork must not become fully opaque until the far-right side of the subject region. Explicit alpha mask mode is used for cross-browser consistency. The goal is to erase the visible vertical cut line while preserving the person as a clear foreground subject.


## Person visibility balance v53

After the eraser-style seam treatment, the isolated person should remain clearly readable. Preserve the long transparent-to-opaque blend that removes the cut line, but let opacity recover somewhat earlier through the middle and right side of the subject region. Slightly harmonize brightness, saturation, and contrast so the person has presence without looking pasted on. Mobile may recover a little earlier than desktop while retaining the same seamless edge principle.


## All-edge person feather and responsive placement v54

The isolated person overlay must never expose a rectangular source edge. Use one continuous top-right radial alpha feather so every exposed boundary of the snippet, especially the left and bottom edges, dissolves smoothly into the centered album-cover background. Preserve strong subject visibility near the top-right while fading progressively toward the lower-left. On narrow/mobile layouts, tune the subject crop independently so the person remains clearly visible rather than drifting too far left or disappearing into the background; keep the layer slightly wider, slightly farther right, and less tightly zoomed as needed. The rest of the current-song artwork treatment remains unchanged.


## Soft edge-intersection subject blend v55

When an isolated person crop sits above the official album-art background, feather the crop like a professional layer mask rather than fading the whole subject. Preserve a fully visible interior and soften only the crop boundaries. Implement this with separate horizontal and vertical alpha gradients intersected together so the left/right and top/bottom edges each receive independent feathering. The bottom and left edges may use a broader transition; top/right edges may use a shorter transition when they sit near the card boundary. Keep both the standard `mask-composite: intersect` path and the WebKit `-webkit-mask-composite: source-in` path for Safari/iOS compatibility. Mobile may use its own crop/position values so the person stays visible without changing the approved desktop composition.


## Mobile subject focal placement v56

Preserve the approved desktop/tablet landscape person composition. On narrow mobile layouts, tune only the subject crop and horizontal focal position so the person remains close to the top-right corner without being cut off or drifting too far left. Keep the v55 all-edge feathering unchanged. Prefer small breakpoint-specific adjustments to `right`, `width`, `background-size`, and `background-position` rather than changing the shared desktop composition.


## Mobile subject direction correction v57

For oversized subject background crops, remember that increasing percentage-based `background-position-x` can move visible artwork left because the image is larger than its positioning area. On mobile, when the person appears too far left, reduce the horizontal background-position percentage and, if necessary, nudge the overlay box slightly right. Preserve the v55 feather masks and approved desktop/tablet composition.


## Mobile subject blend refinement v58

Keep the approved v57 mobile subject position and crop. On narrow mobile layouts only, use a slightly broader left and bottom feather so the subject integrates more naturally with the album-art background without losing the person. Do not change desktop or tablet-landscape positioning, and preserve the intersected horizontal/vertical mask method from v55.


## Mobile lower-body continuity v59

On narrow mobile layouts, avoid making an isolated worship-subject crop read like a torso cut off at the bottom. Preserve the approved horizontal placement and side feathering, reveal slightly more lower body by extending the subject region vertically, and move the bottom feather lower so the visible body transitions naturally into the album-art background. The fade should remain gradual and edge-focused rather than reducing the subject's overall presence.


## Mobile bottom-edge feather v60

When the lower-body crop is already positioned correctly, do not move or resize the subject. Refine only the bottom mask boundary so the exact line where the body ends dissolves more gradually into the album-art background. Preserve side feathering, subject visibility, and all desktop/tablet placement.


## Refresh reliability v61

The installed web app's pull-to-refresh must never remain indefinitely in a loading state or keep serving a stale document after a deployment. Explicit refresh requests and deployed-build probes bypass the service-worker static cache and go network-only. The pull-refresh fetch uses no-store semantics plus a finite timeout, then navigates to the cache-busted URL. Keep a short minimum spinner only for visual continuity; do not let the animation delay a successful update unnecessarily. Normal offline fallback remains intact for ordinary navigation.


## Global lower-body feather continuity v62

Across desktop, tablet, and mobile, an isolated worship-subject crop must never read as a torso abruptly cut off at the lower edge. Preserve approved subject placement and side feathering, but extend the lower vertical alpha transition farther upward and make the final edge more gradual so the body dissolves naturally into the album-art background. This refinement applies to all responsive breakpoints, with slightly stronger lower-edge feathering on narrow mobile layouts.


## Mobile countdown-area subject swell v63

On mobile, when the lower portion of the isolated person remains visible beneath or behind the countdown box, avoid a hard torso-ending line. Keep the approved placement and side feathering, but begin the bottom alpha fade earlier and distribute it across a wider vertical range so the lower body dissolves like a soft swell into the background beneath the countdown area. Preserve the person's upper-body presence and do not alter desktop/tablet composition.


## Mobile deep lower-body swell v64

On narrow mobile layouts, when the lower portion of the subject remains perceptible beneath the countdown card, the fade must begin substantially earlier and remain continuous through the lower half of the subject crop. Preserve the approved subject placement and upper-body clarity, but reduce lower-body alpha progressively from roughly the midpoint downward so no distinct torso or body-ending contour remains. The intended result is a soft atmospheric swell into the album-art background and countdown region, not a visible cropped figure edge.


## Mobile deeper lower-body swell v65

On narrow mobile layouts, preserve the approved subject placement, crop, side feathering, and upper-body clarity while making the lower-body dissolve materially stronger than v64. Begin the bottom alpha decay shortly after the upper half of the crop, then use a long multi-stop fade so the torso loses any distinguishable ending contour before it reaches the countdown region. The lower quarter should read as atmosphere rather than as a cropped body edge. Do not alter desktop/tablet composition or the approved mobile focal position.


## Mobile erased lower-body swell v66

On narrow mobile layouts, preserve the approved subject box and focal placement exactly: right:-2%, width:40%, height:34%, background-size:360% auto, and background-position:84% 64%. Preserve the established horizontal side feather. For the lower-body boundary, keep full vertical mask visibility only through roughly the upper third, then begin a materially stronger, long alpha decay so the torso/body-ending contour is already faint by the middle-lower region and becomes atmospheric well before the bottom edge. The lower quarter should be nearly indistinguishable from the centered album-art background, especially behind and beneath the Cuenta regresiva region. Do not weaken the upper-body/head presence and do not alter desktop/tablet composition.


## Global approved soft-erased subject composite v67

The soft-erased lower-body treatment approved on mobile in v66 is now the permanent visual standard for isolated subject overlays on every viewport. Desktop, tablet, mobile, and future songs must preserve their approved responsive subject positioning while using the same compositing principle: a clear upper subject, professionally feathered side boundaries, and a long lower-body alpha decay beginning around the upper-middle portion of the crop. The body must lose any distinguishable crop-ending contour well before the lower boundary and dissolve into the centered album-art atmosphere like repeated passes of a large soft Photoshop eraser. The lower quarter should read primarily as atmosphere, never as a rectangular or torso-ending cutout. Preserve the intersected horizontal/vertical mask architecture, Safari/WebKit compatibility, centered base cover, semantic stage colors, text readability, countdown/progress logic, and refresh/PWA system. Responsive focal placement remains independently tunable and must not be changed merely to achieve the fade.


## Automatic high-resolution cover and subject system v68

The approved v67 subject-compositing aesthetic is now a permanent automatic system for every song that is actively in the preparation pipeline, including overlapping preparation cycles where more than one song is active at the same time.

Required behavior:
- The current-preparation area is a multi-card system. Every song whose activeFrom <= current time < rolloverAt receives its own complete current card, countdown, progress state, timeline, official-cover atmosphere, subject overlay, and responsive treatment.
- Overlapping preparation windows are supported intentionally; do not collapse multiple active songs into one card.
- Explicit per-song artworkUrl remains the highest-authority source when an exact cover has been curated.
- Otherwise, artwork resolution first queries COV / covers.musichoarders.xyz using the Tidal, Spotify, and Apple Music source filters and prefers the highest-resolution candidate available.
- Apple/iTunes lookup remains a non-breaking fallback when COV is unavailable, blocked by CORS, rate-limited, or has no reliable result.
- Cache resolved cover URLs locally to avoid unnecessary repeated provider lookups.
- The centered official cover remains the base atmosphere and source for palette extraction.
- Person detection runs independently for every active song cover. When native FaceDetector is supported, select the strongest primary face using size plus a small edge/upper-frame preference, then mathematically translate that source focal point into the established top-right subject box.
- Automatic focus must be responsive. Desktop/tablet and mobile receive independently calculated background-position values while preserving the approved subject box family and the v67 soft-erased lower-body aesthetic.
- The mobile subject box remains near the approved top-right safe area; responsive focus variables may move the image inside the box but must not reintroduce crop seams.
- The approved intersected horizontal/vertical alpha masks and long lower-body dissolve remain unchanged as the global visual standard.
- Manual coverSubjectFocus / subjectFocus overrides remain supported and take precedence over automatic detection for art-direction corrections.
- Dios De Milagros remains the approved reference implementation and retains its locked desktop/mobile focus values.
- If browser-native person detection is unavailable, the centered cover system still renders normally; curated per-song subject metadata remains the deterministic fallback for covers requiring a person treatment on unsupported browsers.
- Cover lookup, subject detection, or palette failures must never break countdowns, timeline logic, song rollover, semantic stage colors, offline/PWA behavior, or readability.
- Future pipeline additions should provide coverSearchArtist / coverSearchAlbum when the release metadata differs from the displayed song title/artist, and may provide coverMinResolution when a higher COV threshold is appropriate.


## Portable automatic face detection v69

Automatic person-aware cover composition must not depend exclusively on the browser-native Shape Detection FaceDetector API.

Required behavior:
- Use native FaceDetector first when available.
- When native FaceDetector is unavailable or fails, lazily load MediaPipe Tasks Vision FaceDetector and the BlazeFace short-range model, then run still-image face detection locally in the browser.
- The portable fallback is specifically required so Safari/iOS/PWA users can receive automatic person-aware cover placement rather than silently losing the subject overlay.
- MediaPipe should use the CPU delegate for the still-image cover task for broad mobile/Safari stability.
- The face image itself is processed locally; do not upload album artwork to a face-recognition service.
- Normalize native and MediaPipe bounding-box shapes into one internal representation before subject scoring and focal-position calculation.
- Cache normalized subject coordinates per song/artwork so the detector/model does not need to rerun on every page load.
- Keep manual subject-focus overrides as the highest-priority art-direction correction.
- Lock each current card while artwork is being resolved so the one-second countdown render loop cannot repeatedly restart a slow COV/catalog request.


## Load performance and one-way reveal stability v70

The website must prioritize fast first paint, low mobile CPU/layout churn, and deterministic element visibility.

Required behavior:
- Scroll reveal animations are one-way only. A section may transition from hidden to visible once, but scrolling it out of the viewport must never remove visibility or trigger a second fade cycle.
- After a reveal completes, stop observing that element.
- Elements already in or immediately adjacent to the initial viewport should be made visible immediately rather than waiting for an asynchronous observer callback.
- Include a short defensive reveal fallback so no card, section, or footer can remain permanently hidden because of an IntersectionObserver/browser scrolling bug.
- The live countdown timer aligns to absolute one-second boundaries; do not update the DOM multiple times per second when the displayed values only change once per second.
- Dynamic upcoming and introduced-song sections must use render signatures and only rebuild their innerHTML when their actual contents change.
- COV and Apple/iTunes artwork lookups may begin in parallel. COV remains the preferred high-resolution source, but a slow COV response must not block first usable cover rendering; Apple/iTunes may supply the current load while COV continues and populates its cache for future loads.
- Preconnect only to the small set of external origins required by current-cover resolution and portable face detection.
- Below-fold list containers may use content-visibility when supported, but the active current-song card must remain eagerly rendered.
- Performance changes must not weaken the refresh/PWA freshness system, countdown accuracy, stage colors, automatic subject detection, or approved album-art aesthetic.


## Cross-device responsive compatibility v71

The approved IPCDJ Worship aesthetic must remain structurally consistent across arbitrary viewport widths, heights, orientations, browser zoom levels, safe-area devices, installed PWAs, split-screen layouts, tablets, laptops, and large desktop displays.

Required behavior:
- Use intrinsic sizing and min-width:0 / minmax(0,1fr) where needed so flex/grid children cannot force horizontal overflow.
- The primary shell remains centered and visually capped near the established 860px design width while never exceeding the available viewport.
- Preserve safe-area padding on notched and rounded-screen devices.
- Long song titles, artist names, status text, dates, metadata, and accessibility text must wrap instead of clipping or widening the page.
- Preserve the established three-platform desktop/tablet layout and single-column phone layout.
- Countdown cards use four columns where space supports them and two columns on narrower phones; short landscape layouts may retain four compact columns when vertical space is limited.
- Tiny/narrow viewports may reduce padding and typography modestly, but must not alter the approved hierarchy, dark-glass aesthetic, semantic colors, album-art system, or subject-mask character.
- The isolated subject system must recalculate its focal placement after resize, orientation change, split-screen changes, and visual viewport changes so automatic face framing does not retain stale coordinates from a previous card size.
- Manual subject overrides remain deterministic across responsive changes.
- Browsers without CSS mask support must hide the isolated subject enhancement rather than display a rectangular duplicate-art crop; the centered blurred/detail/perimeter cover treatment remains the graceful fallback.
- Responsive compatibility work must preserve one-way reveal behavior, refresh/PWA freshness, countdown accuracy, COV artwork resolution, MediaPipe/native detection, semantic progress colors, and all approved v67-v70 visual treatments.


## Non-blocking refresh and instant navigation v72

The installed mobile web app and normal browser must never remain indefinitely in a loading/navigation state during refresh, update checks, cold opens, or intermittent network conditions.

Required behavior:
- Every service-worker navigation network request must have a finite abort timeout. Never use an unbounded network-first navigation.
- Normal app opens should return the last verified cached application shell immediately when available, while updating that shell from the network in the background.
- Explicit refresh/fresh/latest navigations should prefer the network so the user can receive a newly deployed build, but the network attempt must still be bounded and must fall back to the last verified shell on timeout or failure.
- Seed the offline/known-good application shell during service-worker installation when possible so the first controlled navigation has a fast fallback.
- Pull-to-refresh must fetch and verify a fresh build marker before navigation.
- A failed pull-to-refresh must stop its spinner and keep the already-working application visible; it must not call an unbounded location.reload fallback.
- Service-worker update checks must not block first paint or page interactivity. Run routine update checks after load/idle and bound explicit update waits.
- The startup deployed-build probe must itself have a finite timeout.
- Preserve cache-busted freshness parameters and the ability for stale cached HTML to self-correct when a newer deployed build is detected.
- Optimize load speed by keeping noncritical update work off the critical rendering path while retaining all v67-v71 aesthetic, responsive, countdown, subject-detection, and freshness invariants.


## Instant album-cover boot v73

Album artwork must begin loading as early as possible and must not wait for the current-card renderer or external catalog lookup on repeat visits.

Required behavior:
- Whenever a reliable artwork URL is resolved for a pipeline song, persist that URL locally together with songId, activeFrom, rolloverAt, and savedAt.
- During document head parsing, before the main application renderer runs, read the locally persisted cover records and identify any record whose active window contains the current time.
- Immediately inject image preload hints for those currently active cover URLs, with the first active cover receiving high fetch priority.
- Also inject a temporary CSS rule keyed by data-song-id so a dynamically created current card can inherit the already-known cover the instant it enters the DOM, before provider resolution completes.
- The normal resolver remains authoritative and replaces/refreshes the card artwork when needed.
- After first paint/idle, resolve and warm the next few pipeline covers at low priority, persist their URLs, and allow the browser HTTP cache to warm the image bytes before their future activation date.
- Background warming must never block first paint, interactivity, countdown updates, refresh behavior, or current-cover loading.
- Continue to prefer curated artworkUrl first, then COV high-resolution sources, then Apple/iTunes fallback.
- The early boot optimization must support multiple simultaneously active preparation songs by preloading and styling each active song independently.


## Staged cover and subject reveal v74

Album-cover loading must look intentional even when a first-time device has not yet cached the current artwork.

Required behavior:
- Current-song album artwork layers begin visually hidden while the rest of the card UI renders normally.
- Once the cover image is confirmed loaded or available from cache, reveal the blurred base, detail layer, and perimeter layer with a smooth approximately one-second fade.
- The isolated person/subject must not pop in simultaneously. It should begin roughly 180ms after the cover atmosphere becomes visible and use a slightly longer fade so it settles naturally into the composition.
- Preserve the exact approved cover/detail/perimeter target opacities on desktop and mobile; the fade changes timing only, not the final aesthetic.
- Manual and automatically detected subjects use the same staged subject reveal.
- If subject detection finishes before the cover is visually ready, hold the subject reveal until the cover has begun/finished entering rather than showing the person against an empty card.
- If the cover was already preloaded by the v73 boot system, still perform the brief staged visual fade so repeat loads remain polished rather than flashing instantly.
- Respect prefers-reduced-motion by removing transition animation while still showing the final artwork and subject state.
- Loading/reveal state must not affect countdown logic, semantic stage colors, masks, responsive subject positioning, multi-current-song support, refresh behavior, or cover-source selection.


## Current-song highlight preview queue v75

Songs currently in preparation may expose a compact official-audio preview module directly below the current preparation cards.

Required behavior:
- The preview module appears only when at least one current/preparation song exists and is placed immediately below the preparation cards.
- Every simultaneously active preparation song gets its own queued preview row; only one preview may play at a time.
- Resolve previews from Apple/iTunes song results using the same title/artist reliability scoring used for artwork matching.
- Use only official provider preview URLs; do not host or copy full copyrighted tracks into the repository.
- Default preview length is song-configurable from 10 to 15 seconds, with 12 seconds as the normal target.
- If a song provides previewClipStart, treat it as the authoritative manual chorus/climax override.
- Otherwise, locally fetch/decode the provider's preview and analyze short RMS energy frames to choose the strongest available 10–15 second window, favoring a central high-energy section and avoiding the extreme beginning/end when possible.
- If Web Audio analysis or preview fetching fails, fall back to a safe centered 10–15 second segment rather than breaking playback.
- Audio analysis happens locally in the listener's browser and does not upload audio to a third party.
- Start playback only from an explicit user tap. Preserve the user gesture immediately on iOS/Safari while highlight analysis resolves.
- Fade preview volume in over roughly 0.8 seconds and fade it out over roughly 1.15 seconds near the segment end. Manual pause and song switching should also fade down rather than cut abruptly.
- Show a subtle progress line, album artwork, song title, artist, play/pause state, and compact "Fragmento destacado" metadata while preserving the existing glass/card aesthetic.
- Current-card artwork should synchronize into the preview thumbnail when available.
- Preview lookup/analysis must never block page rendering, countdowns, cover loading, refresh, responsive behavior, or current-song rollover.


## Inline chorus preview v76

The audio preview control belongs inside each existing current/preparation song card. Do not create a separate Adelanto card or independent preview section.

Required behavior:
- Each current preparation card contains a compact "Escuchar coro" control directly beneath the song title/artist and before the countdown content.
- Preview length is exactly 15 seconds.
- Do not display a "10–15 s" badge or standalone Adelanto heading/card.
- A preview may be labeled "Coro" only when that song has explicit previewClipSection:"chorus" metadata and an explicit previewClipStart.
- Do not infer "chorus" solely from RMS energy or volume. Energy analysis may remain as an internal fallback for unconfigured songs, but the UI must identify that state as chorus pending confirmation rather than claiming it is the chorus.
- Song-specific manual chorus metadata overrides all automatic highlight selection.
- Current song Dios De Milagros is configured as a manual chorus preview using the official Apple/iTunes preview source. The song structure is externally confirmed to contain the chorus "Dios de milagros / Dios de imposibles..." repeatedly.
- Fade-in/fade-out, one-song-at-a-time playback, explicit user-tap requirement, iOS/Safari gesture handling, and local analysis fallback remain preserved from v75.


## Minimal Adelanto control and deterministic chorus source v77

The current preparation-card audio control is intentionally minimal.

Required behavior:
- Inside each prep card, show only the text "Adelanto" and one circular play/pause button. No progress bar, time display, thumbnail, "Coro" label, duration badge, explanatory copy, or mini-player container styling.
- Pause is immediate and authoritative. On pause, cancel any active animation frame and stop timer first, stop/pause the media immediately, then switch the button state in the same interaction. Do not fade after a user explicitly presses pause.
- Song switching must also stop the previous source immediately before starting the new one.
- Dios De Milagros must not use the Apple/iTunes 30-second preview because that provider excerpt begins at the start of the song rather than the chorus.
- Dios De Milagros uses the official Miel San Marcos YouTube video id 0_Wgv6_Dj8U as the preview source, with a song-specific manual chorus window and exactly 15 seconds of playback.
- The externally documented song arrangement identifies "Dios de milagros / Dios de imposibles..." as the chorus after Verse 1 and Verse 2. The preview source/timestamp must therefore target that chorus rather than infer a section from loudness.
- Future songs may use an official full-song source plus a manually confirmed chorus timestamp when provider preview clips do not contain the chorus.


## Precise chorus envelope v78

Automatic completion of a song preview must sound like a deliberately edited chorus excerpt, not a hard iframe cutoff.

Required behavior:
- YouTube-based chorus previews use the YouTube IFrame Player API with JavaScript control enabled, not only start/end URL parameters.
- Seek to the manually configured chorus start and define the segment endpoint as exactly start + 15 seconds.
- Fade from 0% to full preview volume during approximately the first 1.0 second.
- Begin the outro fade before the endpoint and reach 0% volume by the exact 15-second boundary. Current Dios De Milagros uses an approximately 1.8-second outro fade.
- Poll the player's actual getCurrentTime() during playback; do not use a wall-clock-only timeout to decide the audible endpoint.
- At the segment boundary: set volume to zero first, pause the player, seek back to the configured chorus start, then return the UI button to Play.
- Explicit user pause remains immediate and does not wait for an outro fade.
- Preload the YouTube IFrame API during idle time so preparing the player does not unnecessarily delay a user tap.
- Do not change the minimal "Adelanto + play/pause button" visual design established in v77.


## Instant preview interaction and load efficiency v79

The Adelanto player must not compete with first-page rendering and must feel immediate even when its media dependency has not loaded yet.

Required behavior:
- Do not preload the YouTube IFrame API during page startup or generic idle time. Load it only after explicit preview intent, beginning on pointerdown/touch intent for the Adelanto button.
- Dynamically add YouTube network preconnect hints only when preview intent occurs.
- The play button must never swap to a spinner or change geometry. On first tap, immediately switch to the stable pause visual and a non-layout-changing starting state; when actual playback begins, transition internally from starting to playing without icon flicker.
- A second tap during either starting or playing must cancel the pending start/playback immediately and return to Play.
- Fade-in timing must use real elapsed time beginning when the YouTube Player actually reaches PLAYING state. Do not infer fade-in progress from the sought media timestamp.
- After unmuting, explicitly set volume back to zero before audible playback begins. This prevents Safari/mobile players from restoring a previous non-zero volume.
- Fade-out remains based on actual media time remaining until the exact chorus endpoint.
- Remove nonessential MediaPipe CDN preconnects from the initial document head. Face-detection libraries are loaded only if automatic subject detection is actually required.
- Current-song artwork remains eager/high priority; future-song artwork warming is delayed further into idle time and staggered so it cannot compete with the current card, refresh, or first interaction.
- Preserve v72 bounded refresh, v73 instant current-cover boot, v74 staged cover/person fade, and all responsive compatibility rules.


## Preview playback request integrity v80

The Adelanto request token represents user intent only.

Required behavior:
- Creating, replacing, or destroying an internal YouTube Player instance as part of the same requested Play operation must not increment/invalidate the request token.
- Explicit user pause/stop and a subsequent new user play request may invalidate older asynchronous work.
- A first Play request must survive asynchronous API loading and player construction and reach playVideo().
- If the YouTube API or player does not become ready, clear the starting state and return the control to Play within a bounded timeout; never leave the button stuck.
- Preserve v79 zero-volume fade-in timing, on-intent dependency loading, and first-page performance rules.


## Dios De Milagros chorus extension v81

For Dios De Milagros, the Adelanto chorus window is song-specific at 17 seconds instead of the default 15 seconds so the chorus phrase can complete naturally before the existing fade-out envelope finishes.

Required behavior:
- Keep previewClipStart at the manually confirmed chorus start.
- Use previewClipDuration from song metadata when calculating the YouTube segment endpoint.
- Dios De Milagros uses 17 seconds.
- Preserve the existing fade-in and fade-out durations and all interaction/load-speed behavior.
- Other songs remain free to use their own configured duration; do not globally change every preview to 17 seconds.


## Dios De Milagros chorus retime v82

For Dios De Milagros, the preview window is treated as a musical edit rather than a fixed-duration trim.

Required behavior:
- Start the preview 2 seconds earlier than v81 so the fade-in can happen before the chorus vocal phrase is already underway.
- End the preview 2 seconds later than v81 so the final chorus phrase has additional room before the fade reaches silence.
- Current settings: previewClipStart 80 seconds, previewClipDuration 21 seconds, previewFadeIn 1.35 seconds, previewFadeOut 2.0 seconds.
- Do not globally apply these values to other songs; they are song-specific.
- Preserve the actual-player-time envelope and immediate user pause behavior.


## Immediate current-song preview start v83

For the current preparation song, the Adelanto player is prepared after initial page load so a Play tap can start media immediately without doing player creation/seek work on that tap.

Required behavior:
- Prepare the hidden YouTube player only after the current page has rendered and become idle; never block first paint/current card loading.
- Cue the current song at its configured chorus start while muted at volume 0.
- On Play, if that song is already prepared, do not perform a redundant seek before playVideo(); unmute, keep volume at 0, and start immediately.
- Current Dios De Milagros settings: start 80 seconds, duration 18 seconds, fade-in .35 seconds, fade-out 1.5 seconds.
- The shorter fade-in is intentional so the chorus is audible essentially immediately while still avoiding a hard audio edge.
- After automatic completion, cue the player back to the chorus start so the next tap is immediate again.
- Preserve first-page performance by doing preparation only after render/idle.


## Preview immediacy and center-cover reveal v84

Current-song preview:
- Prepare the current hidden YouTube player shortly after the window load event (roughly 280 ms later), rather than waiting several seconds for generic idle time.
- This preparation remains after first render and must not block the initial document/current cover.
- Dios De Milagros uses start 79 seconds, duration 18 seconds, fade-in .22 seconds, fade-out 2.4 seconds.
- The earlier fade-out is intentional; do not lengthen the overall window to compensate.
- Keep the player cued back to the song-specific chorus start whenever a reset occurs so subsequent Play taps require no seek.

Current-card album art:
- Do not leave the visual center as a low-detail blurred dead spot.
- The lightly blurred detail layer must include a broad, low-opacity central reveal so album typography/art remains perceptible through the center.
- Preserve the approved person isolation/masks exactly.
- Move the stronger soft/dark blending toward the left/title side with a gentle left-to-center gradient; the center and right side should retain more visible album detail.
- Apply the same principle on mobile with a slightly softer central reveal.


## Faster Adelanto response v85

For the current song, favor near-instant Adelanto response once the visible card has rendered.

Required behavior:
- Dios De Milagros keeps the same start/end window from v84: start 79 seconds, duration 18 seconds.
- Move the outro fade approximately 1.5 seconds later by shortening the fade-out envelope from 2.4 seconds to .9 seconds; do not extend the endpoint.
- Use a very short .16-second fade-in so the audio edge remains polished but feels immediate.
- Prepare the current YouTube player approximately 40 ms after DOMContentLoaded/current-card render rather than waiting for the full load event.
- Silently prebuffer only the current song at volume 0/muted, then pause and hold it at the chorus start so the Play tap reuses a ready player.
- Do not prebuffer future songs or multiple players.
- Preserve all existing first-paint/current-cover optimizations and the v84 center-cover composition.


## Dios De Milagros preview micro-tune v86

Small song-specific timing refinement:
- Keep previewClipStart at 79 seconds.
- Extend the endpoint slightly by using previewClipDuration 18.8 seconds.
- Keep previewFadeOut at .9 seconds.
- Reduce previewFadeIn to .08 seconds so audio becomes audible almost immediately while still avoiding a hard zero-to-full edge.
- Begin current-song prebuffer preparation about 10 ms after the current card/DOM is ready.
- Do not apply these micro-timing values globally to future songs.


## Hot-standby Adelanto playback v87

Tap-to-audio latency is independent from the fade envelope.

Required behavior:
- Dios De Milagros uses previewClipStart 79 seconds, previewClipDuration 19.4 seconds, previewFadeIn .35 seconds, and previewFadeOut .9 seconds.
- Keep the smooth .35-second fade-in; do not shorten it to hide startup latency.
- After prebuffering, keep the current YouTube player actively PLAYING while muted at volume 0 and repeatedly anchored within roughly .25 seconds of the chorus start.
- On Play, release hot standby and unmute the already-running stream. Avoid waking a paused iframe when hot standby is available.
- Explicit Pause remains immediate, then silently restores hot standby at the chorus start.
- Automatic completion fades to zero, then silently restores hot standby at the chorus start.
- Only the current song may use hot standby.


## Cross-platform album-art composition lock v88

The current-song album-art background must preserve the same visual composition across desktop, tablet, mobile, tiny-width, and landscape layouts.

Required behavior:
- Use shared CSS variables for blurred-base opacity, detail-layer opacity, perimeter-detail opacity, and detail blur strength.
- Desktop baseline: base .76, detail .42, edge .50, detail blur 2.6px, edge blur 1.6px.
- Tablet 641–899px keeps the desktop baseline exactly.
- Mobile <=640px may soften only slightly for density/readability: detail .40, edge .48, detail blur 2.8px, edge blur 1.7px. Do not create a visibly different composition.
- Tiny mobile must retain the mobile composition instead of progressively reducing album-art visibility.
- Short landscape keeps the desktop background composition; layout changes must not alter artwork balance.
- The broad center-detail reveal uses the same focal geometry across breakpoints so the visual center never becomes a blurred/dead spot on one device but visible on another.
- The left/title-side dark blend remains shared across all sizes.
- Person/subject placement and size may remain responsive; do not alter the approved subject masks or their responsive positioning as part of background consistency work.
- Reduced-transparency/forced-colors accessibility modes may intentionally reduce artwork visibility and are exempt from visual parity.


## Mobile cover visibility safeguard v89

Mobile browsers must not depend solely on inherited custom-property opacity targets for current-song cover layers.

Required behavior:
- At <=640px, explicitly set the ready-state opacities for blurred base, cover-detail, and cover-edge-detail.
- Mobile ready-state targets: base .76, detail .40, edge .48.
- Mobile may still use slightly softer blur values (detail 2.8px, edge 1.7px).
- Do not add tiny-width opacity overrides beneath 640px; tiny phones inherit the same explicit mobile visibility.
- Desktop/tablet shared composition variables remain valid.
- Preserve v84/v88 center-detail and left-side blend geometry plus all approved subject masks.


## Tiny-mobile cover inheritance v90

Phones <=340px must inherit the explicit <=640px current-cover ready-state visibility without any additional cover opacity overrides.


## Cross-platform experience parity v91

The website should present the same design language and interaction behavior across iPhone/iPad Safari and installed web app, Android Chromium/PWA, desktop Safari/Chrome/Edge, tablet, landscape, and supported small screens. Responsive sizing may change where necessary, but the perceived product must remain the same.

Adelanto:
- Fade-in and fade-out use the same smoothstep volume envelope, driven by requestAnimationFrame and the player clock rather than CSS or browser-specific media transitions.
- The configured fade durations remain song-specific; do not alter timing merely for a particular browser.
- The Play button explicitly resets native browser button appearance so Safari/iOS and Chromium/Android render the same circular control.
- SVG events remain owned by the button, not by the icon.

Album-art/current card:
- Preserve the v84 center-detail reveal, left-side blend, v90 explicit mobile visibility, and approved person masks/placement.
- Cover base/detail/edge layers always share the same background position/repeat behavior and centered transform origin across engines.
- Do not introduce device-specific artwork compositions unless needed for subject placement or accessibility.
- Browser accessibility modes such as reduced motion, reduced transparency, forced colors, and increased contrast may intentionally differ.

Global:
- Lock browser text autosizing at 100% to prevent mobile Safari/Chromium from unexpectedly changing typography hierarchy.
- Device breakpoints may rearrange layout for fit, but must not change semantic colors, wording, feature availability, animation intent, cover-art identity, or interaction meaning.


## Wall-clock preview envelope v92

Adelanto volume-envelope timing must not depend on YouTube currentTime after hot standby.

Required behavior:
- Keep immediate hot-standby startup.
- Drive fade-in, fade-out, and total preview duration from performance.now() elapsed time once the user starts playback.
- Use the same smoothstep curve for fade-in and fade-out on every platform.
- For Dios De Milagros: previewClipDuration 19.4 seconds, previewFadeIn .70 seconds, previewFadeOut 1.0 second.
- The fade clock begins at the Play tap for an already-prepared hot player so the fade is audibly present from zero volume while the music begins immediately.
- If the player was not prepared and must actually start later, reset the fade clock when the player reaches PLAYING.
- Do not use YouTube currentTime to decide when the fade-out begins or when the preview stops.
- This is specifically to eliminate Safari/iOS and Chromium timing differences caused by iframe seek/playback clock behavior.


## True Adelanto pause/resume state machine v93

The Adelanto control must behave as a real media player, not a play/stop toggle.

Required behavior:
- First Play starts from the configured preview beginning and uses the normal smooth fade-in.
- Pause is immediate and freezes the current YouTube media position exactly where the user paused.
- A paused preview must not be rewound, hot-standby looped, or silently advanced.
- Play after Pause resumes from the saved media position and continues the same preview timeline toward the original ending.
- Pause/resume may be repeated any number of times without invalidating the control or resetting the clip.
- Wall-clock elapsed preview time is saved on Pause and restored on Resume so the ending and fade-out remain tied to the original preview timeline rather than restarting.
- Resume does not replay the opening fade-in unless the pause occurred during that opening fade; the envelope continues from the saved elapsed position.
- When the preview reaches its natural end, clear all pause state, fade out normally, stop audibly, and return the hidden player to the beginning/hot standby.
- The next Play after natural completion is a brand-new play from the beginning with the normal smooth fade-in.
- Behavior must be identical across mobile Safari/PWA, Android Chromium/PWA, and desktop browsers.


## Coordinated preparation-cover reveal v94

The current preparation-song artwork must reveal as one intentional visual composition rather than as separately loading image pieces.

Required behavior:
- Blurred base, strategic detail layer, perimeter-detail layer, and isolated subject all use the same 1.65-second opacity transition and the same cubic-bezier(.22,.65,.25,1) easing.
- Do not intentionally stagger the person behind the background artwork.
- For manual/ready subject placement, add cover-ready and subject-ready in the same animation frame after the artwork image has loaded and decoded.
- When Image.decode() is available, wait for decode before beginning the reveal so CSS background layers are painting from the same decoded resource.
- Use a double requestAnimationFrame only to establish the initial opacity-zero frame before applying ready classes; do not add arbitrary visual delays.
- If automatic subject detection genuinely completes later, the subject may reveal later, but it must use the same 1.65-second transition so it never pops in.
- Preserve v90 mobile cover visibility, v91 cross-platform composition invariants, and all approved subject masks/positioning.
- Reduced-motion mode remains exempt and may reveal immediately.


## Universal Web Audio Adelanto engine v95

The preparation-song Adelanto must use one audio engine across supported platforms.

Reason:
- iOS does not provide reliable JavaScript software-volume control for ordinary HTML media / embedded media in the same way desktop browsers do.
- YouTube iframe playback can surface as a full OS media session on iOS, including lock-screen playback and seeking, which is inappropriate for a short in-site preview.
- Web Audio GainNode / AudioBufferSourceNode provides platform-independent gain automation and precise clip control.

Required behavior:
- Resolve the song's Apple/iTunes catalog preview URL, fetch and decode it into an AudioBuffer, and play it through AudioBufferSourceNode -> GainNode -> destination on ALL platforms.
- Do not select the YouTube iframe path for configured preparation-song previews.
- Use one canonical clip duration per song on every platform. Dios De Milagros remains 19.4 seconds.
- Use previewFadeIn .70 seconds and previewFadeOut 1.60 seconds for Dios De Milagros.
- Select a clip window from the catalog preview using the requested preview duration; do not hard-code a 15-second analysis window.
- Schedule gain ramps on the Web Audio AudioParam so iOS, Android, macOS, Windows, Safari, Chrome, Edge, and installed PWAs hear the same fades.
- Pause stops the current AudioBufferSourceNode and stores elapsed preview time. Resume creates a new source at clipStart + elapsed and continues the original envelope/timeline.
- Natural completion resets elapsed time so the next Play starts from the preview beginning with the full fade-in.
- When the document becomes hidden, pagehide fires, or the document freezes, pause preview playback. A locked phone must not continue the preview in the background.
- Clear top-level Media Session metadata/state/action handlers for the preview. The preview must not intentionally expose seek/skip/full-song transport controls on the OS lock screen.
- Keep decoded preview buffers cached in-memory for low-latency replay during the page session.
- If the catalog preview cannot be fetched/decoded, disable the preview control rather than silently falling back to a platform-inconsistent full YouTube media session.


## Catalog chorus lock v96

For songs whose Apple/iTunes preview asset already begins at the desired musical highlight, use an explicit offset within the catalog preview instead of energy-based window selection.

Dios De Milagros:
- previewCatalogOffset: 0 seconds relative to the Apple/iTunes 30-second preview asset.
- previewClipDuration remains 19.4 seconds.
- previewFadeIn remains .70 seconds.
- previewFadeOut remains 1.60 seconds.
- previewClipStart 79 remains historical/full-song chorus reference only and is not used as an offset into the 30-second Apple preview.
- Do not run strongestPreviewWindow() when previewCatalogOffset is explicitly configured.
- The universal Web Audio engine, pause/resume behavior, background-stop behavior, and cross-platform parity from v95 remain unchanged.


## Spotify chorus preview source v97

Dios De Milagros uses the official Spotify-hosted 30-second preview asset for the exact track as its Web Audio source.

Track:
- Dios De Milagros - En Vivo Desde México
- Miel San Marcos & Kim Richards
- Spotify track URI: spotify:track:1v2lsV9SYQc0KbRkOLEJzk

Preview source:
- previewAudioProvider: spotify
- previewAudioUrl: https://p.scdn.co/mp3-preview/7885aca093c7465af5cb0c4696094db59d167c3f.mp3
- previewCatalogOffset: 0
- previewClipDuration: 19.4 seconds
- previewFadeIn: .70 seconds
- previewFadeOut: 1.60 seconds

Required behavior:
- A configured previewAudioUrl takes priority over Apple/iTunes preview lookup.
- The direct preview still plays only through the universal Web Audio engine.
- Do not re-enable Spotify's full player, YouTube iframe playback, Media Session transport, or background playback for the Adelanto.
- Pause/resume, visibility/background stop, exact duration, and gain-envelope behavior from v95 remain unchanged.


## Full Spotify preview playback v98

Dios De Milagros uses the complete decoded Spotify preview asset rather than truncating it to 19.4 seconds.

Required behavior:
- previewUseFullAsset: true.
- Start at 0 seconds of the Spotify preview asset.
- Use the asset's actual decoded duration as the total Adelanto duration on every platform.
- Keep previewFadeIn at .70 seconds.
- Keep previewFadeOut at 1.60 seconds and apply it to the final 1.60 seconds of the full provider preview.
- Pause/resume continues within the same full-preview timeline.
- Natural completion resets to the beginning for the next Play.
- Web Audio remains the only active playback engine for the Adelanto.
- Background/lock-screen stopping and Media Session clearing remain unchanged.
- previewClipDuration may remain in song metadata for historical/fallback compatibility but must not limit playback when previewUseFullAsset is true.


## Desktop background preview continuation v99

Desktop browser tab changes may allow the short Adelanto to continue and finish normally.

Required behavior:
- On desktop-class environments (fine pointer + hover capability and not a mobile user agent), visibilitychange to hidden does not pause the Web Audio preview.
- Mobile and tablet environments still pause immediately when hidden so iPhone/iPad/Android lock/background behavior remains contained to the website.
- pagehide still stops playback everywhere when the page is actually navigated away from or closed.
- document freeze still stops playback because the browser is suspending the page.
- Media Session state remains cleared; desktop tab continuation must not create OS-level full-song controls.
- Full Spotify preview duration, fades, pause/resume behavior, and Web Audio engine from v98 remain unchanged.


## Desktop AudioContext keepalive v100

Desktop Chrome/Safari/Edge must allow an actively playing Adelanto to continue when the user switches tabs.

Required behavior:
- Desktop classification must not depend on hover/pointer media queries.
- Use navigator.userAgentData.mobile when available; otherwise treat iPhone/iPod/Android as mobile.
- Detect iPadOS separately because it may identify as Macintosh when maxTouchPoints > 1.
- Macintosh without the iPadOS touch signature is desktop, including Chrome on Mac.
- While an Adelanto is playing on desktop and the document is hidden, do not pause it on visibilitychange.
- If the Web Audio AudioContext enters suspended state while desktop playback is active in a hidden tab, immediately call resume().
- Attach an AudioContext statechange listener for this keepalive behavior.
- Desktop freeze events must not proactively invoke the mobile pause path.
- Mobile/tablet background and lock behavior remains unchanged.
- pagehide still stops playback everywhere when leaving/closing the page.


## iOS Web Audio gesture unlock v101

The live Web Audio playback context must never be created merely to decode/preload preview audio on mobile.

Required behavior:
- Download and decode preview assets during hydration using OfflineAudioContext when available.
- Do not create the live AudioContext during mobile preview preparation.
- On pointerdown/touchstart/click of the Adelanto control, synchronously create or retrieve the live AudioContext.
- On that same user gesture, start a one-sample silent AudioBufferSourceNode and call resume() when suspended. This is the iOS Safari/PWA playback unlock.
- Then start the already-decoded Spotify preview through the normal AudioBufferSourceNode -> GainNode path.
- The silent unlock source must be ephemeral and must not establish background media or Media Session controls.
- Desktop AudioContext keepalive behavior from v100 remains unchanged.
- Mobile background/lock pause behavior remains unchanged.
- Full Spotify preview playback and .70 / 1.60 second fades remain unchanged.


## Cross-platform stability polish v102

This pass tightens mobile audio shutdown, preparation-card artwork reliability, and playlist visual hierarchy.

Mobile audio shutdown:
- On mobile/tablet visibility loss, pagehide, or freeze, do not tear down an active Web Audio source at full gain.
- Save elapsed preview time, cancel scheduled gain automation, ramp GainNode exponentially to near-zero over approximately 80 ms, then stop/disconnect the source after approximately 95 ms.
- Suspend the mobile AudioContext after the source is silent.
- This shutdown path exists to prevent iOS route-change clicks, chirps, or sine-like artifacts.
- Manual Pause remains immediate and preserves the existing pause/resume semantics.
- Desktop hidden-tab continuation from v100 remains unchanged.

Cover reliability:
- Reuse the most recent valid per-song boot artwork from localStorage immediately before provider lookup.
- Provider lookup may retry up to three attempts with short backoff.
- If provider lookup fails, retain the boot artwork rather than clearing the visual.
- revealCoverWhenLoaded must have a timeout watchdog so a stalled image event cannot leave the cover permanently invisible.
- Do not restart the cover reveal when the resolved provider URL is identical to the already-applied boot artwork URL.
- Preserve the coordinated 1.65 second cover/detail/edge/person fade, mobile explicit opacity safeguards, approved masks, and cross-platform composition locks.

Playlist hierarchy:
- The playlist card remains near the top as a quick utility but is visually secondary to current preparation songs.
- Use tighter card padding, smaller title/note, smaller icons, 44px minimum controls, and reduced gaps.
- On normal mobile widths, keep the three playlist services in one compact row when practical.
- On extremely narrow screens, allow labels to stack/wrap without horizontal overflow.


## Direct current-cover and hard mobile stop v103

Dios De Milagros current-song artwork:
- Use the exact official Spotify artwork URL directly in song metadata.
- Preconnect/dns-prefetch i.scdn.co and preload the artwork at high priority in <head>.
- Explicit artworkUrl bypasses COV/iTunes provider lookup for the current song's first paint.
- Provider retries remain available for future songs without explicit artwork.
- Existing coordinated 1.65 second visual fade and subject composition remain unchanged.

Mobile background/lock audio:
- Do not use a delayed gain ramp, setTimeout teardown, or AudioContext suspend when the app becomes hidden/locked.
- Immediately cancel GainNode automation and set gain to exactly 0.
- Immediately stop and disconnect the AudioBufferSourceNode and GainNode.
- Close the mobile AudioContext after the graph is already muted/disconnected, then clear the stored context reference.
- The next user Play gesture creates/unlocks a fresh AudioContext.
- This path is intentionally different from manual Pause; manual Pause continues to preserve exact resume position.
- Desktop hidden-tab continuation remains unchanged.


## Earliest mobile lifecycle stop v104

Mobile background/lock stopping must use the earliest lifecycle signal available.

Required behavior:
- window blur is the first-line stop event on mobile/tablet because iOS standalone PWAs can deliver visibilitychange later during lock/app-switch transitions.
- Also listen for standard visibilitychange, webkitvisibilitychange, pagehide, and freeze as backup lifecycle signals.
- All mobile lifecycle events route through one idempotent stopPreviewForMobileBackground() helper.
- The helper uses the v103 hard-stop path: immediate zero gain, immediate source stop/disconnect, and mobile AudioContext close.
- Event listeners use capture where supported so the stop runs as early as possible in dispatch.
- Desktop tab switching must remain unaffected. Desktop blur must not stop the preview.
- Desktop pagehide still stops playback when the page is actually being left/closed.


## Platform reliability hardening v105

The website/PWA must prefer deterministic first-load behavior and self-healing over optimistic network timing.

Current preparation cover:
- A song with explicit artworkUrl renders an eager native <img> blurred base directly in currentSongCardMarkup.
- The native base is independent of provider lookup, Image.decode(), palette extraction, subject detection, and cover-ready state.
- The native image uses loading="eager", decoding="async", and fetchpriority="high".
- The existing CSS detail/edge/person layers remain layered above it and retain the approved composition.
- For explicit native artwork, the pseudo-element blurred base is disabled to avoid double brightness.
- The head preload for the current Spotify cover must use the same non-CORS request mode as the displayed image/CSS request; do not add crossorigin to that image preload.
- Explicit artwork is also written into --cover-image inline on card creation so detail layers do not wait on ensureCoverTheme.
- Subject setup still runs when the native/inline artwork URL already matches the resolved URL.
- Existing v94 1.65-second detail/person transitions remain intact; the native blurred base exists as the fail-safe layer.

Bounded resources:
- Clock sync uses a 2.5-second bounded request.
- iTunes artwork and preview lookups use bounded requests.
- Direct/Spotify preview audio fetch uses an 8-second bound.
- Palette and subject image helpers reject after 6.5 seconds instead of hanging forever.
- A timed-out optional enhancement must never prevent the current card, countdown, links, or other primary UI from remaining usable.

Lifecycle recovery:
- On pageshow, re-render current state and retry missing transient artwork/preview resources.
- On online, retry transient resources and recalibrate the server clock.
- Never require the user to close/reopen the app merely to recover from a temporary network/resource failure.

Service worker:
- Register immediately when the main script executes instead of waiting for window.load.
- Service-worker installation must cache static assets independently; one failed asset may not reject the whole install.
- Healthy-network navigations should prefer a fresh deployed shell within a short bounded window, with the last known-good cached shell as fallback.
- Cache matching for version-query static assets should ignore the query string because the service-worker cache name already versions the asset set.
- Offline or slow-network fallback remains mandatory.


## Zero-flash startup v106

The website/PWA must not perform a visible second-stage startup after the first frame has painted.

Required behavior:
- .reveal content is visible by default.
- Initial and near-viewport sections never begin at opacity 0 or translated position.
- Only genuinely below-the-fold sections receive reveal-pending and may animate when scrolled into view.
- The current-song card and playlist utility must be in final layout from the first painted frame.
- The deployed-build freshness probe must never call location.replace() merely because a newer build is detected after paint.
- When a newer build is detected, trigger service-worker update/skipWaiting silently and allow the next navigation to use the fresh shell.
- Explicit user pull-to-refresh may still perform a navigation because the user intentionally requested refresh.
- Preserve the v105 fast-network-first service-worker navigation behavior and cached offline fallback.
- Preserve the current-cover native fail-safe layer and all approved cover/detail/person transitions.


## IPCDJ logo launch sequence v107

Startup presentation:
- Every true document launch begins with a fixed, full-viewport IPCDJ launch layer already present in the initial HTML.
- The launch layer background is #05070b with only a subtle radial blue ambient field; never use a white intermediate canvas.
- The launch logo is an inline vector derived from the repository's highest-quality IPCDJ favicon/logo SVG, with background rectangles removed and logo geometry rendered white.
- The exact logo geometry is separated into left ring, central CDJ/Worship mark, and right ring for coordinated motion.
- Animate only opacity and transform on SVG groups. Do not animate SVG filters, blur, or expensive paint effects.
- Ring A enters from a very small left/down offset and ring B mirrors from right/up. The central mark fades in without modifying its baked SVG positioning transform; the shared outer logo stage performs the restrained scale resolve.
- Motion must remain subtle, premium, centered, and church-brand appropriate; no bouncing, spinning, flashy particles, or gamified loading indicators.
- Normal launch minimum visibility is approximately 1.22 seconds; hard maximum is approximately 2.45 seconds.
- Exit uses a ~.68 second whole-layer opacity dissolve into the already-rendered website.
- The launch layer waits for the current-song card and, when present, its eager native cover image, but the hard maximum guarantees it can never trap the user behind a loader.
- Remove the launch node from the DOM after exit; it must not remain as an invisible interaction layer.
- Lock page scrolling only while the launch layer exists.

Cross-platform requirements:
- Use inline SVG so logo display has no network dependency.
- Use CSS keyframes/opacity/transform only; no JavaScript frame-by-frame animation loop for logo motion.
- Support iOS Safari/PWA, Android Chrome/PWA, macOS Safari/Chrome, Windows Chrome/Edge, tablet, portrait and landscape.
- For prefers-reduced-motion, disable component motion and shorten the exit while retaining a brief static branded launch state.
- The existing v106 zero-flash content rules remain: underlying initial content is already laid out and visible beneath the launch layer.
- The existing v105 first-load cover fallback and platform hardening remain unchanged.


## Exact one-piece logo splash v108

v108 supersedes the component-level SVG animation strategy from v107.

Logo construction:
- Build launch-logo-white.svg directly from the canonical repository favicon.svg geometry.
- Preserve the original visible black logo shapes and convert them to white.
- Preserve the original final white donut as a transparent cutout using an SVG luminance/alpha mask rather than displaying it as a second white circle.
- The resulting logo has a transparent canvas and exact IPCDJ geometry.
- The exact same SVG is also embedded inline in the initial HTML so launch rendering has zero network dependency.

Animation:
- Treat the finished logo as one visual unit. Do not animate individual clipped SVG groups, rings, letters, or internal transforms.
- Animate only the outer .launch-logo-stage with opacity plus a very small translate/scale settle.
- Use a pure #000000 launch canvas for clean native-style continuity.
- Normal reveal is approximately .92 seconds followed by a short stable hold.
- Exit dissolves the full black launch layer over approximately .72 seconds into the already-rendered website.
- Do not use circles, particles, spinner motion, SVG filters, internal clip-path transforms, or element-by-element logo drawing effects.
- The logo must remain centered and fully recognizable throughout the entire visible portion of the animation.

Reliability:
- Launch layer exists in initial HTML and critical CSS.
- Inline exact vector means no logo network fetch can delay the splash.
- Minimum normal visibility is approximately 1.26 seconds and hard maximum is approximately 2.6 seconds.
- Wait for the current prep card/eager cover where practical, but never exceed the hard maximum.
- Reduced-motion users see the exact static logo with a short crossfade.
- Preserve v106 zero-flash startup rules, v105 resource hardening, v104 mobile audio lifecycle stop, desktop tab preview continuation, and the full Spotify Adelanto.


## Persistent PWA launch state v109

v109 fixes the distinction between a document refresh and reopening an installed PWA.

Launch lifecycle:
- The #ipcdj-launch node remains in the DOM for the lifetime of the document. Do not remove it after the initial animation.
- Explicit states are launch-playing, launch-exit, launch-idle, and launch-armed.
- launch-idle is fully hidden and noninteractive after the normal exit.
- In installed standalone/fullscreen PWA contexts, visibility loss/pagehide arms the launch layer while the app is backgrounded.
- launch-armed is an opaque black full-screen layer with the logo held at its pre-animation opacity/transform.
- When the PWA becomes visible again via visibilitychange, webkitvisibilitychange, pageshow, or focus, restart the exact one-piece logo reveal from a fresh CSS animation timeline.
- This makes warm reopen/resume visually match a refresh/new-document launch instead of exposing the resumed website frame first.
- Ordinary browser tabs do not replay the splash merely because the tab changes visibility; warm replay is limited to installed display modes.
- The launch state machine remains idempotent and uses cycle tokens so duplicate lifecycle events cannot create overlapping exits/replays.

Native alignment:
- HTML theme-color is pure #000000 during startup.
- Manifest background_color and theme_color are pure #000000 so Android/Chromium generated PWA launch surfaces match the custom web splash.
- Provide ios-startup-universal.svg through apple-touch-startup-image as a static Apple startup bridge using the same black canvas and exact white IPCDJ vector.
- Precache launch-logo-white.svg and ios-startup-universal.svg.
- The web launch overlay remains the canonical animated experience; the native bridge only exists to reduce the visual seam before web content takes control.

Preserve all v108 exact-logo geometry, v106 zero-flash rules, v105 platform hardening, v104 mobile audio lifecycle stop, full Spotify preview behavior, and desktop tab continuation.


## Fixed-position zero-flash launch v110

v110 supersedes the remaining launch-motion and warm-resume timing details from v108/v109.

Logo animation:
- The exact one-piece IPCDJ logo stays in one fixed centered position for the entire launch sequence.
- Do not translate, scale, slide, drift, bounce, or otherwise move the outer .launch-logo-stage.
- The logo animation is opacity-only: fade in, stable hold, then fade out as the black launch layer dissolves.
- Start the opacity reveal immediately with no intentional animation delay.
- Keep the existing one-piece exact SVG geometry; never return to internal ring/group animation.

Pre-paint coverage:
- The root <html> element ships with ipcdj-launch-active already present in the initial markup.
- Critical head CSS provides a pure-black fixed pre-paint coverage layer behind #ipcdj-launch before body content can become visible.
- The launch node remains the topmost layer once parsed, and the root pre-paint layer disappears only when the launch lifecycle settles to idle.
- This exists specifically to prevent a split-frame website flash or compositing seam on mobile startup.

Installed PWA lifecycle:
- In standalone/fullscreen mode, window blur arms the black launch layer at the earliest app-switch/background signal, before later visibilitychange/pagehide events.
- visibilitychange, webkitvisibilitychange, and pagehide remain redundant backup arming signals.
- On foreground resume, the launch-playing state is applied synchronously before the next browser paint rather than waiting an extra requestAnimationFrame.
- Switching from launch-armed (animation:none) to launch-playing restarts the opacity animation without forced synchronous layout/reflow.
- Ordinary browser tabs still do not replay the splash merely from tab visibility changes.

Preserve v109 persistent launch states, v106 zero-flash content behavior, v105 reliability hardening, v104 mobile audio shutdown, exact launch logo geometry, and all approved visual/audio invariants.


## Repository hygiene v111

Repository files must have a concrete runtime, compatibility, deployment, documentation, or canonical-source role.

- icon-maskable-512.png was removed because the active manifest no longer referenced it; app-icon-safe.svg is the current maskable install asset.
- Do not retain obsolete duplicate assets merely because an older manifest or service-worker version once used them.
- Before deleting an asset, verify index.html, the active manifest, sw.js, CNAME/GitHub Pages behavior, platform-specific startup/icon requirements, and SITE_STANDARDS.md.
- Canonical source assets and compatibility fallbacks are not considered clutter even when they are not directly visible in the main UI.


## Seamless native-to-web launch handoff v112

v112 corrects the black-only launch regression introduced by the root pre-paint overlay and removes the duplicate native-logo handoff on iOS.

Web launch:
- Do not place an opaque html::before launch layer above the body launch node.
- The initial document background remains pure #000000, but #ipcdj-launch is the canonical visible web launch surface.
- The exact inline IPCDJ SVG must remain visible through the launch-playing opacity animation.
- The logo stays fixed in one centered position and uses opacity only: fade in, hold, fade out.

iOS native bridge:
- ios-startup-universal.svg is a pure-black bridge only. It must not contain the IPCDJ logo.
- The purpose of the Apple startup image is to hand off from the native phase into the web animation without showing a duplicate static logo first.
- The visible logo event belongs to the web launch overlay, not the native startup image.

Installed PWA backgrounding:
- Continue arming the black launch overlay on blur, visibilitychange, webkitvisibilitychange, and pagehide.
- After applying launch-armed, synchronously flush layout so WebKit has the armed state committed before suspension/snapshot whenever possible.
- Foreground resume still restarts the opacity-only launch sequence synchronously.

Preserve v111 repository hygiene, v110 fixed-position animation, v109 persistent launch lifecycle, v106 zero-flash content rules, and all audio/visual invariants.


## iOS standalone launch alignment v113

v113 addresses the installed-iOS PWA center jump and smoothness issues while leaving normal desktop/browser launch behavior intact.

Installed iOS alignment:
- Detect installed iOS/iPadOS standalone/fullscreen mode synchronously in <head>, before the launch node can paint.
- Compare screen.height with window.innerHeight.
- When the standalone web layer is measurably shorter than the physical screen by a plausible system/status-bar gap, offset the web launch logo upward by one half of that gap so its visual center matches the native full-screen center.
- This offset is static positioning compensation only; it is not an animation and must never tween.
- Recalculate the compensation only while the logo is hidden/armed or immediately before a fresh reveal.
- Do not use explicit 100vh/100svh/100dvh sizing on #ipcdj-launch; fixed inset:0 is the launch surface geometry.

Opacity sequence:
- Logo fade-in is opacity-only over approximately .72 s.
- Normal minimum launch visibility is approximately 1.10 s.
- On exit, first fade the logo to black over approximately .48 s while the launch canvas remains fully black.
- Only after the logo fade completes should the black launch canvas fade into the rendered website over approximately .60 s.
- Do not compound the logo opacity fade with the canvas opacity fade at the same time.
- The logo remains fixed in one visual position throughout every visible frame.

iOS native bridge remains pure black so the visible IPCDJ logo belongs to the web animation rather than a competing static startup image.

Preserve v112 seamless handoff, v111 repository hygiene, v110 fixed-position design intent, v109 persistent launch lifecycle, and all existing audio/visual reliability invariants.


## Stable fixed launch fade v114

v114 removes the iOS-only dynamic launch-position correction from v113.

Position:
- The launch logo has no translate, scale, or runtime viewport correction.
- Do not use --ipcdj-launch-y, screen.height / innerHeight corrections, or any other JavaScript positioning adjustment.
- The logo remains centered by the fixed full-screen #ipcdj-launch grid for its entire visible lifetime.
- Initial launch and warm PWA resume use the exact same centered coordinate system.

Fade lifecycle:
- Do not restart a CSS keyframe animation to reveal the logo.
- launch-armed establishes the opaque black overlay with logo opacity 0.
- After one requestAnimationFrame, launch-playing transitions logo opacity from 0 to 1 over approximately .72 seconds.
- The logo remains fully visible through the hold period.
- launch-exit transitions logo opacity back to 0 over approximately .62 seconds while the black layer begins its approximately .68 second dissolve after a short overlap delay.
- No transform may be animated or changed during reveal, hold, or exit.
- The initial HTML launch state is launch-armed, not launch-playing, so WebKit gets a real opacity-0 frame before the fade begins.
- Warm PWA resume follows the same armed -> playing transition and remains covered by black while the transition is prepared.

Preserve v112 pure-black iOS native startup bridge, v111 repository hygiene, v109 persistent launch lifecycle, and all approved reliability/audio behavior.


## iOS PWA launch lifecycle stabilization v115

v115 addresses installed-iPhone startup churn that does not reproduce in a normal mobile browser tab.

Lifecycle:
- The standalone launch state machine must be idempotent across blur, visibilitychange, webkitvisibilitychange, pagehide, pageshow, and focus.
- armLaunch must return immediately if the app is already armed in launch-armed state.
- window blur must not re-arm or restart the splash while the intro is already launch-armed, launch-playing, or launch-exit.
- Blur may arm only when the document is already hidden or the launch state is fully launch-idle.
- This prevents iOS Home Screen startup blur/focus churn from resetting opacity mid-fade.
- Real background transitions remain covered by visibilitychange/webkitvisibilitychange/pagehide and by blur once the app is idle.
- playLaunch ignores duplicate requests when an unarmed launch-playing cycle is already active.

Visual timing:
- Logo remains completely fixed with no transform or runtime positional correction.
- Fade-in is approximately .88 seconds.
- Minimum visible cycle is approximately 1.32 seconds.
- Logo fade-out is approximately .74 seconds.
- Black launch-layer dissolve is approximately .82 seconds with a short overlap so the website emerges gradually rather than snapping in.
- Hard maximum remains bounded at approximately 2.85 seconds.
- Reduced-motion behavior remains short and static.

Native handoff:
- Keep ios-startup-universal.svg as a pure-black Apple startup bridge.
- Keep apple-mobile-web-app-status-bar-style=black-translucent and manifest background/theme black.
- The custom Apple startup image exists to avoid iOS falling back to a screenshot of the previously visible application state.
- Existing Home Screen installations may retain launch-screen/install-time behavior independently from live web updates; device testing must distinguish installed-state artifacts from current web code.

Preserve v114 fixed-position transition architecture, v112 black native bridge, v111 repository hygiene, and all audio/reliability invariants.


## Exact native black iPhone startup surfaces v116

v116 replaces the single universal iOS startup SVG with exact-size native PNG startup surfaces for supported iPhone viewport families.

Purpose:
- iOS Home Screen web apps have a native startup phase before HTML/CSS/JavaScript controls the screen.
- If no matching startup image exists, iOS may display a fallback/previous-app screenshot or a blank system frame.
- The native phase must therefore be visually indistinguishable from the web launch canvas: pure #000000 with no logo or other visible content.

Assets:
- Native startup files live under ios-launch/.
- Each file is a real RGB PNG whose pixel dimensions exactly match its targeted iPhone standalone window family.
- All startup PNGs are solid #000000.
- The obsolete ios-startup-universal.svg is removed.
- Startup PNGs are referenced with exact device-width, device-height, -webkit-device-pixel-ratio, and portrait orientation media queries.
- Current/common iPhone families from 320x568@2 through 440x956@3 are covered.
- sw.js precaches the startup PNG set so the assets remain available offline and during installed-app launches.

Visual ownership:
- Native startup PNG: pure black only.
- Visible IPCDJ logo: web #ipcdj-launch overlay only.
- Website content: revealed only after the approved web fade sequence.
- Never place a logo, spinner, text, screenshot, gradient, or other visible object in native iOS startup PNGs.

Repository hygiene:
- The temporary generator workflow used to create the binary PNGs must not remain in the repository after generation.
- Startup assets are functional compatibility files and are not repository clutter.

Preserve v115 idempotent standalone lifecycle, v114 fixed-position opacity transitions, all audio behavior, and all other site invariants.


## iOS standalone light-launch experiment v117

v117 is a deliberately reversible experiment targeting only installed iPhone/iPad standalone web apps.

Scope:
- Desktop browsers remain on the established black launch canvas with white IPCDJ logo.
- Normal mobile Safari/Chrome browser tabs remain on the established black launch canvas with white IPCDJ logo.
- Android/PWA behavior remains unchanged.
- Only iOS/iPadOS standalone/fullscreen Home Screen mode receives the light launch treatment.

Native startup:
- The 13 exact-size ios-launch PNGs are solid #ffffff in v117.
- Their filenames and device media-query mappings remain unchanged; query version is v117.
- This intentionally absorbs WebKit's unavoidable white intermediate frame into the expected startup appearance.

Web launch:
- An early head detector adds html.ipcdj-ios-light-launch only when the environment is both iOS/iPadOS and installed standalone/fullscreen.
- In that mode, #ipcdj-launch uses #ffffff.
- The existing exact inline IPCDJ logo is rendered black via a static brightness(0) filter.
- Logo position, opacity timings, lifecycle guards, and fade architecture remain unchanged from v115/v116.
- The white overlay fades away over the already-rendered dark website, creating a light-to-dark crossfade rather than an abrupt cut.

Revert:
- backup-before-mobile-light-launch-v117 preserves the complete pre-experiment v116 state, including solid-black iOS startup PNGs.
- If the light launch is rejected, revert to that branch/state rather than manually reconstructing the previous assets.

Repository hygiene:
- The temporary PNG generator workflow is removed after successful asset generation.


## iOS light-launch safe-area hardening v118

v118 tightens the reversible v117 white-launch experiment without changing desktop, Android, or normal mobile-browser launch behavior.

Safe-area/compositor coverage:
- While html has both ipcdj-ios-light-launch and ipcdj-launch-active, html/body backgrounds are forced to #ffffff.
- Body scrolling/overscroll is disabled during the launch cycle.
- The iOS light launch overlay deliberately bleeds 160px beyond every viewport edge via negative inset and expands its minimum height accordingly.
- This overscan exists to prevent any bottom safe-area or compositor frame from exposing underlying website content during standalone startup/resume.
- Logo centering remains visually fixed because the overscan is symmetric on every edge.

System visual alignment:
- The early iOS standalone detector temporarily changes the standard theme-color meta to #ffffff before body paint.
- While the launch is active, root color-scheme is light.
- When the launch lifecycle settles idle, theme-color returns to #000000 for the dark website.
- Do not dynamically change apple-mobile-web-app-status-bar-style; keep black-translucent because current WebKit standalone viewport behavior can depend on it at install time.

Known status-bar tradeoff:
- black-translucent is intentionally retained for correct fullscreen/viewport behavior. Apple documents that it is translucent black and allows content beneath it, so some top-edge darkening over a white launch may remain system-owned.
- If that visual tradeoff is unacceptable, revert the entire light-launch experiment to backup-before-mobile-light-launch-v117 (v116 black launch), rather than changing the status-bar meta and risking standalone viewport regressions.

Preserve v117 iOS-only scope and v115/v114 fixed opacity/lifecycle behavior.


## iOS masked white-to-black launch v119

v119 tightens the reversible iOS light-launch experiment in two ways: underlying-site masking and a staged white-to-black exit.

Initial/active masking:
- The initial html element ships with ipcdj-launch-site-hidden in addition to ipcdj-launch-active.
- The masking rule applies only when ipcdj-ios-light-launch is also present, so desktop, Android, and ordinary mobile-browser behavior is unaffected.
- During the iOS standalone launch cycle, every direct body child except #ipcdj-launch is visibility:hidden.
- This prevents underlying website content from appearing through a transient bottom safe-area/compositor hole while the launch surface is active.
- Hidden page content still lays out and loads in the background, so appFrameReady() and resource loading continue to work.

White-to-black exit:
- The iOS light launch must not fade directly from white into the website.
- Stage 1: black logo fades away while the launch surface transitions from pure white to pure black over approximately .68 seconds.
- Throughout Stage 1, the website remains visibility:hidden.
- Once the launch surface is fully black, theme-color becomes #000000 and the root enters ipcdj-launch-black-stage.
- Stage 2: underlying website visibility is restored while still completely covered by the opaque black launch surface.
- The black launch surface then fades out over approximately .82 seconds, revealing the already-rendered dark website smoothly.
- The result should read visually as white -> black -> website, with no direct white-to-site cut.

Lifecycle:
- lockPage(true) always restores the iOS light launch to white, removes any prior black-stage state, and masks underlying site content.
- lockPage(false) clears active, site-hidden, and black-stage classes and leaves theme-color at #000000.
- Warm standalone resumes use the same masking and staged exit path.

Revert:
- backup-before-white-to-black-v119 preserves the complete v118 state.
- backup-before-mobile-light-launch-v117 still preserves the complete pre-light v116 state.


## Professional launch/readiness polish v120

v120 keeps the working v119 bottom-glitch fix and tightens the remaining iOS standalone handoff plus first-view readiness.

Top handoff synchronization:
- Keep apple-mobile-web-app-status-bar-style=black-translucent because current WebKit standalone viewport sizing can depend on it at install time.
- Do not attempt to solve the top transition by removing that meta tag.
- When the iOS light launch begins its white-to-black stage, switch the root black-stage state and theme-color to #000000 immediately at the start of that same transition.
- The launch surface transitions white -> black over approximately .48 seconds and the black logo fades over approximately .42 seconds.
- After reaching black, restore underlying website visibility while it remains fully covered, hold pure black for approximately 90ms, then fade the black launch surface away over approximately .74 seconds.
- This minimizes the system/status-area lag that was visible when theme-color changed only after the white surface had already become black.

First-view readiness:
- The installed-iOS site remains physically hidden under the launch surface until the current card is genuinely populated.
- appFrameReady requires current-song content, countdown text, an enabled preview Play control, loaded native cover, cover-ready state, and subject-ready when a subject layer exists.
- First-view cover/detail/subject transitions are disabled while the site is masked so those layers settle underneath the launch rather than visibly assembling after reveal.
- Explicit curated cover art may enter cover-ready synchronously while the iOS launch mask is active.
- The current card still obeys the bounded launch hard maximum; readiness cannot create an indefinite launch screen.

Preview control:
- The preview row is visible immediately and does not boot from opacity:0 or translateY.
- The first visible icon is always the Play triangle. Never show the circular loading/restart-looking glyph during page boot.
- The Play button is enabled and bound immediately; audio fetch/decode continues invisibly in the background.
- If the user taps before preparation completes, the user gesture unlocks Web Audio immediately and playback waits for the already-running preparation promise.
- Only a confirmed preview failure after interaction may disable the control.

Clock/render startup:
- Server clock calibration starts immediately but no longer triggers the first current-card render.
- First current-card render uses the restored session clock/device time immediately after definitions are available.
- The server calibration updates the absolute clock silently in the background.
- Do not make visible first-view content wait on the 2.5-second server-clock request.

Network readiness:
- Preconnect and DNS-prefetch p.scdn.co so the configured Spotify preview can begin preparation earlier.
- Keep the active cover eager/high-priority behavior and existing i.scdn.co preload.

Preserve v119 masked site architecture, v118 safe-area overscan, v117 iOS-only white-launch scope, and all existing audio stop/background invariants.


## Future-song Spotify previews v121

v121 extends the established Adelanto/Web Audio system to every song rendered in the future "Después" phase.

Sources:
- Glorioso Día uses the verified Spotify track spotify:track:0ksqrKoeNvywkfeqltzVQ3 and Spotify preview stream https://p.scdn.co/mp3-preview/4e7b800000c5620569348f794ae143844334b14c.mp3.
- No Fallarás - En Vivo uses the verified Spotify track spotify:track:04IkHz1UynmZ48Imgkla2J and Spotify preview stream https://p.scdn.co/mp3-preview/8a7c082277138d69b52b8a0ee1d490b0891365e2.mp3.
- Both future entries use the full Spotify-provided preview asset with the existing smooth .70s fade-in and 1.60s natural end fade-out.

Future-card UI:
- Every dynamically rendered future song card includes a compact Adelanto row inside its own box, beneath the learning/final-preparation metadata.
- The control uses the exact same Play/Pause SVG system and Web Audio path as the active song.
- The first visible state is always Play; there is no boot-time loading/restart glyph.
- Future preview rows hydrate in the background immediately after their cards render.
- pageshow/online recovery hydrates all preview rows, current and future.

One-at-a-time playback:
- Only one preview may actively play at a time.
- Tapping the same song retains the existing pause/resume behavior.
- Tapping a different song fades the currently playing Web Audio preview down over approximately .44 seconds before handing off to the newly selected preview.
- The new preview then enters with that song's configured fade-in.
- Switching does not close the AudioContext; the same live context is reused for a clean foreground handoff.
- Mobile background/lock remains an immediate hard stop and must never use this foreground crossfade path.

Rapid selection:
- Preview changes use a last-selection-wins token.
- If A is playing and the user taps B then C before the A->B handoff finishes, B must never begin after C has been selected.
- An in-progress fade-down promise is shared by later selection requests rather than creating competing gain ramps.

Preserve all v120 startup/readiness behavior and existing preview background-stop/audio safety invariants.


## Preview player redesign and true crossfade v122

v122 redesigns preview presentation and replaces sequential song switching with a real overlapping Web Audio crossfade.

Active/current song UI:
- The active preparation card keeps the preview in its existing general location below title/artist.
- Do not render a separate "Adelanto" text label followed by a detached circular button.
- Render one rounded horizontal preview pill containing:
  - Play/Pause affordance.
  - "Adelanto" label.
  - Five compact live level bars.
  - Remaining preview time.
  - A subtle non-seekable progress fill inside the pill.
- Remaining time uses tabular numerals and updates during playback.
- Progress is informational only and must not imply seekability.
- The equalizer bars are not a decorative loop: they are driven from the actual Web Audio signal through an AnalyserNode and getByteFrequencyData().
- Under prefers-reduced-motion, meter movement is replaced by a static bar state.

Future "Después" song UI:
- Future song cards do not display the word "Adelanto" or a separate preview row.
- Each future song has one circular Play/Pause control fixed in the upper-right corner of its own card.
- The release-date chip remains inside the card content stack under title/artist so it never competes with the playback control.
- Every future control uses the same hydrated Web Audio preview pipeline and exact Spotify preview source already configured for that song.

True crossfade:
- Switching between Web Audio previews must overlap the outgoing and incoming AudioBufferSourceNode graphs.
- The outgoing source remains alive while the incoming source starts.
- Use a .68-second equal-power transition:
  - outgoing GainNode follows a cosine-derived curve to zero;
  - incoming GainNode follows a sine-derived curve from zero to full level.
- Use AudioParam scheduling / setValueCurveAtTime for the gain envelopes; do not emulate crossfade volume with JS interval stepping.
- The outgoing graph is stopped/disconnected only after the overlap completes.
- The incoming preview retains its configured natural end fade-out.
- When an incoming preview has not decoded yet, keep the currently playing preview audible until the incoming buffer is genuinely ready. Do not fade to silence while waiting.
- Rapid selection remains last-selection-wins.
- A rapid A -> B -> C sequence may replace the selected voice, but stale asynchronous preparation must never start a superseded song.

Audio visualization:
- One AnalyserNode is attached to the shared preview AudioContext output.
- fftSize=64 with smoothingTimeConstant=.72.
- All live preview GainNodes route through the analyser before destination.
- requestAnimationFrame reads frequency data and maps five frequency regions to the five pill bars.
- The analyser must not alter the audio signal.
- Visual tracking also updates remaining time and the pill progress fill.

Mobile safety:
- Foreground crossfade behavior must never replace the established hard-stop background policy.
- On iPhone/iPad/mobile background or lock, current and outgoing crossfade voices are stopped and disconnected immediately.
- The mobile AudioContext is still closed after the graph is silenced.
- Analyser references are cleared with the closed mobile context.

Playback control scope:
- Keep controls to Play/Pause only.
- Do not add skip, previous, seek, scrubber, repeat, or other transport controls to preview surfaces.
- The active pill progress is display-only.

Launch logo:
- Platform-wide logo fade-in uses the same smooth cubic-bezier(.4,0,.2,1) character as the approved fade-out.
- Default fade-in is approximately 1.04 seconds.
- Mobile fade-in is approximately 1.12 seconds.
- Logo position remains completely fixed; no transforms, scale, drift, or runtime positional corrections are reintroduced.

Revert:
- backup-before-preview-ui-crossfade-v122 preserves the complete v121 state.

Preserve all v120 launch/readiness behavior, v119 masked white-to-black iOS architecture, and existing preview source/audio safety invariants.


## Album-derived preview pill palette and launch fade v123

v123 refines the active preparation-song Adelanto pill and the platform-wide launch logo entrance.

Active preview pill palette:
- The current-song preview pill must not appear neutral/gray while idle.
- Its idle background uses a restrained two-color gradient derived from the current card's extracted album palette.
- Primary idle gradient colors are --cover-c1 and --cover-c2, so every future active song automatically inherits colors appropriate to its own cover art.
- Default fallbacks remain within the established IPCDJ blue family: approximately rgb(55,93,202) and rgb(137,169,255).
- The border also inherits --cover-c2 at low opacity.
- Text, time, icon, and live meter remain high-contrast neutral light tones.

Playback progress fill:
- The existing non-seekable fill remains tied to --preview-progress.
- While playing, the fill becomes materially visible rather than nearly transparent.
- Fill colors use stronger versions of --cover-c1 and --cover-c2, with a restrained --cover-c3 tail for depth.
- The fill updates continuously with preview progress and reaches the full width of the pill at the end.
- The visual remains decorative/informational only; do not make the pill seekable.
- Keep the fill subtle enough that labels and meter remain legible.

Playing state:
- Do not replace the album-derived palette with a generic gray when playback begins.
- The playing pill continues using the same album palette with slightly stronger border/background intensity.

Launch logo fade:
- Preserve the completely fixed launch logo with opacity-only animation.
- Base platform fade-in duration is approximately 1.18 seconds.
- Mobile fade-in duration is approximately 1.28 seconds.
- Preserve cubic-bezier(.4,0,.2,1), matching the approved soft fade character.
- Do not add scale, translation, drift, bounce, or internal SVG animation.

Revert:
- backup-before-preview-palette-logo-v123 preserves the complete v122 state.

Preserve the v122 true overlapping audio crossfade, live analyser meter, remaining-time display, future top-right controls, and all v120-v119 launch reliability behavior.


## Cold-start launch fade and curated preview accent v124

v124 fixes the first-document launch fade and introduces an explicit contrasting accent system for the active preview pill.

Cold-start logo entrance:
- A single requestAnimationFrame is not sufficient to guarantee the launch-armed opacity:0 frame has actually been painted on a fresh document load.
- playLaunch() now sets launch-armed, forces layout through the logo stage, waits two nested requestAnimationFrame callbacks, and only then applies launch-playing.
- The transition therefore begins from a committed hidden logo frame on first install/cold start as well as warm standalone resumes.
- Preserve opacity-only animation; never add scale, translation, bounce, drift, or internal SVG animation.
- Base launch logo fade-in is approximately 1.32 seconds.
- Mobile launch logo fade-in is approximately 1.42 seconds.
- Preserve cubic-bezier(.4,0,.2,1).

Curated preview accent:
- Album-derived palette remains the fallback for songs without a curated preview accent.
- Songs may define previewAccent1 and previewAccent2 as RGB triplets for a deliberate contrasting player color that still belongs visually with the cover.
- The current card applies these values as --preview-accent-1 and --preview-accent-2.
- Dios De Milagros uses warm gold rgb(242,184,75) -> coral rgb(255,118,87), chosen as a strong complementary accent against the approved blue cover treatment.
- Idle pill uses a clearly visible low-to-medium intensity accent gradient and stronger accent border.
- Playback progress uses a high-visibility accent fill so left-to-right completion is obvious.
- Playing state keeps the same curated accent family with increased intensity.
- High-contrast light text/icon/meter remains unchanged.

Revert:
- backup-before-cold-fade-accent-v124 preserves the complete v123 state.

Preserve v122 true overlapping preview crossfade, analyser-driven live meter, remaining-time display, future top-right controls, and v119-v120 launch masking/readiness architecture.


## Strong preview contrast and fully-settled launch v125

v125 makes the active preparation player accent unmistakable and prevents the launch exit from interrupting the longer logo entrance.

Active preview contrast:
- Curated previewAccent1 and previewAccent2 values are written directly onto the current preview-pill element as --preview-accent-1 and --preview-accent-2.
- This avoids any ambiguity from card-level custom-property inheritance.
- For Dios De Milagros:
  - idle/base player color is warm gold rgb(242,184,75);
  - playback-progress fill color is coral rgb(255,118,87).
- Idle pill must visibly read as gold, not gray or blue:
  - stronger gold background opacity;
  - gold border;
  - gold-tinted Play/Pause circle.
- Played/filling portion must visibly read as coral and remain clearly distinguishable from the unplayed gold area.
- During playback the outer border shifts toward the coral accent.
- White label, timer, icon and meter remain legible above both accents.
- For songs without curated accents, album-derived cover colors remain the fallback.

Logo fade timing:
- Preserve the v124 double-animation-frame cold-start paint guarantee.
- Fade-in uses a slower, more gradual ease-in-out curve: cubic-bezier(.42,0,.58,1).
- Base fade duration is approximately 1.75 seconds with a .12-second delay.
- Mobile fade duration is approximately 1.90 seconds with the same .12-second delay.
- Minimum visible launch duration is increased to approximately 2.30 seconds so the fade-in can fully complete and briefly settle before exit.
- Hard maximum is approximately 3.90 seconds to keep launch bounded.
- The site transition must never begin simply because app content becomes ready before the logo entrance has completed.
- Preserve fixed-position, opacity-only logo behavior.

Revert:
- backup-before-player-contrast-fade-v125 preserves the complete v124 state.

Preserve v122 true overlapping Web Audio crossfade, analyser meter, timer, future top-right controls, and all v119-v120 masking/readiness protections.


## Preview completion dissolve v126

v126 changes only the natural-end visual reset of the active preparation preview pill.

Completion behavior:
- Do not visibly animate the playback fill width backward from 100% to 0%.
- When the preview reaches its natural end:
  - keep the progress fill visually at 100%;
  - show 0:00 momentarily;
  - fade the completed accent fill layer out over approximately .78 seconds using cubic-bezier(.4,0,.2,1);
  - reveal the existing idle/base gradient underneath.
- After the accent layer has fully dissolved, reset --preview-progress to 0% while that fill layer is still invisible.
- Restore the normal idle fill opacity only after the hidden reset has been committed across animation frames.
- Reset the displayed remaining time to the full preview duration after the dissolve/reset completes.

Interaction safety:
- If playback is restarted while a completion dissolve is pending, cancel the pending end timer and clear preview-ending / preview-resetting classes before playback begins.
- Manual pause behavior remains unchanged; this completion dissolve is for natural preview end only.
- Future-song circular controls are unaffected.

Revert:
- backup-before-preview-end-fade-v126 preserves the complete v125 state.

Preserve v125 gold/coral player contrast, v124/v125 launch behavior, v122 overlapping Web Audio crossfade, analyser meter, and all mobile hard-stop protections.


## Dynamic ambient palette, release lifecycle, and translation hardening v127

v127 is a broad architecture pass. Preserve all v126 preview-completion behavior, v125 launch behavior, and v122 Web Audio behavior unless explicitly superseded below.

Platform-wide preview smoothness:
- The active preview pill progress fill no longer animates width per frame.
- Progress uses a full-width pseudo-element with transform:scaleX() from a left transform-origin.
- JavaScript writes a normalized --preview-progress-scale from 0 to 1.
- Completion dissolve remains opacity-only while the fill is held at scaleX(1), then scale resets to 0 while hidden.
- This keeps the preview fill on transform/opacity compositing paths and avoids repeated layout work during playback.
- The natural-end coral-to-gold dissolve from v126 remains intact.
- prefers-reduced-motion continues to suppress non-essential meter/state animations.

Song-driven ambient background:
- The previous fixed global color cycle is replaced by a two-field song-driven ambient system.
- The selected ambient driver is the active preparation song with the nearest future release date.
- Songs in release or released state are ranked below still-preparing songs and do not drive the ambient background when another preparation song exists.
- If no still-preparing song exists, the current release/released song may remain the driver.
- The first three ambient colors come from the same extracted/cached artwork palette used by the current-song card.
- A fourth complementary color is generated from the dominant artwork color by rotating hue approximately 165 degrees and constraining saturation/lightness into a harmonious range.
- The four moving blobs use the four resulting colors simultaneously; individual drift/breathing remains continuous.
- Palette changes crossfade between two complete ambient fields over approximately 2.4 seconds rather than relying on custom-property color interpolation.
- The incoming field is configured while hidden, then fades in while the outgoing field fades out.
- After the crossfade completes, the outgoing field's blob animations are paused to reduce mobile GPU/battery cost.
- The standby field wakes before its next palette transition.
- Reduced-motion and reduced-data modes keep one static active field and disable blob movement.

Release lifecycle:
- Every scheduled song may define releaseDayStartAt, releaseAt, releaseDayEndAt, and introducedAt.
- Estreno state begins at 12:00 AM on the configured release date, not only at the service start time.
- Estreno lasts until the next midnight.
- At that next midnight, the song becomes "Ya estrenado".
- "Ya estrenado" remains in the preparation/current section for one full calendar day.
- At the following midnight, the song leaves the preparation section and moves into Introducciones recientes.
- Exact configured transitions:
  - Dios De Milagros: Estreno Sep 27 00:00 ET; Ya estrenado Sep 28 00:00 ET; Introducciones recientes Sep 29 00:00 ET.
  - Glorioso Día: Estreno Oct 25 00:00 ET; Ya estrenado Oct 26 00:00 ET; Introducciones recientes Oct 27 00:00 ET.
  - No Fallarás: Estreno Nov 8 00:00 ET; Ya estrenado Nov 9 00:00 ET; Introducciones recientes Nov 10 00:00 ET.
- These timestamps retain explicit Eastern offsets across the November DST boundary.
- Multiple preparation songs remain supported.
- Current cards sort unreleased/preparation songs first by nearest release date; release/released cards follow beneath them.
- Release cards use a gold Estreno treatment and dedicated banner.
- Released cards use a distinct green/teal "Ya estrenado" treatment and dedicated banner.
- Countdown/progress/timeline panels are hidden for release and released states so these cards read as completed milestones rather than active countdowns.
- State colors/borders transition smoothly; state banners animate in unless reduced-motion is enabled.
- Newly auto-introduced rows fade into Introducciones recientes unless reduced-motion is enabled.

Google/page-translation compatibility:
- Do not add a dependency on the legacy Google Website Translator Widget.
- The site must remain compatible with browser-native translation and Google Translate's website translation flow.
- Dynamic rendering must never use translated visible text as application state.
- setCardText stores the untranslated Spanish source in data-source-text.
- If the source value has not changed, the one-second renderer does not rewrite the visible text node, allowing a translation engine's translated DOM text to remain intact.
- When the underlying source value changes, the source text is updated and the translation engine may translate the new mutation normally.
- IPCDJ branding, song titles, and artist names use translate="no" plus notranslate so canonical music/entity names are not accidentally translated.
- Normal interface labels remain translatable.
- Translation-sensitive chips, dates, notes, timelines, recent rows, and current-state banners permit wrapping/expanded text instead of depending on English/Spanish fixed widths.
- Do not use innerText/textContent of translated labels to decide phases, song identity, playback ownership, dates, or selectors; continue using data attributes, IDs, configured timestamps, and internal state.

Revert:
- backup-before-dynamic-palette-states-v127 preserves the complete v126 state.


## Continuous cross-platform health monitoring v128

v128 adds a low-overhead in-page integrity monitor plus an external Playwright synthetic browser matrix.

In-page health monitor:
- Exposed as window.IPCDJ_HEALTH.
- getSnapshot()/checkNow() reports:
  - build identifier;
  - adaptive performance mode;
  - launch state;
  - current-card and preview-row counts;
  - disabled preview controls;
  - horizontal overflow;
  - same-origin resource failures;
  - service-worker control;
  - cumulative layout shift when supported;
  - latest Largest Contentful Paint when supported;
  - JavaScript error/unhandled-rejection counts;
  - Long Task and Long Animation Frame counts when the browser supports those entry types;
  - most recent sampled frame-time metrics.
- Global window error and unhandledrejection listeners record recent failures.
- Capturing resource-error listener distinguishes same-origin from optional external resources.
- ResizeObserver loop notifications are ignored because browsers can emit them without a site regression.
- PerformanceObserver entry types are feature-detected; unsupported metrics must never break or downgrade the site.

Sparse frame sampling:
- Monitoring must not itself create continuous requestAnimationFrame overhead.
- One startup sample runs after launch settles.
- Additional short samples occur after scrolling no more frequently than once every 30 seconds and after returning from background.
- Frame samples record median, p95, maximum frame interval, and ratio of frames over 50ms.
- A single slow sample does not alter the site.

Adaptive performance guard:
- Two consecutive severe samples may activate html.ipcdj-performance-lite.
- Lite mode changes only decorative ambient rendering:
  - reduce ambient blur cost;
  - pause b3/b4;
  - keep content, scrolling, countdowns, cards, controls and audio fully functional.
- Three healthy samples restore full ambient rendering.
- This guard is intentionally conservative to avoid reacting to momentary OS/browser scheduling noise.

Persistence:
- The latest health snapshot is stored locally under ipcdj-health-v1 for troubleshooting.
- No personal content, account data, location, or externally transmitted telemetry is collected by the in-page monitor.
- The site remains fully functional if localStorage, PerformanceObserver, or any optional performance API is unavailable.

Synthetic cross-platform health matrix:
- Monitoring package lives under monitoring/.
- @playwright/test is pinned to 1.63.0.
- Projects:
  - Chromium desktop;
  - Firefox desktop;
  - WebKit desktop;
  - Pixel 7 / Chromium mobile profile;
  - iPhone 15 / WebKit mobile profile;
  - WebKit touch/tablet profile at 1024x1366.
- Tests verify:
  - live document responds successfully;
  - build marker exists;
  - launch settles;
  - current song renders;
  - no same-origin resource errors, page errors or unhandled rejections;
  - no meaningful horizontal overflow;
  - scrolling remains within conservative frame-time thresholds;
  - preview playback can start;
  - a future preview can take ownership from the current preview;
  - translation-style text replacement is not overwritten by the one-second live renderer;
  - translated/expanded UI text does not create horizontal overflow.
- CI captures Playwright traces, screenshots, videos, console diagnostics and IPCDJ health snapshots on failures.

Automation:
- .github/workflows/site-health.yml runs on every push to main, manual dispatch, and every two hours at minute 23.
- Workflow installs Chromium, Firefox and WebKit and executes the complete project matrix against https://worship.ipcdj.org.
- Failed runs upload diagnostic artifacts for 14 days.
- A failed matrix creates or updates one open GitHub issue titled "IPCDJ Website Health Alert".
- A later fully passing matrix comments with recovery information and closes that issue.
- Concurrency cancels superseded health runs so rapid repository updates do not create overlapping test storms.

Limits:
- Synthetic WebKit/mobile emulation is a strong regression detector but is not identical to every physical iPhone/iPad hardware/OS combination.
- CI timing is noisier than real hardware; performance thresholds are intentionally conservative to detect severe regressions without turning normal runner variance into false alarms.
- The monitoring system increases confidence and catches regressions automatically; it does not constitute a literal guarantee that no browser/vendor bug can ever occur.

Revert:
- backup-before-health-monitor-v128 preserves the complete v127 state.


## Health-matrix calibration and audio compatibility v129

v129 calibrates the v128 monitoring system using evidence from the first real six-profile matrix run.

Audio compatibility hardening:
- Keep the preferred scheduled Web Audio curve envelopes where the browser accepts them.
- scheduleWebPreviewGain() now falls back to linearRampToValueAtTime if a browser rejects stricter setValueCurveAtTime scheduling.
- Crossfade outgoing/incoming GainNodes also have linear-ramp fallbacks.
- The preferred .68-second equal-power crossfade remains unchanged on browsers that accept the curve schedule.
- Preview playback/preparation failures dispatch ipcdj:preview-error with song id, stage and error message.
- The health monitor records previewErrors and exposes recentPreviewErrors in snapshots/persistence.
- Do not silently swallow a cross-browser preview-start failure.

Synthetic test calibration:
- Optional COV/MusicHoarders artwork-provider CORS/network errors remain diagnostic but are not treated as fatal site errors; artwork resolution already has fallback providers and curated palettes.
- Same-origin resource failures, JavaScript page errors, unhandled rejections, layout overflow and preview errors remain fatal signals.
- Launch settlement wait is extended to 20 seconds for headless WebKit runner throttling while still requiring the launch-active lock to clear.
- CI frame sampling is a gross-freeze detector, not an absolute FPS benchmark. Shared GitHub runners are not deterministic display hardware.
- Synthetic frame checks therefore require meaningful progress and reject catastrophic stalls, while real-device in-page adaptive sampling retains the stricter user-experience thresholds.
- CI worker count is reduced to 1 to avoid browser-engine contention falsely appearing as IPCDJ jank.
- Failure video capture is disabled to avoid ~250 MB diagnostic uploads; Playwright traces, screenshots, health JSON and console diagnostics remain retained.

First-run evidence:
- The first v128 workflow successfully installed Chromium, Firefox and WebKit, ran all six projects, uploaded diagnostics and created the health-alert issue.
- It exposed invalid minimum-frame assumptions on shared CI, optional third-party CORS noise, headless WebKit launch timing contention, and a Firefox preview-start signal.
- v129 addresses those issues rather than simply suppressing the entire monitor.

Revert:
- backup-before-health-calibration-v129 preserves the complete v128 state.


## Preview loudness normalization v130

v130 adds consistent automatic loudness matching to every scheduled Web Audio preview.

Normalization architecture:
- Every decoded preview buffer is analyzed before playback.
- Analysis is performed on the exact preview clip that will be heard, not blindly across the entire provider asset.
- Use gated 400 ms block RMS measurements so silence, quiet intros and tails do not cause a preview to be boosted excessively.
- Use the 70th-percentile active block as the representative program level.
- Target program level is approximately -14.5 dBFS RMS proxy.
- Automatic correction is normally limited to approximately +/-6 dB.
- A 0.97 peak ceiling always overrides upward gain if needed to preserve headroom and avoid normalization-created clipping.
- Silence/invalid-analysis fallback is unity gain.

Playback chain:
- AudioBufferSourceNode -> fixed normalization GainNode -> existing fade/crossfade GainNode -> analyser/output.
- Normalization gain is constant for the preview voice.
- Existing fade-in, fade-out and .68-second song-to-song crossfade remain independent and unchanged.
- Outgoing crossfade voices retain their own normalization node until disposal.
- Natural end, pause/reset, switching, mobile lock/background hard-stop and outgoing-voice cleanup disconnect normalization nodes correctly.

Scope:
- The current song pipeline uses Web Audio / Spotify preview assets, so current and future scheduled previews receive the same normalization system automatically.
- Do not normalize by arbitrary provider volume metadata; derive the correction from decoded PCM for consistency across providers.

Standards basis:
- AudioBuffer.getChannelData() is the canonical Web Audio path for PCM analysis.
- GainNode is the standard cross-browser amplitude stage.
- Avoid changing GainNode levels abruptly during active playback; v130 uses a fixed pre-play normalization gain and leaves timed fade automation on the existing envelope node.

Revert:
- backup-before-preview-normalization-v130 preserves the complete v129 state.


## Album-driven upcoming cards and circular preview countdown v131

v131 redesigns every song in the future/upcoming section using its own artwork palette and upgrades its compact preview control.

Artwork sourcing:
- COV / MusicHoarders remains the preferred high-resolution artwork resolver across Tidal, Spotify and Apple Music.
- Future cards use resolveFutureArtworkUrl(), which gives COV approximately 1.8 seconds to return before using a verified exact Spotify large-cover fallback.
- Verified Spotify fallback artwork:
  - Glorioso Día — https://i.scdn.co/image/ab67616d0000b27372bba4048e09a242595e4a2c
  - No Fallarás — https://i.scdn.co/image/ab67616d0000b273decf3d0f2c88d97720437f20
- Browser palette extraction/caching still refines the card when provider artwork is available.
- The existing curated COVER_THEME_FALLBACKS are applied synchronously so cards never flash as generic gray before asynchronous artwork/palette work finishes.

Upcoming-card palette:
- Each future card derives four background colors from the cover-art palette.
- The first three colors come from extracted/cached cover colors.
- The fourth uses the existing harmonious/complementary ambient-color generator.
- A separately tuned complementary --future-accent is generated for the preview ring, release chip and border.
- Accent luminance is constrained so it remains visible against the card.
- The palette is automatic for future pipeline entries; no song-specific CSS is required.

Upcoming-card background:
- Future cards use layered radial gradients built from --future-c1 through --future-c4.
- The visual should read as a soft blurred/mixed album-color field without displaying the album cover itself.
- Gradients are static layers rather than continuously animated filters, avoiding unnecessary per-frame GPU/paint cost.
- A dark translucent overlay preserves title/date/meta contrast.
- Card borders and release-date indicators inherit --future-accent.
- Text and metadata remain readable with translation expansion and mobile layouts.
- prefers-reduced-motion does not affect the static card palette.

Future preview control:
- Idle state remains a compact circular Play button at the upper-right of its corresponding card.
- When playback begins, the Play icon fades/scales out and a countdown interface fades/scales in inside the same fixed 48x48 footprint.
- Playback state shows:
  - remaining preview time;
  - circular SVG progress ring;
  - ring/accent color from the card's generated --future-accent.
- The control does not resize or move during the morph, preventing card layout shifts.
- The full control remains the Pause target while the countdown is visible.
- Pausing returns visually to Play while preserving the underlying elapsed position; resuming restores the ring from the preserved progress.
- Cross-song switching continues using the existing one-preview-at-a-time Web Audio ownership/crossfade behavior.
- v130 loudness normalization remains upstream of the fade/crossfade stage for all these future previews.

Circular progress implementation:
- SVG circle pathLength=100 is used for normalized progress.
- stroke-dasharray=100 and explicit JavaScript strokeDashoffset values represent playback completion.
- The ring starts at the top through a -90 degree SVG rotation.
- Progress updates from the existing shared requestAnimationFrame preview visual loop and remaining-time calculation.
- Direct strokeDashoffset writes are used instead of CSS calc() to minimize SVG/CSS arithmetic differences across Chromium, Firefox and WebKit.
- Ring updates transition linearly over .10 seconds so they visually track audio without stepping.
- SVG stroke dasharray/dashoffset are the standards-based cross-browser mechanism; no canvas or third-party rendering library is required.

Future natural-end behavior:
- At natural preview completion, the ring reaches 100% and the timer reaches 0:00.
- The active countdown state fades/scales back into the idle Play state over approximately .52 seconds.
- Ring/timer reset only after that end transition.
- A new playback start cancels any pending end-reset timer/state.
- Current preparation-song gold/coral Adelanto pill behavior from v126 remains unchanged.

Performance:
- Future gradient backgrounds use CSS gradients rather than canvas/video.
- The countdown morph uses opacity/transform.
- Progress uses an SVG stroke rather than geometry-changing layout properties.
- The fixed control footprint prevents reflow during playback.
- Reduced-motion disables the optional morph/ring transitions while preserving all state information.

Revert:
- backup-before-future-card-themes-v131 preserves the complete v130 state.

Preserve v130 loudness normalization, v129 audio compatibility diagnostics/fallbacks, v128 health monitoring, v127 song-driven ambient/release lifecycle/translation architecture, and all earlier launch/audio safety invariants.


## Future preview completion hold v132

v132 refines the upcoming-song circular preview control so its ending behavior exactly matches the intended visual sequence.

Clockwise progress:
- The future preview SVG ring continues to begin at 12 o'clock through a -90 degree rotation.
- Progress continues from 0 to 100 clockwise using the shared audio playback clock.
- The remaining-time countdown remains centered inside the ring.
- Play fades/scales out as the countdown/ring fades/scales in without changing the fixed control footprint.

Natural completion sequence:
- At natural preview completion the ring reaches a fully closed 100% circle and the timer reads 0:00.
- The complete ring/countdown remains fully visible for approximately 620 ms.
- After that hold, the entire completed ring/countdown state fades/scales out over approximately 560 ms while the Play state fades/scales back in.
- The ring must stay at 100% throughout the return fade.
- Only after the completed state is no longer visible may the ring reset to 0 and the timer reset to the full preview duration.
- Never animate the circular line backward.
- Never expose the hidden 100-to-0 reset to the user.

Interaction safety:
- Starting/resuming playback cancels pending future-complete/future-returning states and timers.
- The existing Pause target, normalized volume, song-to-song crossfade, mobile hard-stop and preview ownership rules remain unchanged.
- prefers-reduced-motion keeps the same state sequence without transitional motion.

Revert:
- backup-before-future-preview-finish-v132 preserves the complete v131 state.


## Dormant push notification foundation v133

v133 lays down the architecture for a future platform-wide Web Push notification system without activating any notification behavior in the live website.

Runtime isolation:
- Nothing under notifications/ is imported by index.html.
- sw.js does not import notifications/sw-foundation.js.
- No notification permission prompt exists.
- No PushManager.subscribe() call is executed.
- No push backend is contacted.
- No new service-worker push or notificationclick handler is active.
- No VAPID key is present in the live website.
- Build marker and service-worker cache remain at v132 because runtime behavior is intentionally unchanged.
- The notification groundwork must remain dormant until a future explicit implementation request activates a stage.

Standards-based platform model:
- Future notification transport must use the standards-based Push API, Notifications API and existing Service Worker.
- Use feature detection instead of browser-name detection.
- Notification permission/subscription must be initiated only after direct user action.
- Persistent/mobile notifications must be displayed from the service worker with ServiceWorkerRegistration.showNotification().
- iPhone/iPad support should target the installed/Home Screen web-app flow while retaining the same standards-based transport for other supporting platforms.
- Do not depend on browser timers, setTimeout, page visibility or Periodic Background Sync for scheduled ministry notifications.
- Server-side scheduling is authoritative.

Foundation files:
- notifications/README.md — architecture, staging and intentionally undecided product rules.
- notifications/notification-foundation.js — side-effect-free client capability/subscription helpers.
- notifications/sw-foundation.js — dormant service-worker payload and click-routing helpers.
- notifications/notification-contract.schema.json — version-1 push payload schema.
- notifications/event-catalog.json — draft extensible event taxonomy/preferences with enabled:false.
- notifications/backend-contract.md — vendor-neutral secure backend/subscription/scheduler contract.

Draft notification categories:
- song_phases
- estreno
- live_set
- announcements

Draft event types:
- song.phase.entered
- song.release.reminder
- song.release.today
- live_set.published
- live_set.updated
- system.announcement

All categories default disabled in the foundation. The catalog is a vocabulary/contract, not an activation schedule.

Canonical scheduling:
- Future push timing must come from a server-side scheduler using the same versioned canonical event/song schedule as the website renderer.
- Church/song scheduling timezone is America/New_York.
- Every generated notification event must have an idempotency/deduplication key.
- The server must never infer notification state from translated DOM text or a user's local browser timer.
- Live Set notifications should ultimately be driven by explicit publish/update revisions, not by scraping whether a tab happens to be visible.

Subscription/privacy model:
- A notification subscription should not require name, email, phone number or account merely to receive ministry notifications.
- Store an anonymous installation id plus PushSubscription endpoint/keys, category preferences, locale/timezone and operational timestamps.
- Treat push endpoints and encryption keys as secrets/capability URLs.
- VAPID private key and backend/database secrets must never be embedded in the website repository/runtime.
- Remove permanently invalid subscriptions when the push service reports them gone.
- Preferences should be updatable without forcing the user to create a new push subscription.

Future activation sequence:
1. Add a user-facing Notifications settings surface and support/install-state guidance.
2. Deploy secure backend API + storage + VAPID.
3. Activate sw.js push / notificationclick handlers using the dormant foundation.
4. Connect canonical song/Live Set events to the server scheduler.
5. Enable only notification scenarios/wording/timing explicitly approved later.

Deliberately unresolved until future product decisions:
- exact phase events that notify;
- reminder lead times;
- quiet hours;
- repeat rules;
- per-song overrides;
- Live Set publication/update policy;
- manual admin announcements;
- badge-count semantics;
- notification wording;
- default category choices.

Preview verification:
- The health matrix now explicitly verifies that future preview controls contain the countdown/ring and that the SVG ring advances once the future preview takes playback ownership.
- The cross-browser scroll sweep was moved out of in-page requestAnimationFrame loops because headless WebKit can throttle rAF independently of actual scroll health.
- These monitoring changes do not alter website runtime behavior.

Revert:
- backup-before-notification-foundation-v133 preserves the complete v132 website state before notification groundwork and monitoring-test changes.


## Cross-platform sRGB vibrancy consistency v134

v134 hardens the album-derived upcoming-song card colors so the intended palette remains as consistent and vibrant as practical across Chromium, Firefox, WebKit/Safari, Android, desktop and installed PWA rendering.

Scope:
- No preview playback logic or future-preview countdown/ring behavior changes in v134.
- No notification foundation activation.
- This is a color extraction/rendering consistency pass only.

Color-space policy:
- Future-card theme colors are normalized to explicit 8-bit sRGB integer triplets before being written to CSS custom properties.
- CSS rendering continues to use rgb()/rgba() only for these dynamic card colors.
- Do not use display-p3, lab(), lch(), oklab(), oklch(), color-mix(), mix-blend-mode or browser-specific wide-gamut values for the canonical upcoming-card palette.
- Wide-gamut devices may physically display sRGB differently/better, but the CSS source values and compositing intent remain deterministic.

Palette extraction:
- The palette canvas explicitly requests a 2D sRGB context when the browser supports the colorSpace option.
- Browsers that do not support the option fall back to the established standard 2D context without failing.
- Extracted colorful values pass through normalizeVibrantSrgbColor().
- Saturation receives a restrained lift and bounded lightness so the palette does not look washed out after dark-theme compositing.
- Near-neutral/grayscale colors below the saturation threshold stay neutral; never invent a hue for grayscale artwork.
- Existing cached/fallback palettes are also normalized before future-card CSS variables are generated.

Rendering/compositing:
- Upcoming cards now have an explicit #0a0d14 base instead of a semi-transparent base layer.
- The four album-derived radial-gradient colors remain the same semantic palette, but their alpha levels are raised modestly to retain visible vibrancy.
- The dark readability overlay is reduced slightly so it does not unnecessarily mute the palette.
- Gradient layers remain plain standards-based radial/linear gradients with no filter blur, backdrop dependency or blend mode.
- Static gradient rendering remains preferred over animated filters for consistency and GPU efficiency.

Accessibility/readability:
- White title/metadata treatment and text shadows remain unchanged.
- Accent borders/date indicators remain derived from the normalized palette.
- Do not disable user accessibility color/contrast modes merely to force visual fidelity.

Physical-display limitation:
- Exact emitted color cannot be literally identical across different display panels, calibration, brightness, HDR/wide-gamut capabilities or OS color management.
- IPCDJ guarantees the same normalized sRGB source values and rendering architecture, not identical physical photons across hardware.

Revert:
- backup-before-srgb-vibrancy-v134 preserves the complete v132 runtime before this color consistency pass.

## Future preview hydration integrity v135

The upcoming-song preview control is a persistent composite control, not a disposable Play icon.

Required behavior:
- Hydration must preserve the complete `.future-preview-button` DOM shell, including `.future-preview-idle`, `.future-preview-active`, the SVG ring, ring progress circle, and countdown.
- Never replace the entire future preview button `innerHTML` during hydration, preparation, play/pause transitions, or recovery. Update only the dedicated `.preview-icon-slot` when an icon refresh is needed.
- On playback start, Play crossfades out while the countdown and clockwise progress ring crossfade in together.
- The ring begins at 12 o'clock, advances with actual preview elapsed time, and reaches 100% at the same moment the countdown reaches `0:00`.
- At natural completion, the complete ring/countdown state remains briefly readable, then both fade away while Play returns; the hidden ring may reset only after it is invisible.
- Automated health coverage must verify that the countdown and ring still exist after hydration, not merely in the initial HTML template.

## macOS desktop scroll compositor guard v135

Desktop macOS receives a scroll-only compositor guard for smoothness on older Intel iMac-class hardware while preserving the approved visual identity at rest.

Required behavior:
- Detect desktop macOS without misclassifying iPadOS devices that report Macintosh.
- Only while active scrolling, pause decorative ambient blob animation and bypass expensive backdrop-filter sampling on the main glass surfaces.
- Do not remove, recolor, flatten, or replace the ambient palette; the exact current palette remains visible while scrolling.
- Restore the complete ambient animation and glass blur automatically shortly after scrolling settles.
- The optimization must not alter song lifecycle, countdown timing, preview audio, preview progress, launch behavior, translation, keyboard/input behavior, or PWA freshness.
- Do not use permanent low-quality rendering merely because the platform is macOS; this is a transient scroll-path optimization.

## Preview finish polish v136

Upcoming-song circular preview:
- The animated progress stroke must occupy the same outer circumference as the existing 48 px circular Play-button border, visually riding on/over that border rather than appearing as a smaller inner ring.
- The progress ring may extend approximately 1 px outside the button box so its stroke remains crisp and fully visible.
- It still begins at 12 o'clock, advances clockwise from 0 to 100, and finishes exactly with the countdown reaching 0:00.
- The countdown remains centered inside the circular button and the completed ring/countdown state fades back to Play together.

Current-preparation horizontal preview:
- At natural preview completion, the analyser bars must fade out smoothly rather than visibly snapping to their idle height.
- The 0:00 timer must fade out before its text is reset to the full preview duration.
- Reset analyser levels, timer text, and progress position only while those reset-sensitive elements are invisible.
- After the hidden reset, the analyser and timer may fade back into their calm idle presentation.
- Preserve the existing coral-to-gold progress finish, Web Audio normalization, equal-power song switching, pause/resume behavior, and mobile background hard-stop.

## Exact border-owned future preview ring v137

The circular upcoming-song preview progress is not a second ring around the Play button. The SVG ring owns the button outline itself.

Required behavior:
- The 48 px future preview button keeps a transparent CSS border for sizing only.
- A permanent 48 x 48 SVG track is the visible circular outline in idle, playback, completion, and return states.
- The SVG track and progress circle share the exact same center, radius, and stroke geometry. The animated progress stroke must overlay that track, never occupy a larger or smaller circumference.
- Canonical geometry is viewBox 0 0 48 48, center 24/24, radius 23.4, stroke width 1.2. This keeps the stroke inside the same 48 px button edge without creating an outer halo/ring.
- Use SVG pathLength=100 with numeric stroke-dasharray/stroke-dashoffset values so elapsed playback maps directly to 0-100 progress consistently across current Safari/WebKit, Chromium, and Firefox.
- Idle shows the neutral outline and Play icon. Playback fades Play to the centered countdown while the progress stroke draws clockwise from 12 o'clock over the outline itself.
- At 100% / 0:00, hold the complete progress briefly, then fade the progress stroke and countdown while Play returns, revealing the neutral outline underneath.
- Do not reintroduce an oversized SVG, negative inset, duplicated CSS border, conic-gradient border, or a separate outer progress circumference.

## Future preview ring cascade integrity v138

Root cause fixed in v138:
- The site-wide icon rule `.preview-button svg { width:17px; height:17px }` has specificity 0-1-1.
- A plain `.future-preview-ring` selector has specificity 0-1-0, so the generic icon rule wins for width/height even when it appears earlier in the stylesheet.
- This caused the progress SVG to render as a 17 x 17 circle at the upper-left of the 48 px dark Play button, matching the production screenshot.

Permanent rule:
- Size the progress SVG with `.future-preview-button > svg.future-preview-ring`, which is more specific than the generic icon selector.
- The ring uses width:100% and height:100% so it exactly follows the dark Play button at 48 px desktop and 42 px small-mobile sizes.
- Never hard-code a separate outer ring size.
- The neutral SVG track remains the visible border; the progress stroke overlays the exact same path during playback and fades at completion.
- Automated health checks must compare the SVG and button bounding rectangles so this cascade regression is caught.

## Future preview completion crossfade v139

At natural completion of an upcoming-song circular preview:
- Hold the fully completed progress ring and 0:00 state briefly so completion reads intentionally.
- Then crossfade back to idle as one coordinated transition rather than resetting individual elements abruptly.
- Progress ring opacity fades over roughly 0.68 s.
- Countdown/active layer fades and settles with only a subtle scale change.
- Neutral border stroke eases back to its idle opacity at the same time.
- The dark button surface and playback glow ease back to the idle surface instead of snapping at cleanup.
- The Play icon begins slightly after the completed state starts dissolving, producing a layered crossfade instead of a simultaneous pop.
- Do not reset stroke-dashoffset or countdown text until the completed layer is fully invisible and the Play return has finished.
- Cleanup timing must remain longer than all return transition durations.

## Slow future preview return v140

The natural-completion return for future-song circular previews should feel intentionally slow and fluid rather than quick:
- Hold the completed 100% ring / 0:00 state for about 0.62 s.
- Fade the completed progress ring over about 1.40 s.
- Fade the countdown/active layer over about 1.28 s with only a very subtle scale settle.
- Ease the neutral outline and button surface back over about 1.30 s.
- Bring the Play icon back over about 1.18 s with an approximately 0.22 s delay so it emerges behind the dissolving completed state.
- Keep the cleanup/reset delay longer than every visual transition (about 1.72 s after return begins).
- Never expose the internal reset of timer text or ring dash position.

## Continuous stability system v141

v141 audits and hardens the existing v128-v140 monitoring architecture without changing production UI/audio behavior.

Operating model:
- The external health workflow runs every hour at minute 17, on every push to main, and by manual dispatch.
- Push-triggered checks wait until the build marker in the deployed GitHub Pages shell matches the repository build marker before executing the browser matrix. This prevents a valid new commit from being judged against an older Pages deployment.
- The browser matrix covers Chromium desktop, Firefox desktop, WebKit desktop, Chromium mobile, iPhone-class WebKit mobile, 320 x 568 compact WebKit mobile, and WebKit tablet.
- Linux CI starts a PulseAudio backend before browser tests so Firefox Web Audio is not judged in an environment with no audio server.
- Playwright browser/media limitations remain distinct from production-browser failures; diagnostic data must preserve enough context to distinguish them.

Monitoring calibration:
- WebKit CI frame sampling is a catastrophic-freeze detector only. Shared/headless WebKit may throttle rAF independently of actual Safari scrolling, so its ceiling is intentionally loose while real-device IPCDJ_HEALTH remains stricter.
- Non-WebKit CI retains the tighter frame interval and >50 ms ratio guardrails.
- Future-preview ring validation checks concentric center alignment and the intentional one-pixel transparent-border inset instead of requiring the SVG padding box to equal the outer border box.
- The approved production geometry must never be changed merely to satisfy an incorrect synthetic assertion.

Expanded integrity/efficiency checks:
- Manifest is fetched and validated for canonical id/start_url/scope/display/colors.
- Every manifest icon must return successfully.
- sw.js must load successfully and contain a versioned IPCDJ cache.
- A live service-worker registration must become active.
- Duplicate DOM IDs, horizontal overflow, same-origin resource errors, JavaScript errors, unhandled rejections, and preview errors remain fatal.
- Coarse runaway budgets protect against accidental DOM/resource explosions without pretending CI network timing is a real-device benchmark.
- Health snapshots retain long-task, long-animation-frame, CLS, LCP, resource-count, and DOM-count diagnostics for analysis.

Safe self-recovery:
- Real devices continue using the in-page adaptive performance guard: two severe samples may enter ipcdj-performance-lite; three healthy samples restore full decoration.
- The service worker continues network-first freshness with last-known-good fallback and cache cleanup.
- Playwright retries transient test failures and GitHub automatically closes the health-alert issue after a later fully passing matrix.
- The monitoring system must NOT autonomously rewrite production source code or roll back a deployment merely because CI fails. Automatic code mutation can turn provider outages, runner noise, or a bad assertion into a production regression. Source fixes remain evidence-driven; only bounded runtime degradation/recovery is automatic.
- Monitoring should diagnose, isolate, and surface a reproducible failure with artifacts so a source change can be made safely.

Coverage limit:
- Synthetic browser projects provide broad engine/device regression coverage, not a literal guarantee for every hardware/OS/browser combination. Physical-device reports remain authoritative evidence when synthetic behavior conflicts with an observed real device.

## Watchdog co-development contract v142

This is a permanent development rule for IPCDJ Worship.

Canonical policy:
- `monitoring/WATCHDOG_POLICY.md` is the detailed watchdog co-development contract.
- `SITE_STANDARDS.md` and the watchdog policy must be read before substantive runtime changes.
- The health workflow validates that the policy and this standards marker remain present before running the matrix.

Feature-development requirement:
- Every substantive new runtime feature or behavior must receive an explicit watchdog disposition before it is considered complete.
- Allowed dispositions are:
  - `FEATURE_COVERAGE_ADDED` when the new feature has behavior/state that existing broad checks cannot understand;
  - `GENERIC_COVERAGE_SUFFICIENT` when existing global watchdog coverage already detects the realistic failure modes.
- New interaction/state machines, audio/media behavior, network/provider dependencies, PWA/lifecycle behavior, persistence/sync, browser-specific logic, exact timed sequences, or complex responsive geometry normally require dedicated feature coverage.
- Simple content/copy/artwork changes using an already-tested renderer usually rely on generic coverage unless they introduce new runtime behavior.

Mandatory implementation reporting:
- Every substantive website implementation response must explicitly tell the user the watchdog status.
- Use one of:
  - `Watchdog: FEATURE_COVERAGE_ADDED — ...`
  - `Watchdog: GENERIC_COVERAGE_SUFFICIENT — ...`
  - `Watchdog: PENDING — ...`
- If the final health run is still queued or running, do not call watchdog verification complete.
- After a final run completes, report pass/fail and distinguish production regressions from external-provider or CI/test-calibration failures when evidence allows.

Development integrity:
- Dedicated watchdog coverage must ship in the same change set as the feature it protects whenever practical.
- Never alter valid production behavior solely to satisfy an incorrect synthetic assertion; calibrate the test to the intended behavior.
- The watchdog may automatically degrade/recover bounded decorative performance behavior, retry tests, use service-worker fallbacks, capture diagnostics, and manage the health-alert issue.
- It must not autonomously rewrite production source code or roll back a deployment solely because a synthetic test fails.

Verification baseline:
- The complete v141 seven-profile health system passed its first final end-to-end run on 2026-09-21 after deployment-aware waiting, Firefox audio-backend setup, WebKit calibration, compact-mobile coverage, and PWA/efficiency checks were added.

## Primary tabs, timed events, and vivid preparation progression v143

Navigation:
- The existing landing page remains the default Inicio panel with its established content and behavior unchanged.
- A persistent primary tablist sits below the hero with Inicio and Worship semanal.
- Tabs follow the WAI-ARIA tab pattern: role=tablist/tab/tabpanel, aria-controls, aria-selected, roving tabindex, and automatic Left/Right/Home/End keyboard activation.
- Panel switching is local and instant; there is no route reload, duplicate app boot, or extra network dependency.
- Panel entrance uses a short opacity/translate transition and is disabled under prefers-reduced-motion.

Worship semanal:
- The panel is currently a coming-soon placeholder.
- Its purpose text explicitly states that weekly Friday and Sunday worship sets will live there with repertoire, order, and service instructions.
- Future implementation should populate this panel without disturbing Inicio.

Special-event tabs:
- SPECIAL_EVENT_TABS is the data-driven source for temporary event tabs.
- Campaña GU 2026 is currently configured as the active special event.
- Its placeholder explains that the panel will hold worship repertoire, order, musicians, and team instructions for the October 9–11 event.
- hideAt is 2026-10-12T00:00:00-04:00, so the tab and panel disappear automatically at midnight immediately after Sunday October 11.
- Special-event visibility is synchronized from the existing server-calibrated live clock. If an expiring special-event panel is active, navigation falls safely back to Inicio.
- Future special events should be added to SPECIAL_EVENT_TABS with their own key, label, content, and hideAt timestamp.

Preparation-stage color language:
- Semantic progression is intentionally more vivid while retaining text labels so status is never communicated by color alone.
- Learning begins vivid red/coral.
- It moves through orange into amber for final preparation.
- It transitions into fresh green as estreno approaches.
- Estreno itself is green, completing the red-to-green readiness metaphor instead of returning to gold.
- Timeline cards use stable semantic colors: Aprendizaje red, Preparación final amber, Estreno green.
- Active timeline/status/progress treatments use stronger soft fills, borders, and restrained glows while keeping the dark IPCDJ visual system.

Watchdog:
- Disposition: FEATURE_COVERAGE_ADDED.
- The matrix validates default Inicio state, weekly-tab content, keyboard tab navigation, Campaña GU synthetic pre-expiry visibility, exact midnight removal, fallback to Inicio, and distinct red/amber/green timeline colors.
- Generic overflow/error/PWA/performance coverage continues to apply platform-wide.

## Semantic timeline cascade correction v144

- Removed the older album-palette background rule whose higher specificity could override the new semantic non-active timeline backgrounds.
- Aprendizaje, Preparación final, and Estreno cards now consistently own distinct red, amber, and green background treatments as intended.
- The v143 feature watchdog now verifies both semantic border colors and distinct stage-card background images across the browser matrix.
- All v143 tab, event-expiry, accessibility, status/progress, and navigation behavior remains unchanged.

## Clean tab navigation and single-phase illumination v145

Tabs:
- Primary navigation is visually reduced to a clean text-tab row with one subtle active underline.
- Removed the heavy segmented-control container, filled active pill, large shadows, and panel entrance animation.
- Switching Inicio / Worship semanal / special-event tabs is immediate: no panel fade/translate and no replay of the IPCDJ launch sequence.
- Internal tab switches mark a short local-navigation window; the standalone launch blur/focus handlers ignore that local switch while still responding normally to real app background/foreground lifecycle events.
- ARIA tab semantics and keyboard navigation remain unchanged.

Preparation progression:
- The moving Camino al estreno bar remains the owner of the vivid red→orange→amber→green progression.
- Timeline phase cards are neutral by default.
- Only the phase that is actually current receives the illuminated selected treatment using the live stage color.
- Aprendizaje illuminates only during Aprendizaje.
- Preparación final illuminates only during Preparación final.
- Estreno is revealed and illuminated on the release phase; the release timeline is no longer hidden on release day.
- Inactive phase cards have no glow and reduced opacity, so future/past phases do not compete visually.
- The Estreno dot is muted when inactive and glows only when Estreno is active.

Watchdog:
- Disposition: FEATURE_COVERAGE_ADDED.
- Tab tests now verify that local tab changes leave the launch overlay state unchanged and do not add a panel-enter animation.
- Phase tests verify at most one active illuminated phase, correct phase-to-card mapping, no inactive glow, reduced inactive emphasis, and visible Estreno timeline during the release phase.

## iOS tab launch root fix and restrained Estreno date v146

Internal navigation / launch separation:
- The v145 click-time guard was too late for iOS standalone mode because a blur/focus pair can occur before the click handler.
- The launch subsystem now captures pointerdown, touchstart, and mousedown on .site-tab before focus changes and marks a short internal-navigation window.
- Blur/focus launch handlers ignore that internal window.
- activateSiteTab also dispatches ipcdj:internalnavigation. If a platform somehow armed the launch overlay before the click, the launch subsystem synchronously cancels that accidental armed state before a frame can paint.
- Real visibilitychange, pagehide, and genuine app background/foreground behavior remain intact.

Estreno visibility:
- Inactive phase cards remain neutral and non-glowing.
- When Estreno is not current, only its date and small dot receive a restrained warm-gold cue so the target date is easy to locate.
- The inactive Estreno card itself does not receive the active-phase glow, border, or selected treatment.
- When Estreno becomes the actual phase, the normal active green stage treatment takes ownership.

Watchdog:
- Disposition: FEATURE_COVERAGE_ADDED.
- The tab test now reproduces pointerdown -> synthetic blur -> click and verifies the launch overlay remains idle.
- The phase test continues enforcing one active illuminated phase and no inactive-card glow, while also checking the inactive Estreno date remains visually distinct.

## Confirmed-background launch authority v147

Root cause:
- iOS standalone mode may emit window blur/focus while the document remains visible after a full scroll cycle.
- v146 still allowed a visible blur to arm the launch overlay before later tab interaction, which could replay the intro even though the app never left the foreground.

Permanent launch rule:
- window blur is no longer authoritative for background detection.
- A blur only starts a short observation timer; it may arm the launch sequence only if document.hidden becomes true.
- visibilitychange / webkitvisibilitychange with document.hidden=true and pagehide are authoritative background signals.
- Resume playback occurs only when a background transition was explicitly confirmed.
- A visible blur followed by focus, scrolling, keyboard/focus changes, or internal navigation must never arm or replay the intro.
- Internal navigation clears any pending blur observation.

Watchdog:
- Disposition: FEATURE_COVERAGE_ADDED.
- A dedicated standalone-mode regression test now performs full scroll bottom -> top, injects visible blur/focus, then switches to Worship semanal and Campaña GU.
- The test asserts launch-idle and absence of ipcdj-launch-active throughout the sequence.

## Tab visibility polish v148

- Kept the v145-v147 clean underline navigation model and all existing no-animation behavior.
- Increased inactive tab legibility slightly through brighter text and modestly stronger weight.
- Added only a very faint shared strip background/top edge so the navigation reads as an intentional section without returning to a bulky segmented control.
- The active tab now uses a slightly thicker blue gradient underline, restrained glow, and faint background wash.
- The special-event indicator is marginally larger/brighter while remaining subtle.
- No tab-switch, launch, lifecycle, event-expiry, or accessibility behavior changed.

Watchdog:
- Disposition: GENERIC_COVERAGE_SUFFICIENT.
- This is CSS-only visual emphasis. Existing cross-platform layout, overflow, tab interaction, launch-regression, reduced-motion, and responsive coverage already protect the realistic failure modes.

## Top navigation dock v149

- Primary section tabs moved above the IPCDJ Worship hero so navigation is the first application control in the shell.
- The nav is sticky near the safe top edge, keeping Inicio / Worship semanal / active special-event access available during long scrolling.
- Styling remains compact and clean: dark high-opacity dock, subtle border/shadow, small gaps, and a restrained selected-tab blue surface plus underline.
- No backdrop-filter is used on the sticky dock, avoiding extra compositor cost while scrolling.
- Existing ARIA tab semantics, keyboard behavior, no-panel-animation rule, confirmed-background launch rules, and special-event lifecycle remain unchanged.
- Compact and tiny-screen rules preserve three-tab fit when Campaña GU is present.

Watchdog:
- Disposition: FEATURE_COVERAGE_ADDED.
- Primary-tab coverage now verifies the nav precedes the hero and computes as sticky.
- The standalone full-scroll regression also verifies the navigation remains visible at the bottom of the page before returning to the top and switching tabs.

## Professional static top tabs v150

- Replaced the v149 sticky/floating dock with a static top navigation bar to eliminate visual instability and safe-area/sticky compositing artifacts.
- Navigation remains above the hero as the first application control.
- The container is one restrained dark surface with a single border and shadow.
- Tabs use equal-width CSS grid columns, one simple selected surface, and no animated underline.
- Removed the selected underline/glow stack and sticky offset entirely.
- Labels may wrap naturally instead of squeezing or overflowing; <=340px receives a small type/indicator reduction.
- Existing no-panel-animation, confirmed-background launch behavior, special-event lifecycle, ARIA semantics, and keyboard navigation remain unchanged.

Watchdog:
- Disposition: FEATURE_COVERAGE_ADDED.
- Primary navigation coverage now checks that tabs are top-level, non-sticky, equal width/equal height, and contained within the viewport across the browser/device matrix.
- The existing full-scroll launch regression remains in place without requiring navigation to float during scrolling.

