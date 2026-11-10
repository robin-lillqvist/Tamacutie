# Lessons

- **Every interaction needs a visible cause and effect on the critter.** "Play" that only animated a prop and changed a number felt pointless. The critter should react with its body: chase, catch, look, lean, giggle. And the player should physically do something: flick, drag, tap.
- **Play the game, don't just render it.** Static snapshots missed that the happy face kept the eyes closed, which hid the eye tracking. The XCUITest play-throughs in landscape (`CritterCornerUITests`) are the way to see real behaviour; read their screenshots after UI changes.
- **Effects belong on the critter, not on top of it.** Mud drawn as a separate overlay floated around while the critter breathed and wiggled. Paint coat effects inside the critter painter, clipped to the body outline.
- **Gesture layers must sit under the buttons.** A full-screen drag catcher placed above a button silently ate its taps. Order the ZStack so tappable things come after the catch-all layer, and keep resting tools clear of other buttons (the duck covered the sponge).
- **Make tools physical.** If you can scrub or rinse by touching anywhere, the steps blur together. Make the player pick each tool up from where it lies, with a pulsing hint on the next one.
