import XCTest

/// Walks through the wide park and plays with everything: swings, slide, sandbox, ducks, butterflies, ice cream.
/// Set TEST_RUNNER_SNAPSHOT_DIR to keep the screenshots.
final class ParkZonesUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUp() {
        continueAfterFailure = false
        XCUIDevice.shared.orientation = .landscapeLeft
        app = XCUIApplication()
        app.launchArguments = ["-muted", "YES", "-resetSave", "YES", "-demoPet", "YES", "-screen", "park"]
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

    /// Like a finger: element taps miss things in positioned layers.
    private func touch(_ id: String) {
        element(id).coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
    }

    private func page(right: Bool, times: Int) {
        for _ in 0..<times {
            let arrow = element(right ? "scroll-right" : "scroll-left")
            guard arrow.exists else { return }
            arrow.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            Thread.sleep(forTimeInterval: 1.3)
        }
    }

    private func waitUntil(_ timeout: TimeInterval, _ condition: () -> Bool) -> Bool {
        let end = Date().addingTimeInterval(timeout)
        while Date() < end {
            if condition() { return true }
            Thread.sleep(forTimeInterval: 0.3)
        }
        return condition()
    }

    private var petState: String { (element("park-pet").value as? String) ?? "" }

    func testPlayAllOverThePark() {
        XCTAssertTrue(element("scroll-right").waitForExistence(timeout: 5))
        page(right: true, times: 1)
        snap("zones-01-playground")

        touch("park-swing")
        XCTAssertTrue(waitUntil(8) { petState == "gungar" }, "it walks over and sits on the swing")
        for _ in 0..<5 {
            touch("park-swing")
            Thread.sleep(forTimeInterval: 0.5)
        }
        snap("zones-02-swinging")

        touch("park-slide")
        XCTAssertTrue(waitUntil(8) { petState == "åker rutschkana" }, "off the swing and up the slide")
        Thread.sleep(forTimeInterval: 1.4)
        snap("zones-03-sliding")
        Thread.sleep(forTimeInterval: 2)

        for _ in 0..<4 {
            touch("park-sandbox")
            Thread.sleep(forTimeInterval: 1.4)
        }
        snap("zones-04-sandcastle")

        page(right: true, times: 2)
        touch("park-pond")
        Thread.sleep(forTimeInterval: 0.4)
        touch("park-pond")
        Thread.sleep(forTimeInterval: 2.5)
        snap("zones-05-ducks")

        let butterfly = element("butterfly-0")
        if butterfly.exists {
            butterfly.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).tap()
            Thread.sleep(forTimeInterval: 2.5)
            snap("zones-06-butterfly")
        }

        touch("park-kiosk")
        Thread.sleep(forTimeInterval: 3)
        snap("zones-07-ice-cream")
    }

    func testCarryTheSötisOntoTheSwing() {
        let pet = element("park-pet")
        XCTAssertTrue(pet.waitForExistence(timeout: 5))
        page(right: true, times: 1)
        touch("park-swing")
        XCTAssertTrue(waitUntil(8) { petState == "gungar" })

        // Lift it off the swing and put it down on the grass beside it…
        let swing = element("park-swing")
        pet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
            .press(forDuration: 0.9, thenDragTo: swing.coordinate(withNormalizedOffset: CGVector(dx: 1.15, dy: 0.5)), withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(waitUntil(3) { petState != "gungar" }, "picked up off the swing")
        Thread.sleep(forTimeInterval: 1.5)
        snap("zones-08-carried-off-the-swing")

        // …then carry it back and drop it on the swing.
        pet.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45))
            .press(forDuration: 0.9, thenDragTo: swing.coordinate(withNormalizedOffset: CGVector(dx: 0.3, dy: 0.4)), withVelocity: .slow, thenHoldForDuration: 0.3)
        XCTAssertTrue(waitUntil(3) { petState == "gungar" }, "dropped on the swing, it sits down to swing")
        snap("zones-09-carried-to-swing")
    }
}
