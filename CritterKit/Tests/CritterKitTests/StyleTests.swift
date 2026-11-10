import XCTest
@testable import CritterKit

final class StyleTests: XCTestCase {
    func testNewCrittersDefaultToVinyl() {
        XCTAssertEqual(makePet().appearance, .vinyl)
    }

    func testChosenStyleIsKeptThroughSaveAndMemorial() throws {
        var game = GameState(now: t0)
        XCTAssertTrue(game.adopt(genome: plainGenome(), name: "Pip", style: .plush, now: t0))
        let loaded = try SaveFile.decode(SaveFile.encode(game))
        XCTAssertEqual(loaded.pet?.appearance, .plush)
        game.advance(to: t0 + 10 * 86400)
        game.sayGoodbye()
        XCTAssertEqual(game.memorial.first?.appearance, .plush)
    }

    func testSavesFromBeforeStylesLoadAsVinyl() throws {
        let game = makeGame()
        var json = try JSONSerialization.jsonObject(with: SaveFile.encode(game)) as! [String: Any]
        var pet = json["pet"] as! [String: Any]
        pet.removeValue(forKey: "style")
        json["pet"] = pet
        let loaded = try SaveFile.decode(JSONSerialization.data(withJSONObject: json))
        XCTAssertEqual(loaded.pet?.appearance, .vinyl)
    }

    func testEveryStyleHasASwedishTitle() {
        XCTAssertEqual(Set(CritterStyle.allCases.map(\.title)).count, CritterStyle.allCases.count)
    }
}
