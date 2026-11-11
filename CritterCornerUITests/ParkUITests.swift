import XCTest

/// Plays fetch in the park: throw, catch it when it comes back, then with the park friend.
final class ParkUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-resetSave", "YES", "-demoPet", "YES", "-screen", "park"]
        app.launch()
    }

    private func snap(_ name: String) {
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    private var ball: XCUIElement { app.descendants(matching: .any)["park-ball"].firstMatch }
    private var score: XCUIElement { app.staticTexts["park-score"] }

    /// Waits until the ball flies toward you, then taps it. Polls quickly: an expectation
    /// only checks about once a second, by which time the ball has landed.
    private func catchTheBall(timeout: TimeInterval = 8) {
        let deadline = Date().addingTimeInterval(timeout)
        while (ball.value as? String) != "fånga" {
            XCTAssertLessThan(Date(), deadline, "the ball never came back")
            Thread.sleep(forTimeInterval: 0.05)
        }
        ball.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func waitForScore(_ value: String) {
        let match = NSPredicate(format: "label == %@", value)
        let wait = XCTNSPredicateExpectation(predicate: match, object: score)
        XCTAssertEqual(XCTWaiter().wait(for: [wait], timeout: 3), .completed, "score is \(score.label), expected \(value)")
    }

    func testFetchWithYourSotisAndTheFriend() {
        XCTAssertTrue(ball.waitForExistence(timeout: 5))
        XCTAssertEqual(score.label, "0")

        // You throw; your sötis catches (1) and throws back; you catch (2).
        app.buttons["park-throw"].tap()
        catchTheBall()
        waitForScore("2")
        snap("park-1-caught")

        // Tap the friend so it joins: you → sötis → friend → you is three catches.
        let friend = app.descendants(matching: .any)["park-friend"].firstMatch
        XCTAssertTrue(friend.exists)
        friend.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
        Thread.sleep(forTimeInterval: 0.5)
        app.buttons["park-throw"].tap()
        catchTheBall(timeout: 10)
        waitForScore("5")
        snap("park-2-with-friend")
    }
}
