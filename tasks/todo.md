# Critter Corner — build plan

## Phase 1 — Core logic (CritterKit package, fully unit-tested)
- [x] Seeded RNG, Genome, name generator
- [x] Pet state + real-time simulation (needs decay, sleep, digestion/poop, weight, death)
- [x] Social behaviour (missed-you bonus, love-full cooldown)
- [x] Economy (wallet, daily gift, piggy bank), catalog, inventory, room layout
- [x] Game state + memorial + persistence (JSON)

## Phase 2 — App shell
- [x] XcodeGen project (iPad only, landscape, iPadOS 17+)
- [x] Theme + procedural CritterView (SwiftUI Canvas, matches mockups)
- [x] GameStore (real-time ticking, save on background)

## Phase 3 — Screens
- [x] Adopt, Home (HUD, petting, feeding, water, sleep, scoop, play)
- [x] Market, Bath, Park (fetch + dig), Decor, Body info, Farewell + In Memoriam
- [x] Local notifications for low needs

## Phase 4 — Ship
- [x] App icon
- [ ] Build, test, install silently on both iPads

- [x] Shiny sparkle after bath; believable bath (taps, pipes, shower rail, sponge, towel, drain); dirt on the coat; condition looks (sparkly, dirty, filthy, sick, dying)

## Review
- Logic: 44 CritterKit tests (`cd CritterKit && swift test`) cover decay, sleep, digestion, sickness, weight, death by neglect and by overeating, social behaviour, economy, decor, memorial and save/load.
- App: 13 tests (`xcodebuild test`) cover the store's real-time persistence and render every screen at iPad size (set TEST_RUNNER_SNAPSHOT_DIR to save PNGs).
- iPadOS 26 letterboxes landscape-only apps, so every orientation is supported. Portrait works, but the layout is designed for landscape.
- Deploy is blocked: Xcode has no signed-in Apple account, so it can't create a provisioning profile for se.lillqvist.crittercorner.

# Polish round 1 — make the critter interactive
- [x] Playground logic in CritterKit (ball physics, fetch state machine, bubbles) + tests
- [x] Play mode on Home: flick the ball, critter chases/catches/returns it; blow bubbles it jumps to pop
- [x] Living critter: wanders, walks to bowl/bed by need, faces direction, walk bob, eyes follow touch
- [x] Petting/tickle reactions, haptics, drag food to the mouth (mouth opens when food is near)
- [x] UI tests that play the game in a landscape simulator and save screenshots

# Temper and a life of its own
- [x] Temper ladder in CritterKit: grumpy → upset (sad) → furious, from sustained bothering while it wants space; rate-limited, decays, food calms + tests
- [x] Furious art: red eyes, angry brows, pointy teeth, shaking, steam
- [x] Reactions in Home: escalating lines, sulking, raging stomps
- [x] SoloLife in CritterKit: picks an activity after ~20 s alone (read in window / stargaze at night, ball alone, dance, fish) + tests
- [x] Playground: critter tosses the ball itself + test
- [x] Home: perch on the window sill with a book, solo ball, dance, fish; touching interrupts; grabbing the ball joins in
- [x] Snapshots/UI check, swift test, app build, commit, deploy

## Review
- Temper: 7 TemperTests + a real-time over-petting test. A UI play-through pesters it from grumpy to sad to furious in about 3 minutes of steady pestering.
- Fixed along the way: love decays slightly between strokes, so it was never exactly 100 and over-petting never made it grumpy on a device. "Full" now starts at 99.
- Solo life: 7 SoloLifeTests and a self-fetch test. A UI test waits until it starts something on its own, then checks that a touch interrupts it. Screenshots show the ball game and reading in the window.
