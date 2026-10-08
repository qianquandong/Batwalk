# BATWALK UI REDESIGN — IMPLEMENTATION TASK LIST

## Goal

Upgrade the existing Batwalk Apple Watch + iPhone app from the current prototype-looking UI to the approved premium visual direction shown in the attached design boards.

This is an IMPLEMENTATION task, not a design exploration task.

Use the attached approved design boards as the source of truth.

Do not invent a different visual style.

Do not change the game rules or product scope.

Do not add AI.

Primary priority:
APPLE WATCH FIRST.

Then bring the iPhone companion app into the same design system.

==================================================
P0 — INSPECT CURRENT CODEBASE
==================================================

Before editing:

1. Inspect the complete SwiftUI project structure.

2. Identify:
- watchOS app entry point
- iOS app entry point
- Home screen
- Progress screen
- Friendship / Care screen
- Collection screen
- Settings screen
- Hatch / Egg screens
- Batpedia screen
- History screen
- Unlock / Purchase screen
- shared game models
- HealthKit logic
- WatchConnectivity logic
- image / sprite assets

3. Do NOT rewrite working business logic unless necessary.

4. Create a short implementation map:

CURRENT FILE
→ SCREEN
→ WHAT WILL CHANGE

Then begin implementation.

==================================================
P1 — CREATE SHARED DESIGN SYSTEM
==================================================

Do this BEFORE styling screens individually.

Create a reusable Batwalk design system.

Suggested structure:

DesignSystem/
    BatwalkColors.swift
    BatwalkTypography.swift
    BatwalkSpacing.swift
    BatwalkMotion.swift
    BatwalkCardStyle.swift
    BatwalkButtonStyle.swift

Use names appropriate to the existing project if structure differs.

------------------------------
COLOR TOKENS
------------------------------

Create semantic colors instead of scattering hex values.

Suggested tokens:

deepNight
nightSurface
nightCard
nightCardElevated

indigo
purpleGlow
pinkAccent

moonlight
softLavender

textPrimaryDark
textSecondaryDark

textPrimaryLight
textSecondaryLight

lockedBatBackground

rarityCommon
rarityUncommon
rarityRare
rarityLegendary
rarityShiny

Do NOT use random per-screen colors.

------------------------------
GRADIENTS
------------------------------

Reusable gradients:

batwalkPrimaryGradient
progressGradient
buttonGradient
hatchGlowGradient
nightBackgroundGradient

Purple → Pink should be the main interactive gradient.

Do not overuse gradients for all surfaces.

------------------------------
SPACING
------------------------------

Use an 8pt-based layout system.

Suggested:

xs = 4
sm = 8
md = 12
lg = 16
xl = 24

Watch screens should generally use:
8–12pt spacing.

------------------------------
CARD STYLE
------------------------------

Create reusable dark glass card style:

- very dark indigo / navy
- subtle translucent surface
- 1px soft border
- small inner highlight
- rounded corners
- restrained blur
- no excessive shadow

Potential component:

BatwalkGlassCard

------------------------------
BUTTON STYLE
------------------------------

Create:

BatwalkPrimaryButtonStyle

Appearance:
- purple/pink gradient
- rounded pill / rounded rectangle
- strong readable label
- small soft glow
- minimum 44pt interaction height where possible

Press animation:
scale 1.0 → 0.96
~0.12 sec easeOut

Release:
0.96 → 1.0
spring / easeOut

==================================================
P2 — APPLE WATCH REDESIGN
==================================================

The Watch experience is the core product.

Do not make it look like a Health dashboard.

The BAT should be the most important visual element.

--------------------------------------------------
TASK 2.1 — HOME SCREEN
--------------------------------------------------

CURRENT:
Plain black screen with bat + name + steps.

TARGET:
Match approved Home concept.

Required hierarchy:

TOP:
small Batwalk label OR minimal contextual header

CENTER:
large current Bat artwork

BACKGROUND:
dark moonlit atmospheric environment

Do not use a flat black background.

Use:
- dark blue / indigo base
- subtle stars
- moon / forest / cave elements if existing assets permit

BOTTOM:

Bat name

Example:
Mochi Bat

Then one premium progress pill:

[egg icon] 961 steps to hatch

or when no egg is active:
Friendship / status context

Requirements:

- Bat occupies roughly 40–55% of usable screen height
- avoid excessive text
- remove prototype-looking UI
- keep everything glanceable

Interaction:

Tap bat:
small happy reaction

Long press:
optional only if existing navigation needs it

Animation:

Idle Float:
bat moves approximately 2–3px vertically

Animation duration:
~2.4 sec

Curve:
.easeInOut

Repeat:
autoreverse forever

Wing / body movement:
extremely subtle

Ear twitch:
random every approximately 6–10 sec if technically clean

