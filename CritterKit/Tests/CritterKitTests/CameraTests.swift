import XCTest
@testable import CritterKit

final class CameraTests: XCTestCase {
    private func settle(_ camera: inout Camera, seconds: Double = 3) {
        for _ in 0..<Int(seconds * 60) { camera.step(1 / 60) }
    }

    func testPanningStaysInsideTheWorld() {
        var camera = Camera(worldWidth: 2400, viewportWidth: 1200)
        camera.pan(by: 300)
        XCTAssertEqual(camera.x, 0, "can't look past the left wall")
        camera.pan(by: -500)
        XCTAssertEqual(camera.x, 500)
        camera.pan(by: -5000)
        XCTAssertEqual(camera.x, 1200, "can't look past the right wall")
        XCTAssertFalse(camera.canScrollRight)
        XCTAssertTrue(camera.canScrollLeft)
    }

    func testAFlingKeepsSlidingThenStops() {
        var camera = Camera(worldWidth: 3600, viewportWidth: 1200)
        camera.fling(velocity: -1500)
        camera.step(0.1)
        let early = camera.x
        XCTAssertGreaterThan(early, 0)
        settle(&camera)
        XCTAssertGreaterThan(camera.x, early)
        XCTAssertEqual(camera.velocity, 0)
        XCTAssertLessThanOrEqual(camera.x, camera.maxX)
    }

    func testItFollowsTheSötisButNotRightAfterYouSwipe() {
        var camera = Camera(worldWidth: 2400, viewportWidth: 1200)
        camera.follow(600)
        settle(&camera)
        XCTAssertEqual(camera.x, 0, "a sötis near the middle doesn't move the camera")

        camera.pan(by: 0)
        camera.follow(1500)
        settle(&camera, seconds: 1)
        XCTAssertEqual(camera.x, 0, "it waits after you touched the screen")

        settle(&camera, seconds: Camera.followPause)
        camera.follow(1500)
        settle(&camera)
        XCTAssertTrue(camera.isVisible(1500, margin: -100), "now it keeps the sötis on screen")
    }

    func testItDoesNotDragYouBackToASötisYouLeftBehind() {
        var camera = Camera(worldWidth: 3600, viewportWidth: 1200, x: 2400)
        settle(&camera, seconds: Camera.followPause + 1)
        camera.follow(300)
        settle(&camera)
        XCTAssertEqual(camera.x, 2400, "you scrolled away on purpose")
    }

    func testPagingGlidesAScreenOver() {
        var camera = Camera(worldWidth: 2400, viewportWidth: 1200)
        camera.page(right: true)
        settle(&camera)
        XCTAssertEqual(camera.x, 960, accuracy: 1)
        camera.page(right: true)
        settle(&camera)
        XCTAssertEqual(camera.x, 1200, accuracy: 1)
        camera.center(on: 0)
        settle(&camera)
        XCTAssertEqual(camera.x, 0, accuracy: 1)
    }

    func testAWorldNarrowerThanTheScreenNeverScrolls() {
        var camera = Camera(worldWidth: 800, viewportWidth: 1200)
        camera.pan(by: -400)
        XCTAssertEqual(camera.x, 0)
        XCTAssertFalse(camera.canScrollRight)
    }
}

final class WideRoomMigrationTests: XCTestCase {
    func testOldSavesKeepTheirFurnitureWhereItWas() throws {
        var game = makeGame()
        game.earn(1000)
        XCTAssertEqual(game.buy("bookshelf"), .bought)
        let placed = try XCTUnwrap(game.place("bookshelf", x: 0.5, y: 0.6))
        var json = try JSONSerialization.jsonObject(with: SaveFile.encode(game)) as! [String: Any]
        json["version"] = 1
        let loaded = try SaveFile.decode(JSONSerialization.data(withJSONObject: json))
        let decor = try XCTUnwrap(loaded.room.first { $0.id == placed.id })
        XCTAssertEqual(decor.x, 0.5 / Rules.roomScreens, accuracy: 0.0001, "same spot, now in the left half of the wide room")
        XCTAssertEqual(decor.y, 0.6, accuracy: 0.0001)
        XCTAssertEqual(loaded.version, GameState.currentVersion)

        let again = try SaveFile.decode(SaveFile.encode(loaded))
        XCTAssertEqual(again.room.first?.x ?? 0, decor.x, accuracy: 0.0001, "migrates only once")
    }
}

