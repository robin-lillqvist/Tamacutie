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

## Review
