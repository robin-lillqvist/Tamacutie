import CritterKit
import SwiftUI
import XCTest
@testable import CritterCorner

/// Renders every screen at landscape iPad size. Fails if a screen renders nothing;
/// set SNAPSHOT_DIR (TEST_RUNNER_SNAPSHOT_DIR for xcodebuild) to also save PNGs for a visual check.
@MainActor
final class ScreenSnapshotTests: XCTestCase {
    private var store: GameStore!

    override func setUp() async throws {
        let url = FileManager.default.temporaryDirectory.appending(path: UUID().uuidString).appending(path: "save.json")
        store = GameStore(saveURL: url, defaults: UserDefaults(suiteName: UUID().uuidString)!)
        store.perform { state, now in
            _ = state.adopt(genome: Genome(seed: 2024), name: "Mochi Starfizz", now: now)
            state.earn(400)
            _ = state.feed("kibble", now: now.addingTimeInterval(-3 * 3600))
        }
        store.skipAhead(hours: 1)
    }

    private func render<TView: View>(_ name: String, _ view: TView, size: CGSize = CGSize(width: 1180, height: 820)) throws {
        let host = view
            .environment(store)
            .environment(Toaster())
            .frame(width: size.width, height: size.height)
        let renderer = ImageRenderer(content: host)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.uiImage, "\(name) did not render")
        XCTAssertEqual(image.size.width, size.width)
        let data = try XCTUnwrap(image.pngData())
        XCTAssertGreaterThan(data.count, 20_000, "\(name) looks blank")
        if let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            try data.write(to: URL(fileURLWithPath: dir).appending(path: "\(name).png"))
        }
    }

    func testHome() throws { try render("home", HomeView()) }
    func testMarket() throws { try render("market", MarketView()) }
    func testBath() throws { try render("bath", BathView()) }
    func testPark() throws { try render("park", ParkView()) }
    func testDecor() throws { try render("decor", DecorView()) }
    func testMemoriam() throws { try render("memoriam", MemoriamView()) }
    func testAdopt() throws { try render("adopt", AdoptView()) }
    func testFarewell() throws {
        store.skipAhead(hours: 24 * 8)
        let pet = try XCTUnwrap(store.pet)
        XCTAssertFalse(pet.isAlive)
        try render("farewell", FarewellView(pet: pet))
    }
    func testShinyAfterBath() throws {
        store.perform { state, now in _ = state.finishBath(useShampoo: false, now: now) }
        XCTAssertEqual(store.pet?.shine(at: store.now) ?? 0, 1, accuracy: 0.01)
        try render("home-shiny", HomeView())
        try render("bath-shiny-zoom", LiveCritterView(genome: store.pet!.genome, expression: .happy, shine: 1).padding(40).background(Color.mintLight), size: CGSize(width: 400, height: 400))
    }

    func testHomePortraitMini() throws { try render("home-portrait-mini", HomeView(), size: CGSize(width: 744, height: 1133)) }
}
