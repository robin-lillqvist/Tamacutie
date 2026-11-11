import XCTest
@testable import CritterKit

final class TemperTests: XCTestCase {
    /// A sötis that has just had enough of cuddles.
    private func grumpyPet() -> (Pet, Date) {
        var pet = makePet()
        pet.needs.love = 100
        for second in 0..<Rules.overPetLimit { _ = pet.stroke(at: t0 + Double(second)) }
        let now = t0 + Double(Rules.overPetLimit)
        XCTAssertEqual(pet.temper(at: now), .grumpy)
        return (pet, now)
    }

    /// Strokes, tickles and taps on a sötis that wants space, `gap` seconds apart. Returns when it ended.
    private func pester(_ pet: inout Pet, times: Int, from start: Date, gap: TimeInterval = Rules.botherInterval) -> Date {
        var now = start
        for index in 0..<times {
            now = start + Double(index) * gap
            pet.advance(to: now)
            switch index % 3 {
            case 0: _ = pet.stroke(at: now)
            case 1: _ = pet.tickle(at: now)
            default: pet.poke(at: now)
            }
        }
        return now
    }

    private var bothersToUpset: Int { Int((Rules.upsetAt / Rules.annoyancePerBother).rounded(.up)) }
    private var bothersToFurious: Int { Int((Rules.furiousAt / Rules.annoyancePerBother).rounded(.up)) }

    /// Keeps pestering at a steady pace until it reaches `temper`. Returns how many bothers it took and when.
    private func pester(_ pet: inout Pet, until temper: Temper, from start: Date) -> (count: Int, end: Date) {
        var now = start
        for count in 1...200 {
            now = pester(&pet, times: 1, from: now + Rules.botherInterval)
            if pet.temper(at: now) == temper { return (count, now) }
        }
        XCTFail("never got \(temper)")
        return (0, now)
    }

    func testKeepPesteringAndItGoesGrumpyThenSadThenFurious() {
        var (pet, now) = grumpyPet()
        let upset = pester(&pet, until: .upset, from: now)
        XCTAssertGreaterThanOrEqual(upset.count, bothersToUpset, "a few more pokes is still only grumpy")
        XCTAssertEqual(pet.expression(at: upset.end), .sad)
        XCTAssertTrue(pet.isIgnoring(at: upset.end))

        let furious = pester(&pet, until: .furious, from: upset.end)
        XCTAssertGreaterThanOrEqual(upset.count + furious.count, bothersToFurious)
        XCTAssertLessThan(upset.count + furious.count, bothersToFurious + 5, "steady pestering does get there")
        XCTAssertEqual(pet.expression(at: furious.end), .furious)
        now = furious.end
        XCTAssertGreaterThan(now.timeIntervalSince(t0), 60, "it takes over a minute of pestering to go bananas")
    }

    func testFastPokingCountsOnlyOncePerInterval() {
        var (pet, now) = grumpyPet()
        for step in 0..<400 { pet.poke(at: now + Double(step) * 0.05) }
        XCTAssertEqual(pet.temper(at: now + 20), .grumpy, "twenty seconds of frantic tapping is not enough")
        XCTAssertLessThanOrEqual(pet.annoyanceLevel, Rules.annoyancePerBother * 11)
    }

    func testAPetThatWantsNothingFromYouIsNotBothered() {
        var pet = makePet()
        for second in 0..<200 {
            pet.poke(at: t0 + Double(second))
            _ = pet.tickle(at: t0 + Double(second))
        }
        XCTAssertEqual(pet.temper(at: t0 + 200), .calm, "tickles and taps on a happy sötis are just play")
        XCTAssertEqual(pet.annoyanceLevel, 0)
    }

    func testLeftAloneItCalmsDownAgain() {
        var (pet, now) = grumpyPet()
        let end = pester(&pet, until: .furious, from: now).end
        now = end + 6 * 60
        pet.advance(to: now)
        XCTAssertEqual(pet.temper(at: now), .upset, "fury fades within minutes")
        now = end + 30 * 60
        pet.advance(to: now)
        XCTAssertEqual(pet.temper(at: now), .calm)
        XCTAssertNotEqual(pet.stroke(at: now), .ignored)
    }