Do NOT continuously run expensive particle systems.

--------------------------------------------------
TASK 2.2 — PROGRESS SCREEN
--------------------------------------------------

Replace current text-heavy screen.

TARGET STRUCTURE:

Large glowing circular progress ring.

CENTER:
61%

BELOW:
961 steps to hatch

Then two stat cards:

Walking icon
Today
3,539

Fruit icon
Fruit
0

Do NOT display instructional Health permission paragraphs during normal gameplay.

Health troubleshooting text belongs in Settings / error state.

Progress ring:

purple → pink gradient

Background track:
low-opacity dark purple

Ring animate when screen opens:
progress smoothly fills from previous value

Duration:
0.6–0.9 sec

Progress pulse:

scale approximately:
1.0 → 1.025 → 1.0

opacity/glow:
very subtle

duration:
~1.6 sec

No aggressive neon effect.

--------------------------------------------------
TASK 2.3 — FRIENDSHIP / CARE
--------------------------------------------------

TARGET:

Top:
Bat artwork

Middle:
Mochi Bat
Friendship Lv. 1

Friendship bar:
20 / 100

Bottom:
large Feed button

Example:

🍓 Feed (0)

Use available fruit count.

Friendship bar:

dark background track
pink / magenta fill

When value increases:
animate smoothly
~0.5 sec easeOut

FEED interaction:

On tap:

1.
button compresses to ~0.96

2.
fruit visually moves toward bat if easy to implement

3.
bat does small happy bounce

4.
brief hearts appear

5.
Friendship bar fills

Heart particles:

maximum ~3–5

duration:
<1 sec

Do not create continuous particles.

If fruit count == 0:

button remains visually premium but disabled.

Show:
“Walk to find fruit”

only as small secondary text if needed.

--------------------------------------------------
TASK 2.4 — COLLECTION
--------------------------------------------------

Current grid looks too plain.

TARGET:

Header:
Bats
1 / 20

3-column grid where practical.

Unlocked card:
- bat sprite
- premium border
- subtle purple glow
- name or compact label if space permits

Selected/current companion:
small heart indicator

Locked card:
- dark silhouette
- question mark
- subtle dark card
- no bright blue question mark

Avoid excessive text.

NEW BAT REVEAL:

when a bat becomes newly unlocked:

opacity:
0 → 1

scale:
0.90 → 1.05 → 1

soft glow briefly appears

duration:
~0.5 sec

Use spring animation.

--------------------------------------------------
TASK 2.5 — HATCH READY SCREEN
--------------------------------------------------

Create / polish dedicated Hatch Ready state.

TARGET:

Header:
Ready!

Center:
egg / bat reveal visual

Text:
Your egg is ready!

Subtext:
A new friend is waiting to hatch.

Bottom:
large primary button

🥚 Hatch Now

Visual effects:

- subtle gold sparkles
- warm glow
- slow shimmer
- bat/egg floats slightly

On Hatch Now:

1.
screen dims slightly
2.
egg shakes
3.
short crack animation
4.
white/gold flash
5.
reveal bat
6.
haptic
7.
show rarity
8.
continue to Collection / companion setup

Keep total hatch sequence approximately:
2–4 seconds

Rare/Legendary can have slightly stronger effects.

Do not turn this into a long cinematic.

--------------------------------------------------
TASK 2.6 — SETTINGS
--------------------------------------------------

Move debug / instructional HealthKit text out of gameplay screens.

Settings should contain grouped cards:

Current Companion

Notifications

Health Access

Restore Purchase if relevant

Version / legal if already present

Use dark premium grouped cards.

Make Health permission errors understandable.

Example:

Health Access

Connected

or:

Health Access

Needs attention

Tap opens existing permission recovery flow.

==================================================
P3 — WATCH NAVIGATION / MOTION
==================================================

Do NOT add excessive animation.

Implement subtle global page transitions.

Recommended transition:

incoming:
opacity 0 → 1
offset x 10–16 → 0

outgoing:
opacity 1 → 0

duration:
0.25–0.35 sec

Use easeInOut.

Respect Reduce Motion.

Create shared helper if useful:

BatwalkPageTransition

Do not use animation effects that interfere with Digital Crown / Watch scrolling.

==================================================
P4 — IPHONE COMPANION REDESIGN
==================================================

The iPhone app can remain light-themed.

Do NOT copy the dark Watch UI directly.

Target:
premium editorial collectible app.

Use:
- off-white / very light lavender backgrounds
- purple brand accents
- large whitespace
- rounded cards
- subtle shadows only
- dark navy primary text

--------------------------------------------------
TASK 4.1 — BATPEDIA GRID
--------------------------------------------------

Header:

Batpedia · 1/20

Segmented control:

Normal | Shiny

Grid:
3 columns

