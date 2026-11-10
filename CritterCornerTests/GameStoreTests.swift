import CritterKit
import XCTest
@testable import CritterCorner

@MainActor
final class GameStoreTests: XCTestCase {
    private var saveURL: URL!
    private var defaults: UserDefaults!
    private var fakeNow = Date(timeIntervalSince1970: 1_800_000_000)

    override func setUp() async throws {
        saveURL = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "save.json")
        defaults = UserDefaults(suiteName: UUID().uuidString)
        fakeNow = Date(timeIntervalSince1970: 1_800_000_000)
    }

    private func makeStore() -> GameStore {
        GameStore(saveURL: saveURL, defaults: defaults, clock: { [unowned self] in fakeNow })
    }

    func testFreshGameHasNoPet() {
        XCTAssertNil(makeStore().pet)
    }

    func testAdoptionIsSavedAndReloaded() {
        let store = makeStore()
        store.perform { state, now in _ = state.adopt(genome: Genome(seed: 7), name: "Pip Starfizz", now: now) }
        XCTAssertEqual(makeStore().pet?.name, "Pip Starfizz")
    }

    func testTimeKeepsPassingWhileTheAppIsClosed() {
        let store = makeStore()
        store.perform { state, now in _ = state.adopt(genome: Genome(seed: 7), name: "Pip", now: now) }
        let hunger = store.pet!.needs.hunger
        fakeNow += 4 * 3600
        let reopened = makeStore()
        XCTAssertLessThan(reopened.pet!.needs.hunger, hunger)
    }

    func testSkipAheadMovesTheClockAndPersists() {
        let store = makeStore()
        store.skipAhead(hours: 2)
        XCTAssertEqual(store.now, fakeNow + 7200)
        XCTAssertEqual(makeStore().now, fakeNow + 7200)
    }
}
