import XCTest
@testable import CritterKit

final class BathSessionTests: XCTestCase {
    private func fill(_ bath: inout BathSession) {
        bath.turnOnTap()
        for _ in 0..<200 { if bath.update(1.0 / 60) { break } }
    }

    /// Sweeps the sponge over the whole body, like a kid would.
    private func scrubEverywhere(_ bath: inout BathSession, passes: Int = 30) {
        for _ in 0..<passes {
            for y in stride(from: 0.3, through: 0.88, by: 0.05) {
                for x in stride(from: 0.2, through: 0.8, by: 0.05) {
                    bath.scrub(at: x, y)
                }
            }
        }
    }

    func testDirtierCrittersHaveMoreMud() {
        XCTAssertGreaterThan(BathSession(seed: 1, dirtiness: 1).dirt.count, BathSession(seed: 1, dirtiness: 0).dirt.count)
        XCTAssertTrue(BathSession(seed: 1, dirtiness: 0.5).dirt.allSatisfy { (0...1).contains($0.x) && (0...1).contains($0.y) })
    }

    func testNothingHappensUntilTheTapIsOn() {
        var bath = BathSession(seed: 1, dirtiness: 0.5)
        XCTAssertFalse(bath.update(5))
        XCTAssertEqual(bath.water, 0)
        bath.scrub(at: 0.5, 0.5)
        XCTAssertTrue(bath.foam.isEmpty, "No scrubbing in an empty tub")
    }

    func testTubFillsOverTime() {
        var bath = BathSession(seed: 1, dirtiness: 0.5)
        bath.turnOnTap()
        _ = bath.update(BathSession.fillSeconds / 2)
        XCTAssertEqual(bath.water, 0.5, accuracy: 0.01)
        XCTAssertEqual(bath.step, .fill)
        XCTAssertTrue(bath.update(BathSession.fillSeconds))
        XCTAssertEqual(bath.step, .scrub)
        XCTAssertFalse(bath.isFilling)
    }

    func testScrubbingRemovesMudAndMakesFoam() {
        var bath = BathSession(seed: 3, dirtiness: 1)
        fill(&bath)
        let spot = bath.dirt[0]
        for _ in 0..<5 { bath.scrub(at: spot.x, spot.y) }
        XCTAssertLessThan(bath.dirt.first { $0.id == spot.id }?.amount ?? 0, spot.amount)
        XCTAssertFalse(bath.foam.isEmpty)
        XCTAssertGreaterThan(bath.stepProgress, 0)
    }

    func testScrubbingOffTheBodyMakesNoFoam() {
        var bath = BathSession(seed: 3, dirtiness: 1)
        fill(&bath)
        bath.scrub(at: 0.02, 0.05)
        XCTAssertTrue(bath.foam.isEmpty)
    }

    func testAFullBathRunsThroughEveryStep() {
        var bath = BathSession(seed: 9, dirtiness: 0.8)
        fill(&bath)
        scrubEverywhere(&bath)
        XCTAssertEqual(bath.step, .rinse)
        XCTAssertTrue(bath.dirt.isEmpty)
        XCTAssertEqual(bath.cleaned, 1, accuracy: 0.001)

        let foamCount = bath.foam.count
        bath.rinse(atX: 0.5, dt: 0.1)
        XCTAssertEqual(bath.foam.count, foamCount, "Rinsing takes a moment")
        for _ in 0..<200 {
            for x in stride(from: 0.2, through: 0.8, by: 0.1) { bath.rinse(atX: x, dt: 1.0 / 30) }
        }
        XCTAssertEqual(bath.step, .dry)
        XCTAssertFalse(bath.drops.isEmpty, "Rinsing leaves the critter wet")

        for _ in 0..<20 {
            for drop in bath.drops { bath.dry(at: drop.x, drop.y) }
        }
        XCTAssertEqual(bath.step, .done)
        XCTAssertEqual(bath.overallProgress, 1)
    }

    func testToolsOnlyWorkInTheirStep() {
        var bath = BathSession(seed: 2, dirtiness: 0.3)
        fill(&bath)
        bath.rinse(atX: 0.5, dt: 1)
        bath.dry(at: 0.5, 0.5)
        XCTAssertEqual(bath.step, .scrub)
    }
}