Unlocked bat:

- art
- species name
- rarity badge
- subtle purple highlight

Locked:

- soft lavender / gray card
- silhouette / ?
- number
- no harsh borders

Tap unlocked bat:
navigate to Bat Detail.

Animation:
newly loaded cards stagger in very slightly.

Maximum delay between cards:
~30–50ms.

Do not create a slow cascading animation.

--------------------------------------------------
TASK 4.2 — BAT DETAIL
--------------------------------------------------

Target layout:

Hero section:

large atmospheric bat artwork
moon / forest background

Bat name:
Mochi Bat

Variant chips:
Normal
Common

Information cards:

Friendship Level
Favorite Fruit
Hatch Source
Hatch Date

Bottom primary button:

Set as Companion

If already companion:

Current Companion ✓

Use reusable chips and information-row components.

--------------------------------------------------
TASK 4.3 — HISTORY
--------------------------------------------------

Replace plain system-list feeling.

Top stat cards:

Bats Found
Shiny Bats
Eggs Hatched
Steps Walked

Use compact 2x2 cards.

Below:

Hatch Timeline

Each hatch row:

bat thumbnail
bat name
variant
egg source
date / time

Newest first.

Keep light visual hierarchy.

Do not display raw technical information.

--------------------------------------------------
TASK 4.4 — UNLOCK / PAYWALL
--------------------------------------------------

Current price:
$1.99 ONE-TIME PURCHASE

Do NOT add subscription.

Target page:

premium visual hero
bat + treasure / magical collection art if available

Title:

Unlock the Full Batwalk Experience

Benefits:

Access all 20 bats
Discover Rare & Legendary bats
Find Shiny variants
Unlock all egg pools
Complete the Batpedia

CTA:

Unlock All Bats
$1.99 · One-time purchase

Secondary:
Restore Purchase

Avoid manipulative countdowns / fake discounts.

Animation:

CTA subtle glow

premium hero sparkle:
very restrained

purchase success:
short celebration only

--------------------------------------------------
TASK 4.5 — COLLECTION / STATS
--------------------------------------------------

Create premium overview.

Hero progress card:

My Collection

1 / 20
5%

Milestones:

5 bats
10 bats
15 bats
20 bats

Recent Hatches list below.

Locked milestones:
muted.

Completed milestone:
brand purple / pink.

==================================================
P5 — REUSABLE COMPONENTS
==================================================

Extract where appropriate.

Suggested components:

WATCH

BatHeroView
BatwalkProgressRing
BatwalkStatRow
BatwalkGlassCard
FriendshipProgressView
FeedButton
BatCollectionTile
LockedBatTile
HatchReadyView

IPHONE

BatCard
LockedBatCard
RarityChip
VariantChip
StatCard
BatInfoRow
HatchHistoryRow
PrimaryGradientButton

SHARED

BatwalkTheme
BatwalkMotion
BatwalkRarityStyle

Do not over-engineer.

Only extract things that are reused.

==================================================
P6 — MOTION SYSTEM
==================================================

Implement these exact animation categories.

1. BAT IDLE FLOAT

Duration:
2.4 sec

Translate:
approximately 2–3 px

Curve:
easeInOut

autoreverse:
yes

--------------------------------------------------

2. EAR TWITCH

Interval:
random ~6–10 sec

Very short:
~0.15 sec movement
return ~0.2 sec

Only if animation asset / transform supports it cleanly.

--------------------------------------------------

3. HAPPY BOUNCE

Trigger:
feed / pet / friendship increase

Scale:
1 → 1.06 → 1

Vertical:
approximately -3px

Duration:
~0.35 sec

Spring.

--------------------------------------------------

4. PROGRESS RING

Initial fill:
0.7 sec

Pulse:
1.6 sec subtle

Do not continuously glow strongly.

--------------------------------------------------

5. FRIENDSHIP BAR

Animate old value → new value

0.45–0.6 sec easeOut

--------------------------------------------------

6. HATCH READY

Glow loop:
~1.8 sec

Sparkle:
few particles only

Do not continuously allocate large particle systems.

--------------------------------------------------

7. CARD / TILE UNLOCK

opacity:
0 → 1

scale:
0.9 → 1.04 → 1

duration:
~0.45 sec

--------------------------------------------------

8. BUTTON PRESS

scale:
1 → 0.96

duration:
0.1 sec

release:
spring to 1

--------------------------------------------------

9. PAGE TRANSITION

slide:
10–16px

fade

duration:
0.25–0.35 sec

--------------------------------------------------

10. REDUCE MOTION

If accessibility Reduce Motion is enabled:

disable:
- idle floating
- repetitive ring pulse
- decorative sparkles
- page slide

retain:
simple opacity changes where useful.

==================================================
P7 — ASSET RULES
==================================================

