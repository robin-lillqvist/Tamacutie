import XCTest
@testable import CritterKit

final class LifeAndDeathTests: XCTestCase {
    func testWellFedPetKeepsHealthyWeight() {
        var pet = makePet()
        for hour in stride(from: 0.0, to: 72, by: 4) {
            pet.advance(to: t0 + hours(hour))
            _ = pet.feed(FoodEffect(hunger: 24), at: t0 + hours(hour))
            _ = pet.drink(32, at: t0 + hours(hour))
        }
        XCTAssertTrue(pet.isAlive)
        XCTAssertEqual(pet.weightStage, .healthy)
    }

    func testNeglectMakesPetThinThenKillsIt() {
        var pet = makePet()
        pet.advance(to: t0 + hours(30))
        XCTAssertTrue(pet.isAlive)
        XCTAssertLessThan(pet.weight, Rules.healthyWeight)

        pet.advance(to: t0 + hours(40))
        XCTAssertTrue(pet.isAlive, "Death should take a while, not one day")
        XCTAssertTrue([.thin, .starving].contains(pet.weightStage))

        pet.advance(to: t0 + hours(24 * 7))
        XCTAssertFalse(pet.isAlive)
        XCTAssertEqual(pet.causeOfDeath, .starvation)
        XCTAssertEqual(pet.expression(at: t0 + hours(24 * 7)), .dead)
    }

    func testDeathStopsTheClock() {
        var pet = makePet()
        pet.advance(to: t0 + hours(24 * 10))
        let death = pet.deathDate!
        pet.advance(to: t0 + hours(24 * 20))
        XCTAssertEqual(pet.deathDate, death)
        XCTAssertEqual(pet.ageInDays(at: t0 + hours(24 * 20)), Int(death.timeIntervalSince(t0) / 86400))
    }

    func testOverfeedingMakesPetFat() {
        var pet = makePet()
        pet.needs.hunger = 100
        for minute in 0..<8 {
            XCTAssertEqual(pet.feed(FoodEffect(hunger: 20), at: t0 + Double(minute) * 60), .tooFull)
        }
        XCTAssertEqual(pet.weightStage, .chubby)
        XCTAssertTrue(pet.isAlive)
    }

    func testOverfeedingEvenMoreKillsIt() {
        var pet = makePet()
        pet.needs.hunger = 100
        var minute = 0.0
        while pet.isAlive && minute < 100 {
            _ = pet.feed(FoodEffect(hunger: 10, fun: 15, fattening: 6), at: t0 + minute * 60)
            minute += 1
        }
        XCTAssertFalse(pet.isAlive)
        XCTAssertEqual(pet.causeOfDeath, .overeating)
        XCTAssertGreaterThan(minute, 5, "One treat must never be fatal")
        XCTAssertEqual(pet.feed(FoodEffect(hunger: 10), at: t0 + hours(1)), .dead)
    }

    func testChubbyPetSlimsDownWithNormalCareAndExercise() {
        var pet = makePet()
        pet.weight = 75
        pet.needs.hunger = 60
        pet.visitPark(at: t0)
        XCTAssertEqual(pet.weight, 72, accuracy: 0.01)
        pet.advance(to: t0 + hours(4))
        XCTAssertLessThan(pet.weight, 72)
    }

    func testThinPetRecoversWhenFed() {
        var pet = makePet()
        pet.weight = 25
        pet.needs.hunger = 90
        pet.needs.thirst = 90
        pet.advance(to: t0 + hours(5))
        XCTAssertGreaterThan(pet.weight, 25)
    }

    func testDehydrationAlsoWastesAway() {
        var thirsty = makePet()
        var fine = makePet()
        thirsty.needs.thirst = 0
        thirsty.needs.hunger = 100
        fine.needs.hunger = 100
        fine.needs.thirst = 100
        thirsty.advance(to: t0 + hours(3))
        fine.advance(to: t0 + hours(3))
        XCTAssertLessThan(thirsty.weight, fine.weight)
    }
}