    func testTreatsCalmItDown() {
        var (pet, now) = grumpyPet()
        now = pester(&pet, until: .furious, from: now).end
        _ = pet.feed(FoodEffect(hunger: 5), at: now)
        XCTAssertEqual(pet.temper(at: now), .upset)
        _ = pet.feed(FoodEffect(hunger: 5), at: now)
        XCTAssertTrue(pet.drink(10, at: now))
        XCTAssertLessThan(pet.temper(at: now), .upset)
        XCTAssertFalse(pet.isGrumpy(at: now))
        XCTAssertTrue(pet.isIgnoring(at: now), "calmer, but it still wants a bit of space")
    }

    func testPesteringAfterATreatMakesItGrumpyAgain() {
        var (pet, now) = grumpyPet()
        XCTAssertTrue(pet.drink(10, at: now))
        XCTAssertEqual(pet.temper(at: now), .calm)
        pet.poke(at: now + 5)
        XCTAssertEqual(pet.temper(at: now + 5), .grumpy)
    }

    func testOldSavesWithoutAnnoyanceStillLoad() throws {
        let pet = makePet()
        var json = try JSONSerialization.jsonObject(with: JSONEncoder().encode(pet)) as! [String: Any]
        json.removeValue(forKey: "annoyance")
        json.removeValue(forKey: "lastBother")
        let decoded = try JSONDecoder().decode(Pet.self, from: JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(decoded.annoyanceLevel, 0)
    }
}

final class SoloLifeTests: XCTestCase {
    private func pick(_ pet: Pet, idle: TimeInterval = 60, phase: DayPhase = .day, roll: Double = 0.5) -> SoloActivity? {
        SoloLife.pick(for: pet, at: t0, idle: idle, phase: phase, roll: roll)
    }

    private func rested() -> Pet {
        var pet = makePet()
        pet.needs = Needs(hunger: 90, thirst: 90, energy: 90, hygiene: 90, fun: 90, love: 90)
        return pet
    }

    func testOnlyWhenLeftAloneForAWhile() {
        XCTAssertNil(pick(rested(), idle: Rules.soloAfterIdle - 1))
        XCTAssertNotNil(pick(rested(), idle: Rules.soloAfterIdle))
    }

    func testEveryDaytimeActivityComesUp() {
        let picks = Set(stride(from: 0.0, to: 1, by: 0.02).compactMap { pick(rested(), roll: $0) })
        XCTAssertEqual(picks, [.reading, .playingBall, .dancing, .watchingFish])
    }

    func testAtNightItLooksAtTheStarsInsteadOfReading() {
        let picks = Set(stride(from: 0.0, to: 1, by: 0.02).compactMap { pick(rested(), phase: .night, roll: $0) })
        XCTAssertTrue(picks.contains(.stargazing))
        XCTAssertFalse(picks.contains(.reading))
    }

    func testBoredItPlaysTiredItReads() {
        var bored = rested()
        bored.needs.fun = 20
        XCTAssertEqual(pick(bored, roll: 0), .playingBall)
        var tired = rested()
        tired.needs.energy = 35
        let picks = Set(stride(from: 0.0, to: 1, by: 0.05).compactMap { pick(tired, roll: $0) })
        XCTAssertEqual(picks, [.reading, .watchingFish])
    }

    func testNeedsComeFirst() {
        var hungry = rested()
        hungry.needs.hunger = 20
        XCTAssertNil(pick(hungry))
        var sleepy = rested()
        sleepy.needs.energy = 15
        XCTAssertNil(pick(sleepy))
    }

    func testGrumpyItGoesOffToReadAndUpsetItSulks() {
        var pet = rested()
        pet.needs.love = 100
        for second in 0..<Rules.overPetLimit { _ = pet.stroke(at: t0 - 30 + Double(second)) }
        XCTAssertEqual(pet.temper(at: t0), .grumpy)
        XCTAssertEqual(pick(pet, roll: 0.9), .reading)
        for index in 0..<20 { pet.poke(at: t0 - 25 + Double(index) * Rules.botherInterval * 0.6 + Double(index)) }
        XCTAssertGreaterThanOrEqual(pet.temper(at: t0 + 20), .upset)
        XCTAssertNil(SoloLife.pick(for: pet, at: t0 + 20, idle: 60, phase: .day, roll: 0.5))
    }

    func testPlayingAloneIsFunButNoAttention() {
        var pet = rested()
        pet.needs.fun = 40
        let before = pet.lastInteraction
        pet.amuseItself(fun: 5, energy: 1)
        XCTAssertEqual(pet.needs.fun, 45, accuracy: 0.01)
        XCTAssertEqual(pet.needs.energy, 89, accuracy: 0.01)
        XCTAssertEqual(pet.lastInteraction, before)
    }
}
