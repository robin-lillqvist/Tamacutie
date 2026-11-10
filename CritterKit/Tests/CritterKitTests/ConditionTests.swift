import XCTest
@testable import CritterKit

final class ConditionTests: XCTestCase {
    func testConditionFollowsHygiene() {
        var pet = makePet()
        pet.needs.hygiene = 95
        XCTAssertEqual(pet.condition(at: t0), .clean)
        pet.needs.hygiene = 70
        XCTAssertEqual(pet.condition(at: t0), .normal)
        pet.needs.hygiene = 40
        XCTAssertEqual(pet.condition(at: t0), .dirty)
        pet.needs.hygiene = 10
        XCTAssertEqual(pet.condition(at: t0), .filthy)
    }

    func testBathMakesItSparklyThenNormalAgain() {
        var pet = makePet()
        pet.bathe(at: t0)
        XCTAssertEqual(pet.condition(at: t0), .sparkly)
        let later = t0 + Rules.shineDuration + 60
        pet.advance(to: later)
        XCTAssertEqual(pet.condition(at: later), .clean)
    }

    func testGrimeGrowsAsHygieneDrops() {
        var pet = makePet()
        pet.needs.hygiene = 80
        XCTAssertEqual(pet.grime, 0)
        pet.needs.hygiene = 35
        XCTAssertEqual(pet.grime, 0.5, accuracy: 0.001)
        pet.needs.hygiene = 0
        XCTAssertEqual(pet.grime, 1)
    }

    func testSicknessAndDangerousWeightOutrankDirt() {
        var pet = makePet()
        pet.needs.hygiene = 10
        pet.weight = 10
        XCTAssertEqual(pet.condition(at: t0), .dying)
        pet.weight = 50
        for minute in 0..<5 { _ = pet.feed(FoodEffect(hunger: 1), at: t0 + Double(minute) * 60) }
        pet.advance(to: t0 + 8 * 3600)
        XCTAssertTrue(pet.isSick)
        XCTAssertEqual(pet.condition(at: t0 + 8 * 3600), .sick)
    }

    func testDeadIsDead() {
        var pet = makePet()
        pet.advance(to: t0 + 10 * 86400)
        XCTAssertEqual(pet.condition(at: t0 + 10 * 86400), .dead)
    }
}
