# Lessons

- **Every interaction needs a visible cause and effect on the critter.** "Play" that only animated a prop and changed a number felt pointless. The critter should react with its body: chase, catch, look, lean, giggle. And the player should physically do something: flick, drag, tap.
- **Play the game, don't just render it.** Static snapshots missed that the happy face kept the eyes closed, which hid the eye tracking. The XCUITest play-throughs in landscape (`CritterCornerUITests`) are the way to see real behaviour; read their screenshots after UI changes.
- **Effects belong on the critter, not on top of it.** Mud drawn as a separate overlay floated around while the critter breathed and wiggled. Paint coat effects inside the critter painter, clipped to the body outline.
- **Gesture layers must sit under the buttons.** A full-screen drag catcher placed above a button silently ate its taps. Order the ZStack so tappable things come after the catch-all layer, and keep resting tools clear of other buttons (the duck covered the sponge).
- **Make tools physical.** If you can scrub or rinse by touching anywhere, the steps blur together. Make the player pick each tool up from where it lies, with a pulsing hint on the next one.
- **"Research a style" means looking at the actual visuals.** I ran two text searches about Toca Boca's philosophy, never viewed a single reference image, and presented small tweaks as "Toca-like". The user saw straight through it. For any art-style request: gather real reference images, write down concrete rules (proportions, shape construction, texture, palette, faces), show a design sheet for approval, then change code. Never claim a style match that the visuals don't show.
- **After editing `project.yml`, run `xcodegen generate`.** The Xcode project is generated and gitignored, so the rename to "Sötishörnan" didn't reach the build until I regenerated. Check the installed name on the device (`devicectl device info apps`) after a deploy.

## Moving tap targets
- A SwiftUI Button that moves every frame drops taps (the park frisbee scored 0 for a real child). Hit-test moving things in one fixed tap layer against a model, and be lenient about time: fingers lag behind eyes, so accept taps near where the object just was.
- In UI tests, poll with short sleeps instead of XCTNSPredicateExpectation when timing matters; expectations only check about once a second.

## Rate-limit interactions in the model
- Gestures fire many times a second. Every care action a child can repeat (stroke, tickle) needs a minimum interval in CritterKit, and chatty speech must not replace a bubble that just appeared. Consequences like grumpiness need a visible warning first and sustained misuse, never a few fast taps.

## Test model rules with time passing
- Needs decay continuously, so "exactly full" never lasts on a device. The over-petting rule only passed its unit tests because those never advanced time between strokes. When a rule compares a decaying value to a limit, test it with `advance(to:)` between actions.
- UI-test screenshots only land on disk via `TEST_RUNNER_SNAPSHOT_DIR` (xcodebuild strips the prefix). Plain `SNAPSHOT_DIR` silently writes nothing.

## Scrolling worlds
- Things that stand on something must be placed by their *drawn* feet, not their frame. The critter's feet sit 21 pt above its 300 pt frame (`RoomLayout.groundInset`); use `critterCenter(feetAt:)` and check contact in a zoomed snapshot. The user spotted a sötis bouncing in mid-air over the cushion.
- A walk animated with `withAnimation` sets the final x at once. Anything that tracks the critter while it moves (the camera) needs the interpolated position (`stroll`).
- In XCUITest, `element.tap()` silently missed buttons in a `.position`ed overlay, though the element said it was hittable. Coordinate taps (`element.coordinate(withNormalizedOffset: 0.5, 0.5).tap()`) behave like fingers. When a tap "does nothing", count taps in the app before blaming the app logic.
- Menus must never cover the sötis: `MenusClearUITests` checks the needs strip, dock, fridge and play pill against the critter's body frame.
- A `DragGesture(minimumDistance: 0)` next to a double-tap gesture doesn't get its first event until the finger moves, so a "hold still" timer started from it never fires. Use `LongPressGesture(...).sequenced(before: DragGesture(...))` for press-and-hold.
- Before driving the UI to something, make sure it's on screen: the camera follows the sötis and can scroll the target away.
- UI tests launch with `-muted YES`.
