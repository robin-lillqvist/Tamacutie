import XCTest
@testable import CritterKit

final class SocialTests: XCTestCase {
    func testStrokingGivesLove() {
        var pet = makePet()
        XCTAssertEqual(pet.stroke(at: t0), .loved(gain: Rules.strokeLove))
        XCTAssertEqual(pet.needs.love, 60 + Rules.strokeLove, accuracy: 0.01)
    }

    func testPetMissesYouAfterLongAbsence() {
        var pet = makePet()
        pet.needs.hunger = 100
        let later = t0 + Rules.missedYouAfter + 60
        pet.advance(to: later)
        XCTAssertTrue(pet.registerVisit(at: later))
        pet.wakeUp(at: later)
        XCTAssertEqual(pet.expression(at: later), .excited)
        XCTAssertEqual(pet.stroke(at: later), .loved(gain: Rules.strokeLove * 2))
    }

    func testShortAbsenceIsNotMissed() {
        var pet = makePet()
        XCTAssertFalse(pet.registerVisit(at: t0 + hours(3)))
        XCTAssertFalse(pet.missesYou(at: t0 + hours(3)))
    }

    func testFullOfLoveThenIgnoresYou() {
        var pet = makePet()
        var result = StrokeResult.ignored
        for _ in 0..<20 {
            result = pet.stroke(at: t0)
            if result == .nowFull { break }
        }
        XCTAssertEqual(result, .nowFull)
        XCTAssertEqual(pet.stroke(at: t0 + 60), .ignored)
        XCTAssertEqual(pet.expression(at: t0 + 60), .ignoring)
        let afterCooldown = t0 + Rules.loveFullCooldown + 60
        pet.advance(to: afterCooldown)
        XCTAssertNotEqual(pet.stroke(at: afterCooldown), .ignored)
    }

    func testSleepingPetCannotBeStrokedOrFed() {
        var pet = makePet()
        XCTAssertTrue(pet.goToSleep(at: t0))
        XCTAssertEqual(pet.stroke(at: t0), .asleep)
        XCTAssertEqual(pet.feed(FoodEffect(hunger: 10), at: t0), .asleep)
        pet.wakeUp(at: t0)
        XCTAssertFalse(pet.isAsleep)
    }

    func testExpressions() {
        var pet = makePet()
        pet.needs = Needs(hunger: 90, thirst: 90, energy: 90, hygiene: 90, fun: 90, love: 90)
        XCTAssertEqual(pet.expression(at: t0), .happy)
        pet.needs.hunger = 10
        XCTAssertEqual(pet.expression(at: t0), .hungry)
        pet.needs.hunger = 90
        pet.weight = 95
        XCTAssertEqual(pet.expression(at: t0), .sad)
    }
}
