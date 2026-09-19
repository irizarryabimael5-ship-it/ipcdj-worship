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