Do NOT generate placeholder emoji for final visual UI where an asset exists.

Use the supplied Mochi pixel artwork.

If required artwork is missing:

DO NOT redesign the character.

Create a clear TODO referencing the missing asset.

Maintain aspect ratio.

Do not stretch sprites.

Do not add interpolation blur to pixel art.

For SwiftUI pixel art rendering, ensure imagery stays visually crisp.

If appropriate use:
.interpolation(.none)

Test actual rendering on physical Apple Watch.

==================================================
P8 — REMOVE CURRENT PROTOTYPE LOOK
==================================================

Specifically remove / fix:

- large plain blocks of text on Watch
- debug-like Health instructions inside gameplay
- generic black backgrounds
- bright default blue question marks
- inconsistent corner radius
- generic default buttons
- inconsistent spacing
- default List appearance where custom cards are expected
- utility-dashboard feel

Do NOT sacrifice accessibility.

==================================================
P9 — HAPTICS
==================================================

Use haptics only for meaningful actions.

Recommended:

Feed:
light feedback

Friendship level increase:
success

Egg ready:
notification / success

Hatch:
strong success

Rare / Legendary reveal:
one additional restrained success event

Do NOT generate haptics for every navigation tap.

==================================================
P10 — PERFORMANCE
==================================================

Apple Watch battery is important.

Do NOT:

- run continuous TimelineView at unnecessary frame rates
- run 60fps animations when not needed
- create permanent particle emitters
- use heavy blur stacks everywhere
- continuously poll HealthKit because of animation

Animations should stop when screen is not visible.

Prefer lightweight SwiftUI animations.

==================================================
P11 — PREVIEW / TEST STATES
==================================================

Create preview/demo states for:

Home
Progress 61%
Progress 100%
Friendship Lv.1
Friendship Lv.5
No Fruit
Fruit Available
Collection 1/20
Collection with Rare Bat
Hatch Ready
Health Permission Error

iPhone:

Batpedia 1/20
Bat Detail
History
Unlock Page
Collection Stats

This lets visual QA happen without changing live game data.

==================================================
P12 — QA AGAINST DESIGN IMAGES
==================================================

After implementation:

compare each implemented screen side-by-side with attached design board.

Verify:

WATCH

[ ] Home visually matches
[ ] Progress ring matches
[ ] Friendship matches
[ ] Collection matches
[ ] Hatch Ready matches
[ ] Settings feels consistent

IPHONE

[ ] Batpedia matches
[ ] Bat Detail matches
[ ] History matches
[ ] Unlock matches
[ ] Collection Stats matches

SYSTEM

[ ] typography consistent
[ ] spacing consistent
[ ] card radius consistent
[ ] colors centralized
[ ] motion subtle
[ ] Reduce Motion supported
[ ] no broken functionality

==================================================
P13 — DEFINITION OF DONE
==================================================

This redesign is complete when:

1.
The Watch app no longer feels like a prototype or utility app.

2.
Mochi feels like a character living on the user's wrist.

3.
The visual system clearly matches the supplied design boards.

4.
Home / Progress / Friendship / Collection feel like one product.

5.
Animations make the bat feel alive without hurting battery.

6.
iPhone and Watch clearly belong to the same Batwalk brand.

7.
All existing core functionality still works.

8.
HealthKit still works.

9.
Purchases still work.

10.
Collection state is not lost.

11.
Animations respect accessibility settings.

12.
No AI functionality has been added.

==================================================
IMPLEMENTATION ORDER
==================================================

Implement in this exact order:

PASS 1
Design tokens + reusable Watch components

PASS 2
Watch Home

PASS 3
Watch Progress

PASS 4
Watch Friendship

PASS 5
Watch Collection

PASS 6
Hatch Ready + Hatch animation

PASS 7
Watch Settings

PASS 8
Watch motion polish + haptics

PASS 9
iPhone Batpedia

PASS 10
iPhone Bat Detail

PASS 11
iPhone History

PASS 12
iPhone Unlock

PASS 13
iPhone Collection Stats

PASS 14
Accessibility + Reduce Motion

PASS 15
Physical device QA + cleanup

==================================================
IMPORTANT WORKING STYLE
==================================================

Do not stop after giving recommendations.

Make the actual changes.

After each major pass:

- build the project
- fix compile errors
- preserve functionality
- visually compare against supplied design
- continue to next pass

If an attached design conflicts with current implementation:

prefer the attached design for VISUAL presentation,
but preserve existing game behavior.

If you discover missing product decisions:
do not redesign the product yourself.

Choose the simplest implementation consistent with the attached design and document the assumption.

At completion give me:

1. Files changed
2. New reusable components
3. Animations added
4. Screens completed
5. Remaining asset TODOs
6. Any technical compromises
7. Build/test status