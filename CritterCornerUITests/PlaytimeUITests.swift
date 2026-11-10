import XCTest

/// Plays the game in a landscape simulator. Set TEST_RUNNER_SNAPSHOT_DIR to keep the screenshots.
final class PlaytimeUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-resetSave", "YES", "-demoPet", "YES"]
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

    private func point(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: x, dy: y))
    }

    func testFetchWithTheBall() {
        XCTAssertTrue(app.buttons["Leka"].waitForExistence(timeout: 5))
        snap("01-home")
        app.buttons["Leka"].tap()
        let ball = app.descendants(matching: .any)["ball"].firstMatch
        XCTAssertTrue(ball.waitForExistence(timeout: 3))
        snap("02-play-ready")
        ball.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.05, thenDragTo: point(0.9, 0.35), withVelocity: .fast, thenHoldForDuration: 0)
        Thread.sleep(forTimeInterval: 0.6)
        snap("03-ball-flying")
        Thread.sleep(forTimeInterval: 1.4)
        snap("04-chasing")
        Thread.sleep(forTimeInterval: 3)
        snap("05-delivered")
        let count = app.staticTexts["play-count"]
        let fetched = expectation(for: NSPredicate(format: "label != '0'"), evaluatedWith: count)
        wait(for: [fetched], timeout: 10)
    }

    func testBubblesPettingAndFeeding() {
        XCTAssertTrue(app.buttons["Leka"].waitForExistence(timeout: 5))
        app.buttons["Leka"].tap()
        app.buttons["Bubblor"].tap()
        for x in [0.35, 0.65, 0.8] {
            point(x, 0.4).tap()
        }
        Thread.sleep(forTimeInterval: 1.2)
        snap("06-bubbles")
        Thread.sleep(forTimeInterval: 4)
        snap("07-bubbles-later")
        app.buttons["Klar"].tap()

        let critter = app.descendants(matching: .any)["critter"].firstMatch
        XCTAssertTrue(critter.waitForExistence(timeout: 3))
        let center = critter.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
        center.press(forDuration: 0.05, thenDragTo: critter.coordinate(withNormalizedOffset: CGVector(dx: 0.9, dy: 0.45)))
        snap("08-petting")

        app.buttons["Mata"].tap()
        let kibble = app.descendants(matching: .any)["food-kibble"].firstMatch
        XCTAssertTrue(kibble.waitForExistence(timeout: 3))
        snap("09-fridge")
        kibble.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).press(forDuration: 0.1, thenDragTo: critter.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.55)))
        Thread.sleep(forTimeInterval: 0.3)
        snap("10-fed")
    }
}
