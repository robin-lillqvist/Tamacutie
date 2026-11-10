import XCTest
@testable import CritterKit

final class GameStateTests: XCTestCase {
    func testStartsWithCoinsAndBasics() {
        let game = GameState(now: t0)
        XCTAssertEqual(game.coins, Rules.startingCoins)
        XCTAssertGreaterThan(game.count(of: "kibble"), 0)
        XCTAssertGreaterThan(game.count(of: "water"), 0)
    }

    func testOnlyOnePetAtATime() {
        var game = makeGame()
        XCTAssertFalse(game.adopt(genome: Genome(seed: 5), name: "Pip", now: t0))
    }

    func testBuyingCostsCoinsAndAddsPack() {
        var game = makeGame()
        let before = game.count(of: "kibble")
        XCTAssertEqual(game.buy("kibble"), .bought)
        XCTAssertEqual(game.coins, Rules.startingCoins - 10)
        XCTAssertEqual(game.count(of: "kibble"), before + 5)
        XCTAssertEqual(game.buy("nope"), .unknownItem)
    }

    func testCannotOverspend() {
        var game = makeGame()
        XCTAssertEqual(game.buy("sofa"), .notEnoughCoins)
        XCTAssertEqual(game.coins, Rules.startingCoins)
    }

    func testFeedingUsesInventory() {
        var game = makeGame()
        game.pet!.needs.hunger = 30
        let before = game.count(of: "kibble")
        XCTAssertEqual(game.feed("kibble", now: t0), .yummy)
        XCTAssertEqual(game.count(of: "kibble"), before - 1)
        XCTAssertEqual(game.pet!.needs.hunger, 50, accuracy: 0.01)
        XCTAssertNil(game.feed("fish", now: t0), "No fish in the fridge")
    }

    func testWaterUsesBottle() {
        var game = makeGame()
        game.pet!.needs.thirst = 20
        XCTAssertTrue(game.refillWater(now: t0))
        XCTAssertEqual(game.pet!.needs.thirst, 65, accuracy: 0.01)
    }

    func testScoopingPaysCoins() {
        var game = makeGame()
        _ = game.feed("kibble", now: t0)
        game.advance(to: t0 + hours(1))
        let poop = game.pet!.poops[0]
        XCTAssertEqual(game.scoop(poop.id), Rules.scoopReward)
        XCTAssertNil(game.scoop(poop.id))
        XCTAssertEqual(game.coins, Rules.startingCoins + Rules.scoopReward)
    }

    func testBathAndParkRewards() {
        var game = makeGame()
        game.pet!.needs.hygiene = 10
        XCTAssertEqual(game.finishBath(useShampoo: false, now: t0), Rules.bathReward)
        XCTAssertEqual(game.pet!.needs.hygiene, 100)
        game.finishPark(coinsFound: 12, now: t0)
        XCTAssertEqual(game.coins, Rules.startingCoins + Rules.bathReward + 12)
        XCTAssertLessThan(game.pet!.needs.hygiene, 100)
    }

    func testMedicineCuresOnlyWhenSickAndOwned() {
        var game = makeGame()
        XCTAssertFalse(game.giveMedicine(now: t0))
        XCTAssertEqual(game.buy("medicine"), .bought)
        XCTAssertFalse(game.giveMedicine(now: t0), "Healthy pets don't need pills")
        XCTAssertEqual(game.count(of: "medicine"), 1)
    }

    func testDailyGiftOncePerDayWithStreak() {
        var game = makeGame()
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        XCTAssertEqual(game.claimDailyGift(now: t0, calendar: calendar), 20)
        XCTAssertNil(game.claimDailyGift(now: t0 + 60, calendar: calendar))
        XCTAssertEqual(game.claimDailyGift(now: t0 + hours(24), calendar: calendar), 25)
        XCTAssertEqual(game.claimDailyGift(now: t0 + hours(48), calendar: calendar), 30)
        XCTAssertEqual(game.claimDailyGift(now: t0 + hours(24 * 5), calendar: calendar), 20, "Missed days reset the streak")
    }

    func testPiggyBankFillsWhileHappyAndIsCapped() {
        var game = makeGame()
        game.pet!.needs = Needs(hunger: 100, thirst: 100, energy: 100, hygiene: 100, fun: 100, love: 100)
        game.advance(to: t0 + hours(2))
        XCTAssertEqual(game.piggyBank, 2 * Rules.piggyRatePerHour, accuracy: 0.01)
        XCTAssertEqual(game.collectPiggyBank(), 6)
        XCTAssertEqual(game.coins, Rules.startingCoins + 6)
        XCTAssertEqual(game.piggyBank, 0, accuracy: 0.01)
    }

    func testGoodbyeMovesPetToMemorial() {
        var game = makeGame()
        game.advance(to: t0 + hours(24 * 10))
        XCTAssertFalse(game.pet!.isAlive)
        game.sayGoodbye()
        XCTAssertNil(game.pet)
        XCTAssertEqual(game.memorial.count, 1)
        let entry = game.memorial[0]
        XCTAssertEqual(entry.name, "Mochi Starfizz")
        XCTAssertEqual(entry.cause, .starvation)
        XCTAssertTrue(entry.epitaph.contains("Missed us"))
        game.lightCandle(for: entry.id)
        XCTAssertEqual(game.memorial[0].candles, 1)
        XCTAssertTrue(game.adopt(genome: Genome(seed: 9), name: "Pip", now: t0 + hours(240)))
    }

    func testGoodbyeIgnoredForLivingPet() {
        var game = makeGame()
        game.sayGoodbye()
        XCTAssertNotNil(game.pet)
        XCTAssertTrue(game.memorial.isEmpty)
    }

    func testDecorPlaceMovePutAway() {
        var game = makeGame()
        game.earn(500)
        XCTAssertEqual(game.buy("sofa"), .bought)
        let baseCosiness = game.cosiness
        let placed = game.place("sofa", x: 0.5, y: 2)!
        XCTAssertEqual(placed.y, 1, "Positions are clamped into the room")
        XCTAssertEqual(game.count(of: "sofa"), 0)
        XCTAssertGreaterThan(game.cosiness, baseCosiness)
        XCTAssertNil(game.place("sofa", x: 0.1, y: 0.1), "Only one sofa owned")
        XCTAssertNil(game.place("kibble", x: 0.1, y: 0.1), "Food is not decor")
        game.move(placed.id, x: 0.2, y: 0.3)
        XCTAssertEqual(game.room[0].x, 0.2)
        game.flip(placed.id)
        XCTAssertTrue(game.room[0].flipped)
        game.putAway(placed.id)
        XCTAssertTrue(game.room.isEmpty)
        XCTAssertEqual(game.count(of: "sofa"), 1)
    }

    func testCatalogIsConsistent() {
        XCTAssertEqual(Set(Catalog.items.map(\.id)).count, Catalog.items.count, "Item IDs are unique")
        for aisle in Aisle.allCases {
            XCTAssertFalse(Catalog.items(in: aisle).isEmpty, "\(aisle) aisle is empty")
        }
        for category in DecorCategory.allCases {
            XCTAssertFalse(Catalog.decor(in: category).isEmpty, "\(category) has no decor")
        }
        XCTAssertTrue(Catalog.items.allSatisfy { $0.price > 0 && $0.packSize > 0 })
    }

    func testSaveAndLoadRoundTrip() throws {
        var game = makeGame()
        _ = game.feed("kibble", now: t0)
        game.advance(to: t0 + hours(3))
        let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString).appendingPathComponent("save.json")
        try SaveFile.save(game, to: url)
        XCTAssertEqual(SaveFile.load(from: url), game)
    }
}
