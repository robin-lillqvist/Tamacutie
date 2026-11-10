import XCTest

/// Gives the critter a full bath in a landscape simulator. Set TEST_RUNNER_SNAPSHOT_DIR to keep screenshots.
/// Points are in the 1194-wide design space, converted to the screen.
final class BathUITests: XCTestCase {
    private var app: XCUIApplication!
    private var designHeight: CGFloat = 830

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-resetSave", "YES", "-demoPet", "YES", "-screen", "bath"]
        app.launch()
        let frame = app.windows.firstMatch.frame
        designHeight = frame.height * 1194 / frame.width
    }

    private func snap(_ name: String) {
        let shot = XCUIScreen.main.screenshot()
        add(XCTAttachment(screenshot: shot))
        if let dir = ProcessInfo.processInfo.environment["SNAPSHOT_DIR"] {
            try? shot.pngRepresentation.write(to: URL(fileURLWithPath: dir).appendingPathComponent("bath-\(name).png"))
        }
    }

    private func at(_ x: CGFloat, _ y: CGFloat) -> XCUICoordinate {
        app.coordinate(withNormalizedOffset: CGVector(dx: x / 1194, dy: y / designHeight))
    }

    private var tubTop: CGFloat { designHeight * 0.64 }

    /// Picks the tool up where it lies, then rubs it back and forth over the critter.
    private func rub(from start: CGPoint, passes: Int) {
        var current = start
        for _ in 0..<passes {
            for y in stride(from: tubTop - 160, through: tubTop - 40, by: 20) {
                for x: CGFloat in [500, 700] {
                    at(current.x, current.y).press(forDuration: 0.02, thenDragTo: at(x, y), withVelocity: 700, thenHoldForDuration: 0)
                    current = CGPoint(x: x, y: y)
                }
            }
        }
    }

    func testAFullBath() {
        let tap = app.buttons["tap"]
        XCTAssertTrue(tap.waitForExistence(timeout: 5))
        snap("1-dirty")
        tap.tap()
        Thread.sleep(forTimeInterval: 1.2)
        snap("2-filling")
        Thread.sleep(forTimeInterval: 2)

        at(460, tubTop - 14).press(forDuration: 0.02, thenDragTo: at(560, tubTop - 120), withVelocity: 600, thenHoldForDuration: 0)
        snap("3-scrubbing")
        rub(from: CGPoint(x: 560, y: tubTop - 120), passes: 6)
        snap("4-foamy")

        app.buttons["shower"].tap()
        Thread.sleep(forTimeInterval: 1)
        snap("5-shower-on")
        var headX: CGFloat = 780
        for x: CGFloat in [520, 680, 560, 640, 600] {
            at(headX, 170).press(forDuration: 0.05, thenDragTo: at(x, 170), withVelocity: 300, thenHoldForDuration: 1.2)
            headX = x
        }
        snap("6-rinsed")

        rub(from: CGPoint(x: 1080, y: 300), passes: 4)
        Thread.sleep(forTimeInterval: 0.3)
        snap("7-shake")
        XCTAssertTrue(app.buttons["Skinande ren! Gå hem"].waitForExistence(timeout: 4), "The bath should be finished")
        Thread.sleep(forTimeInterval: 1.5)
        snap("8-sparkly")
    }
}
