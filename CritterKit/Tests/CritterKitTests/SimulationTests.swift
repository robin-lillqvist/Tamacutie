import XCTest
@testable import CritterKit

final class SimulationTests: XCTestCase {
    func testNeedsDecayInRealTime() {
        var pet = makePet()
        pet.advance(to: t0 + hours(2))
        XCTAssertEqual(pet.needs.hunger, 80 - 2 * Rules.hungerDecay, accuracy: 0.01)
        XCTAssertEqual(pet.needs.thirst, 80 - 2 * Rules.thirstDecay, accuracy: 0.01)
        XCTAssertEqual(pet.needs.fun, 80 - 2 * Rules.funDecay, accuracy: 0.01)
    }

    func testAdvancingInPiecesMatchesAdvancingAtOnce() {
        var once = makePet()
        var pieces = makePet()
        once.advance(to: t0 + hours(5))
        for minute in stride(from: 7.0, through: 300, by: 7) {
            pieces.advance(to: t0 + minute * 60)
        }
        pieces.advance(to: t0 + hours(5))
        XCTAssertEqual(once.needs.hunger, pieces.needs.hunger, accuracy: 0.001)
        XCTAssertEqual(once.weight, pieces.weight, accuracy: 0.001)
    }

    func testAdvancingBackwardsDoesNothing() {
        var pet = makePet()
        pet.advance(to: t0 + hours(1))
        let snapshot = pet
        pet.advance(to: t0)
        XCTAssertEqual(pet, snapshot)
    }

    func testFallsAsleepWhenExhaustedAndWakesRested() {
        var pet = makePet()
        pet.needs.energy = 10
        pet.advance(to: t0 + hours(1))
        XCTAssertTrue(pet.isAsleep)
        // Falls asleep at energy 8 after 30 min, then needs 92 / 14 ≈ 6.6 h to refill.
        pet.advance(to: t0 + hours(7.2))
        XCTAssertFalse(pet.isAsleep)
        XCTAssertGreaterThanOrEqual(pet.needs.energy, 99)
    }

    func testSleepingSlowsHunger() {
        var awake = makePet()
        var sleeping = makePet()
        XCTAssertTrue(sleeping.goToSleep(at: t0))
        awake.advance(to: t0 + hours(2))
        sleeping.advance(to: t0 + hours(2))
        XCTAssertGreaterThan(sleeping.needs.hunger, awake.needs.hunger)
    }

    func testTraitsChangeRates() {
        var glutton = makePet(traits: [.glutton])
        var plain = makePet()
        glutton.advance(to: t0 + hours(3))
        plain.advance(to: t0 + hours(3))
        XCTAssertLessThan(glutton.needs.hunger, plain.needs.hunger)
    }

    func testFoodBecomesPoopAfterDigesting() {
        var pet = makePet()
        _ = pet.feed(FoodEffect(hunger: 10), at: t0)
        pet.advance(to: t0 + Rules.digestionDelay - 60)
        XCTAssertTrue(pet.poops.isEmpty)
        pet.advance(to: t0 + Rules.digestionDelay + 60)
        XCTAssertEqual(pet.poops.count, 1)
        let poop = pet.poops[0]
        XCTAssertTrue((0...1).contains(poop.x) && (0...1).contains(poop.y))
    }

    func testLeftPoopMakesPetSick() {
        var pet = makePet()
        for minute in 0..<5 {
            _ = pet.feed(FoodEffect(hunger: 1), at: t0 + Double(minute) * 60)
        }
        pet.advance(to: t0 + hours(1))
        XCTAssertEqual(pet.poops.count, 5)
        XCTAssertFalse(pet.isSick)
        pet.advance(to: t0 + hours(1) + hours(Rules.hoursDirtyUntilSick) + 60)
        XCTAssertTrue(pet.isSick)
        pet.cure(at: pet.lastUpdate)
        XCTAssertFalse(pet.isSick)
    }

    func testScoopingRemovesPoop() {
        var pet = makePet()
        _ = pet.feed(FoodEffect(hunger: 5), at: t0)
        pet.advance(to: t0 + hours(1))
        let id = pet.poops[0].id
        XCTAssertTrue(pet.scoop(id))
        XCTAssertFalse(pet.scoop(id))
        XCTAssertTrue(pet.poops.isEmpty)
    }
}
