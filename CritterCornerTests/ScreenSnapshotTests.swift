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
            _ = state.adopt(genome: Genome(seed: 2024), name: "Mochi Stjärnbubbel", now: now)
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

    /// Every look side by side: sparkly, clean, dirty, filthy, sick, dying.
    func testConditions() throws {
        let genome = try XCTUnwrap(store.pet?.genome)
        func pet(hygiene: Double, sick: Bool = false, weight: Double = 50) -> Pet {
            var pet = Pet(name: "Test", genome: genome, now: .now)
            pet.needs.hygiene = hygiene
            pet.weight = weight
            if sick {
                for minute in 0..<5 { _ = pet.feed(FoodEffect(hunger: 1), at: .now.addingTimeInterval(Double(minute) * 60)) }
                pet.advance(to: .now.addingTimeInterval(9 * 3600))
                pet.needs.hygiene = hygiene
            }
            return pet
        }
        var bathed = pet(hygiene: 100)
        bathed.bathe(at: .now)
        let looks: [(String, Pet)] = [
            ("sparkly", bathed), ("normal", pet(hygiene: 70)), ("dirty", pet(hygiene: 35)),
            ("filthy", pet(hygiene: 5)), ("sick", pet(hygiene: 60, sick: true)), ("dying", pet(hygiene: 60, weight: 8)),
        ]
        let row = HStack(spacing: 10) {
            ForEach(looks, id: \.0) { name, pet in
                VStack {
                    LiveCritterView(genome: genome, expression: pet.expression(at: .now), weight: pet.weight, shine: pet.shine(at: .now), condition: pet.condition(at: .now), coat: .everyday(for: pet))
                        .frame(width: 180, height: 180)
                    Text(name).font(.cute(18))
                }
            }
        }
        .padding(20)
        .background(Color.cream)
        try render("conditions", row, size: CGSize(width: 1180, height: 260))
    }

    /// Twelve critters in different moods, to judge the art style at a glance.
    func testGallery() throws {
        let moods: [Mood] = [.content, .happy, .excited, .content, .hungry, .sad, .content, .excited, .sleepy, .content, .happy, .ignoring]
        let grid = VStack(spacing: 6) {
            ForEach(0..<2, id: \.self) { row in
                HStack(spacing: 6) {
                    ForEach(0..<6, id: \.self) { column in
                        let index = row * 6 + column
                        let genome = Genome(seed: UInt64(index * 7919 + 11))
                        CritterView(genome: genome, expression: moods[index])
                            .frame(width: 180, height: 180)
                            .background(RoundedRectangle(cornerRadius: 24).fill(Color(hex: genome.palette.stage)))
                    }
                }
            }
        }
        .padding(16)
        .background(Color.cream)
        try render("gallery", grid, size: CGSize(width: 1180, height: 410))
    }

    /// The same critters in all four styles, in a few moods and conditions.
    func testStyles() throws {
        let genomes = [Genome(seed: 31), Genome(seed: 7919 * 3 + 11), Genome(seed: 2024)]
        let moods: [Mood] = [.content, .excited, .happy]
        let sheet = VStack(spacing: 8) {
            ForEach(CritterStyle.allCases, id: \.self) { style in
                HStack(spacing: 8) {
                    Text(style.title).font(.cute(18, .bold)).frame(width: 110, alignment: .leading)
                    ForEach(0..<3, id: \.self) { index in
                        CritterView(genome: genomes[index], expression: moods[index], style: style)
                            .frame(width: 150, height: 150)
                    }
                    CritterView(genome: genomes[0], expression: .asleep, style: style).frame(width: 150, height: 150)
                    CritterView(genome: genomes[1], expression: .sad, coat: CritterCoat(mud: BathSession(seed: genomes[1].seed, dirtiness: 0.9).dirt), style: style).frame(width: 150, height: 150)
                    CritterView(genome: genomes[2], expression: .sick, coat: CritterCoat(sickly: true), style: style).frame(width: 150, height: 150)
                }
            }
        }
        .padding(16)
        .background(Color.cream)
        try render("styles", sheet, size: CGSize(width: 1180, height: 680))
    }

    func testLongSpeechWrapsInsteadOfGrowing() throws {
        let bubble = SpeechBubble(text: "Inte tillräckligt med mynt! Plocka bajs eller lek i parken för att tjäna mer.", maxWidth: 280)
        let renderer = ImageRenderer(content: bubble)
        let size = try XCTUnwrap(renderer.uiImage).size
        XCTAssertLessThanOrEqual(size.width, 290)
        XCTAssertGreaterThan(size.height, 60, "Long lines wrap onto several rows")
    }

    func testHomePortraitMini() throws { try render("home-portrait-mini", HomeView(), size: CGSize(width: 744, height: 1133)) }
}
