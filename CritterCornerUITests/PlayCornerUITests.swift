import XCTest

/// Swipes across the wide room to the play corner and plays there.
/// Set TEST_RUNNER_SNAPSHOT_DIR to keep the screenshots.
final class PlayCornerUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-muted", "YES", "-resetSave", "YES", "-demoPet", "YES"]
        app.launch()
    }

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

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    func testSwipeToThePlayCornerAndPlay() {
        let right = element("scroll-right")
        XCTAssertTrue(right.waitForExistence(timeout: 5))
        XCTAssertFalse(element("scroll-left").exists, "starts at the left wall")

        // Swipe the floor to look right.
        let floor = app.coordinate(withNormalizedOffset: CGVector(dx: 0.85, dy: 0.62))
        floor.press(forDuration: 0.05, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.2, dy: 0.62)), withVelocity: .fast, thenHoldForDuration: 0)
        XCTAssertTrue(element("scroll-left").waitForExistence(timeout: 3), "swiping scrolls the room")
        // Arrows glide the rest of the way, until the right wall.
        for _ in 0..<4 where right.exists {
            // A coordinate tap, like a finger: element taps miss these positioned buttons.
            right.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            Thread.sleep(forTimeInterval: 1.2)
        }
        XCTAssertFalse(right.exists, "reached the right wall")
        snap("corner-01-arrived")

        let bar = element("xylophone-5")
        XCTAssertTrue(bar.waitForExistence(timeout: 3))
        XCTAssertTrue(bar.isHittable, "the xylophone is on screen")
        for id in ["xylophone-0", "xylophone-2", "xylophone-4", "xylophone-5"] { element(id).tap() }
        snap("corner-02-music")

        element("slide").tap()
        Thread.sleep(forTimeInterval: 3.2)
        snap("corner-03-on-the-slide")
        Thread.sleep(forTimeInterval: 2.5)

        element("cushion").tap()
        Thread.sleep(forTimeInterval: 3.4)
        snap("corner-04-bouncing")
    }

    func testPickTheSötisUpAndPutItSomewhereElse() {
        let critter = element("critter")
        XCTAssertTrue(critter.waitForExistence(timeout: 5))
        let start = critter.frame.midX
        let target = app.coordinate(withNormalizedOffset: CGVector(dx: 0.28, dy: 0.45))
        critter.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
            .press(forDuration: 0.9, thenDragTo: target, withVelocity: .slow, thenHoldForDuration: 0.4)
        Thread.sleep(forTimeInterval: 1.5)
        snap("carry-01-dropped")
        let landed = critter.frame.midX
        XCTAssertLessThan(abs(landed - app.frame.width * 0.28), 90, "it lands where you let go (was at \(start), now \(landed))")
        XCTAssertGreaterThan(abs(landed - start), 120, "it really moved")
    }

    func testDropItOnTheCushionAndItBounces() {
        let right = element("scroll-right")
        XCTAssertTrue(right.waitForExistence(timeout: 5))
        let critter = element("critter")
        // Carry it to the right edge: the room scrolls along while you hold it there.
        critter.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
            .press(forDuration: 0.9, thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.97, dy: 0.4)), withVelocity: .slow, thenHoldForDuration: 3)
        Thread.sleep(forTimeInterval: 1)
        snap("carry-02-scrolled")
        for _ in 0..<3 where right.exists {
            right.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            Thread.sleep(forTimeInterval: 1.2)
        }
        let cushion = element("cushion")
        XCTAssertTrue(cushion.waitForExistence(timeout: 3))
        let over = cushion.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: -1.6))
        critter.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.4))
            .press(forDuration: 0.9, thenDragTo: over, withVelocity: .slow, thenHoldForDuration: 0.3)
        Thread.sleep(forTimeInterval: 1.2)
        snap("carry-03-bouncing")
        XCTAssertLessThan(abs(critter.frame.midX - cushion.frame.midX), 40, "it landed on the cushion")
    }
}
