# IPCDJ Worship — Site Standards

These are protected implementation standards for all future changes to the IPCDJ Worship website.

## Core invariant

Every future change must preserve the existing visual identity, responsive behavior, current-song countdown, calibrated time source, progress bar, automatic phase transitions, automatic Monday rollover, upcoming-song rendering, introduced-song history, pull-to-refresh behavior, PWA behavior, and custom-domain operation unless a change is explicitly requested.

Adding or editing a song must not require manually redesigning or rebuilding the page state. Song lifecycle changes are date-driven from the song pipeline.

## Canonical domain

Primary public URL: https://worship.ipcdj.org/

The GitHub Pages URL remains a technical hosting fallback. Canonical, Open Graph, and other public-facing metadata should use the worship.ipcdj.org hostname.

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

The visual aesthetic is a protected system: dark blue/black animated background, blue identity accents, green progress/completed states, red estreno states, white estreno text, glass cards, responsive typography and existing spacing/radius hierarchy.
