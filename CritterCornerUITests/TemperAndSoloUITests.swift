import XCTest

/// Leaves the sötis alone to see it live its own life, and pesters it until it loses its temper.
/// Set SNAPSHOT_DIR to keep the screenshots.
final class TemperAndSoloUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-muted", "YES", "-resetSave", "YES", "-demoPet", "YES"]
        app.launch()
    }

    private var critter: XCUIElement { app.descendants(matching: .any)["critter"].firstMatch }
    private var state: String { (critter.value as? String) ?? "" }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        let attachment = XCTAttachment(screenshot: shot)
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
        if let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("ui-\(name).png"))
        }
    }

    /// Polls with short sleeps; expectations only check about once a second.
    private func waitUntil(_ timeout: TimeInterval, every: TimeInterval = 0.5, _ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            Thread.sleep(forTimeInterval: every)
        }
        return condition()
    }

    func testLeftAloneItFindsSomethingToDoAndATouchInterruptsIt() {
        XCTAssertTrue(critter.waitForExistence(timeout: 5))
        snap("solo-01-start")
        XCTAssertTrue(waitUntil(90) { state.contains("solo-") }, "left alone, it should start doing its own thing")
        Thread.sleep(forTimeInterval: 4)
        snap("solo-02-busy-\(state.replacingOccurrences(of: " ", with: "-"))")
        Thread.sleep(forTimeInterval: 4)
        snap("solo-03-still-busy")
        critter.tap()
        XCTAssertTrue(waitUntil(3) { !state.contains("solo-") }, "a touch makes it stop and notice you")
    }

    func testPesteringMakesItGrumpyThenSadThenFurious() {
        XCTAssertTrue(critter.waitForExistence(timeout: 5))
        // Looking the critter up is slow, so find it once and touch fixed points. Touching keeps it in place.
        let origin = app.coordinate(withNormalizedOffset: .zero)
        let frame = critter.frame
        func at(_ dx: CGFloat, _ dy: CGFloat) -> XCUICoordinate {
            origin.withOffset(CGVector(dx: frame.minX + frame.width * dx, dy: frame.minY + frame.height * dy))
        }
        // Pet it far past full love, until it wants to be left alone.
        var grumpy = false
        for _ in 0..<6 where !grumpy {
            for _ in 0..<8 {
                at(0.15, 0.5).press(forDuration: 0.05, thenDragTo: at(0.9, 0.5))
            }
            grumpy = state.hasPrefix("ignoring")
        }
        XCTAssertTrue(grumpy, "over-petting makes it grumpy, but it was \(state)")
        snap("temper-01-grumpy")

        var sawSad = false
        var furious = false
        for _ in 0..<16 where !furious {
            // It walks off when it wants space, so chase it.
            for _ in 0..<5 {
                critter.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)).tap()
                Thread.sleep(forTimeInterval: 1.6)
            }
            if state.hasPrefix("sad"), !sawSad {
                sawSad = true
                snap("temper-02-sad")
            }
            furious = state.hasPrefix("furious")
        }
        XCTAssertTrue(sawSad, "it gets sad before it gets furious")
        XCTAssertTrue(furious, "keep pestering and it goes bananas, but it was \(state)")
        Thread.sleep(forTimeInterval: 0.6)
        snap("temper-03-furious")
    }
}
