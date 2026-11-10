import XCTest
@testable import CritterKit

final class ShineTests: XCTestCase {
    func testNoShineBeforeABath() {
        XCTAssertEqual(makePet().shine(at: t0), 0)
    }

    func testBathMakesPetShineAndItFades() {
        var pet = makePet()
        pet.bathe(at: t0)
        XCTAssertEqual(pet.shine(at: t0), 1, accuracy: 0.001)
        let halfway = t0 + Rules.shineDuration / 2
        pet.advance(to: halfway)
        XCTAssertEqual(pet.shine(at: halfway), 0.5, accuracy: 0.01)
        let after = t0 + Rules.shineDuration + 60
        pet.advance(to: after)
        XCTAssertEqual(pet.shine(at: after), 0)
    }

    func testShampooShinesLonger() {
        var plain = makePet()
        var shampooed = makePet()
        plain.bathe(at: t0)
        shampooed.bathe(at: t0, shampoo: true)
        let later = t0 + Rules.shineDuration
        XCTAssertEqual(plain.shine(at: later), 0)
        XCTAssertGreaterThan(shampooed.shine(at: later), 0.5)
    }

    func testDirtTakesTheShineAway() {
        var pet = makePet()
        pet.bathe(at: t0)
        pet.needs.hygiene = 40
        XCTAssertEqual(pet.shine(at: t0), 0)
    }

    func testFinishingABathWithShampooUsesItAndShinesLonger() {
        var game = makeGame()
        XCTAssertEqual(game.buy("shampoo"), .bought)
        let bottles = game.count(of: "shampoo")
        _ = game.finishBath(useShampoo: true, now: t0)
        XCTAssertEqual(game.count(of: "shampoo"), bottles - 1)
        XCTAssertGreaterThan(game.pet!.shine(at: t0 + Rules.shineDuration), 0)
    }

    func testOldSavesWithoutShineStillLoad() throws {
        let game = makeGame()
        var json = try JSONSerialization.jsonObject(with: SaveFile.encode(game)) as! [String: Any]
        var pet = json["pet"] as! [String: Any]
        pet.removeValue(forKey: "shineStart")
        pet.removeValue(forKey: "shineEnd")
        json["pet"] = pet
        let loaded = try SaveFile.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(loaded.pet?.shine(at: t0), 0)
    }
}
