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

    /// Strokes one second apart, like a calm hand. Returns every result.
    private func strokes(_ pet: inout Pet, count: Int, from start: Date) -> [StrokeResult] {
        (0..<count).map { pet.stroke(at: start + Double($0)) }
    }

    func testRubbingFastIsNotSpam() {
        var pet = makePet()
        XCTAssertEqual(pet.stroke(at: t0), .loved(gain: Rules.strokeLove))
        for step in 1...20 {
            XCTAssertEqual(pet.stroke(at: t0 + Double(step) * 0.04), .tooSoon)
        }
        XCTAssertEqual(pet.needs.love, 60 + Rules.strokeLove, accuracy: 0.01, "fifty strokes a second count once")
    }

    func testFullOfLoveIsHappyNotGrumpy() {
        var pet = makePet()
        let results = strokes(&pet, count: 10, from: t0)
        XCTAssertEqual(results.last, .nowFull)
        XCTAssertFalse(pet.isIgnoring(at: t0 + 10))
        XCTAssertNotEqual(pet.expression(at: t0 + 10), .ignoring)
    }

    func testOnlyTurnsGrumpyIfYouKeepGoingAfterTheWarning() {
        var pet = makePet()
        pet.needs.love = 100
        let results = strokes(&pet, count: Rules.overPetLimit, from: t0)
        XCTAssertEqual(results.first, .loved(gain: 0))
        XCTAssertEqual(results[Rules.overPetWarning - 1], .enough, "warns before getting cross")
        XCTAssertEqual(results.last, .grumpy)
        let after = t0 + Double(Rules.overPetLimit)
        XCTAssertEqual(pet.stroke(at: after + 5), .ignored)
        XCTAssertEqual(pet.expression(at: after + 5), .ignoring)
        let afterCooldown = after + Rules.loveFullCooldown + 60
        pet.advance(to: afterCooldown)
        XCTAssertNotEqual(pet.stroke(at: afterCooldown), .ignored)
    }

    func testOverPettingInRealTimeStillMakesItGrumpy() {
        var pet = makePet()
        var now = t0
        var results: [StrokeResult] = []
        for _ in 0..<30 {
            now += 1.5
            pet.advance(to: now)
            results.append(pet.stroke(at: now))
            if results.last == .grumpy { break }
        }
        XCTAssertEqual(results.filter { $0 == .nowFull }.count, 1, "love trickling away between strokes isn't 'full again'")
        XCTAssertEqual(results.last, .grumpy)
    }

    func testAPauseForgivesOverPetting() {
        var pet = makePet()
        pet.needs.love = 100
        _ = strokes(&pet, count: Rules.overPetLimit - 1, from: t0)
        let later = t0 + Rules.overPetForgiveAfter + 30
        XCTAssertEqual(pet.stroke(at: later), .loved(gain: 0), "starts counting again")
        XCTAssertFalse(pet.isIgnoring(at: later))
    }

    func testFoodAndDrinkTakeTheGrumpinessAwayButItStillWantsSpace() {
        var pet = makePet()
        pet.needs.love = 100
        _ = strokes(&pet, count: Rules.overPetLimit, from: t0)
        let now = t0 + 30
        XCTAssertTrue(pet.isGrumpy(at: now))
        XCTAssertTrue(pet.drink(20, at: now))
        XCTAssertFalse(pet.isGrumpy(at: now))
        XCTAssertNotEqual(pet.expression(at: now), .ignoring)
        XCTAssertTrue(pet.isIgnoring(at: now), "still wants to be alone for a while")
        XCTAssertEqual(pet.stroke(at: now + 5), .ignored)

        var hungry = makePet()
        hungry.needs.love = 100
        _ = strokes(&hungry, count: Rules.overPetLimit, from: t0)
        _ = hungry.feed(FoodEffect(hunger: 10), at: now)
        XCTAssertFalse(hungry.isGrumpy(at: now))
    }

    func testSweetsMakeItHappy() {
        var pet = makePet()
        pet.needs = Needs(hunger: 50, thirst: 50, energy: 50, hygiene: 50, fun: 30, love: 30)
        XCTAssertNotEqual(pet.expression(at: t0), .happy)
        let lollipop = Catalog.item("lollipop")!.foodEffect!
        XCTAssertTrue(lollipop.isSweet)
        _ = pet.feed(lollipop, at: t0)
        XCTAssertEqual(pet.expression(at: t0 + 60), .happy)
        XCTAssertGreaterThan(pet.needs.love, 30)
        pet.advance(to: t0 + Rules.sweetJoyDuration + 60)
        XCTAssertNotEqual(pet.expression(at: t0 + Rules.sweetJoyDuration + 60), .happy)
    }

    func testSweetsAreExpensive() {
        let sweets = Catalog.items.filter { $0.foodEffect?.isSweet == true }
        XCTAssertEqual(Set(sweets.map(\.id)), ["lollipop", "icecream", "soda"])
        let priciestFood = Catalog.items.filter { $0.foodEffect.map { !$0.isSweet } ?? false }.map(\.price).max()!
        for sweet in sweets {
            XCTAssertGreaterThan(sweet.price, priciestFood * 3, sweet.name)
            XCTAssertEqual(sweet.aisle, .treats)
        }
    }

    func testTickling() {
        var pet = makePet()
        XCTAssertEqual(pet.tickle(at: t0), .giggled)
        XCTAssertEqual(pet.needs.fun, 80 + Rules.tickleFun, accuracy: 0.01)
        XCTAssertEqual(pet.tickle(at: t0 + 0.3), .tooSoon)
        XCTAssertEqual(pet.tickle(at: t0 + Rules.tickleInterval), .giggled)
        for second in 0..<60 { _ = pet.tickle(at: t0 + 10 + Double(second)) }
        XCTAssertFalse(pet.isIgnoring(at: t0 + 80), "tickling never makes it grumpy")
        XCTAssertTrue(pet.goToSleep(at: t0 + 100))
        XCTAssertEqual(pet.tickle(at: t0 + 100), .asleep)
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
