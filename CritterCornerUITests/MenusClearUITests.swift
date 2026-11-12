import XCTest

/// Menus must never cover the sötis in their default positions.
final class MenusClearUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-resetSave", "YES", "-demoPet", "YES"]
        app.launch()
    }

    private func element(_ id: String) -> XCUIElement { app.descendants(matching: .any)[id].firstMatch }

    /// The drawn body sits inside the critter's square frame, with room around it for ears and hops.
    private var body: CGRect {
        let frame = element("critter").frame
        return frame.insetBy(dx: frame.width * 0.15, dy: frame.height * 0.12)
    }

    private func assertClear(_ ids: [String], _ moment: String, file: StaticString = #filePath, line: UInt = #line) {
        let critter = body
        for id in ids {
            let menu = element(id)
            XCTAssertTrue(menu.waitForExistence(timeout: 3), "\(id) missing", file: file, line: line)
            XCTAssertFalse(menu.frame.intersects(critter), "\(id) covers the sötis \(moment): \(menu.frame) over \(critter)", file: file, line: line)
        }
    }

    func testMenusNeverCoverTheSötis() {
        XCTAssertTrue(element("critter").waitForExistence(timeout: 5))
        // Touch it so it stands still where it starts.
        element("critter").press(forDuration: 0.2)
        assertClear(["needs", "dock"], "at home")

        app.buttons["Mata"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        assertClear(["fridge-tray", "needs", "dock"], "with the fridge open")
        app.buttons["Mata"].tap()

        app.buttons["Leka"].tap()
        Thread.sleep(forTimeInterval: 0.6)
        assertClear(["play-count", "needs", "dock"], "while playing")
        app.buttons["Klar"].tap()

        app.buttons["Sova"].tap()
        Thread.sleep(forTimeInterval: 5)
        assertClear(["needs", "dock"], "asleep in bed")
    }
}
