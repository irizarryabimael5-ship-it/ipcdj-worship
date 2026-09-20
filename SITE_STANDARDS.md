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
