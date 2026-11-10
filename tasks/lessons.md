# Lessons

- **Every interaction needs a visible cause and effect on the critter.** "Play" that only animated a prop and changed a number felt pointless. The critter should react with its body: chase, catch, look, lean, giggle. And the player should physically do something: flick, drag, tap.
- **Play the game, don't just render it.** Static snapshots missed that the happy face kept the eyes closed, which hid the eye tracking. The XCUITest play-throughs in landscape (`CritterCornerUITests`) are the way to see real behaviour; read their screenshots after UI changes.
