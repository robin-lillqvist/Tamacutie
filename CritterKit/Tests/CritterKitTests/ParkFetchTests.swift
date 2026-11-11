import XCTest
@testable import CritterKit

final class ParkFetchTests: XCTestCase {
    private let layout = ParkFetch.Layout(groundY: 640, hand: Point2(130, 560), minX: 340, maxX: 1060, friendX: 1040, catchHeight: 190)

    /// Runs the game at 60 fps, like the screen does, collecting events.
    private func run(_ game: inout ParkFetch, from t: inout Double, seconds: Double, until stop: ((ParkFetch, Double) -> Bool)? = nil) -> [ParkFetch.Event] {
        var events: [ParkFetch.Event] = []
        let dt = 1.0 / 60
        let end = t + seconds
        while t < end {
            t += dt
            events += game.update(to: t, dt: dt)
            if let stop, stop(game, t) { break }
        }
        return events
    }

    func testYourSotisAlwaysCatchesWhereverYouThrow() {
        for x in [0.0, 340, 600, 900, 1060, 3000] {
            var t = 0.0
            var game = ParkFetch(layout: layout, petX: 560, now: t)
            XCTAssertTrue(game.throwBall(towardX: x, at: t))
            let events = run(&game, from: &t, seconds: 3) { game, _ in if case .held(.pet, _) = game.ball { true } else { false } }
            XCTAssertEqual(events, [.caught(by: .pet)], "throw to \(x)")
            XCTAssertEqual(game.catches, 1)
            XCTAssertEqual(game.petX, min(1060, max(340, x)), accuracy: 0.001)
        }
    }

    func testThePetRunsThereBeforeTheBallLands() {
        var t = 0.0
        var game = ParkFetch(layout: layout, petX: 340, now: t)
        game.throwBall(towardX: 1060, at: t)
        guard case .flying(let flight) = game.ball else { return XCTFail() }
        _ = run(&game, from: &t, seconds: flight.duration - 0.1)
        XCTAssertEqual(game.petX, 1060, accuracy: 1, "should already be under the ball")
    }

    func testCannotThrowTwice() {
        var game = ParkFetch(layout: layout, petX: 560, now: 0)
        XCTAssertTrue(game.throwBall(towardX: 700, at: 0))
        XCTAssertFalse(game.throwBall(towardX: 800, at: 0.1))
    }

    func testThePetThrowsItBackAndATapNearTheBallCatchesIt() {
        var t = 0.0
        var game = ParkFetch(layout: layout, petX: 560, now: t)
        game.throwBall(towardX: 800, at: t)
        let events = run(&game, from: &t, seconds: 5) { $0.isComingToYou(at: $1) }
        XCTAssertEqual(events, [.caught(by: .pet), .thrown(by: .pet)])

        // A miss far away does nothing; a sloppy tap near the ball still counts.
        t += 0.4
        XCTAssertFalse(game.tryCatch(at: Point2(1100, 100), at: t))
        let ball = game.ballPosition(at: t)
        XCTAssertTrue(game.tryCatch(at: Point2(ball.x + 90, ball.y + 80), at: t))
        XCTAssertTrue(game.canThrow)
        XCTAssertEqual(game.catches, 2)
        XCTAssertEqual(game.streak, 1)
    }

    func testATapWhereTheBallJustWasStillCatchesIt() {
        var t = 0.0
        var game = ParkFetch(layout: layout, petX: 900, now: t)
        game.joinFriend()
        game.throwBall(towardX: 860, at: t)
        _ = run(&game, from: &t, seconds: 12) { game, now in game.isComingToYou(at: now) }
        t += 0.6
        let earlier = game.ballPosition(at: t - 0.5)
        XCTAssertTrue(game.tryCatch(at: earlier, at: t))
    }

    func testTappingTheHandAsTheBallArrivesCatchesIt() {
        var t = 0.0
        var game = ParkFetch(layout: layout, petX: 560, now: t)
        game.throwBall(towardX: 600, at: t)
        _ = run(&game, from: &t, seconds: 5) { game, _ in if case .flying(let f) = game.ball, f.catcher == .you { true } else { false } }
        guard case .flying(let back) = game.ball else { return XCTFail() }
        XCTAssertTrue(game.tryCatch(at: layout.hand, at: back.end - 0.05))
    }

    func testATapJustAfterItLandsStillCounts() {
        var t = 0.0
        var game = ParkFetch(layout: layout, petX: 560, now: t)
        game.throwBall(towardX: 600, at: t)
        _ = run(&game, from: &t, seconds: 5) { game, _ in if case .flying(let f) = game.ball, f.catcher == .you { true } else { false } }
        guard case .flying(let back) = game.ball else { return XCTFail() }
        t = back.end
        _ = run(&game, from: &t, seconds: ParkFetch.landingGrace - 0.1)
        XCTAssertTrue(game.tryCatch(at: layout.hand, at: t))
    }

    func testAMissedBallStillComesHomeSoYouCanThrowAgain() {
        var t = 0.0
        var game = ParkFetch(layout: layout, petX: 560, now: t)
        game.throwBall(towardX: 700, at: t)
        let events = run(&game, from: &t, seconds: 8) { game, _ in game.canThrow }
        XCTAssertEqual(events, [.caught(by: .pet), .thrown(by: .pet), .dropped])
        XCTAssertEqual(game.streak, 0)
        XCTAssertTrue(game.throwBall(towardX: 500, at: t))
    }

    func testTheFriendJoinsAndTheBallGoesAround() {
        var t = 0.0
        var game = ParkFetch(layout: layout, petX: 560, now: t)
        XCTAssertTrue(game.joinFriend())
        XCTAssertFalse(game.joinFriend())
        game.throwBall(towardX: 2000, at: t)
        XCTAssertEqual(game.petTargetX, 1040 - ParkFetch.friendGap, "never runs into the friend")
        let events = run(&game, from: &t, seconds: 10) { $0.isComingToYou(at: $1) }
        XCTAssertEqual(events, [.caught(by: .pet), .thrown(by: .pet), .caught(by: .friend), .thrown(by: .friend)])
        guard case .flying(let flight) = game.ball else { return XCTFail() }
        XCTAssertEqual(flight.thrower, .friend)
        XCTAssertLessThanOrEqual(abs(flight.to.x - flight.from.x) / flight.duration, ParkFetch.throwToYouSpeed + 0.001, "a long throw is still slow enough to catch")
        XCTAssertEqual(game.catches, 2)
    }

    func testThePetStepsAsideWhenTheFriendJoins() {
        var t = 0.0
        var game = ParkFetch(layout: layout, petX: 1000, now: t)
        game.joinFriend()
        _ = run(&game, from: &t, seconds: 2)
        XCTAssertLessThanOrEqual(game.petX, 1040 - ParkFetch.friendGap + 0.001)
    }

    func testCritterHopsUpToMeetTheBall() {
        var game = ParkFetch(layout: layout, petX: 560, now: 0)
        game.throwBall(towardX: 560, at: 0)
        guard case .flying(let flight) = game.ball else { return XCTFail() }
        XCTAssertEqual(game.hop(.pet, at: 0.1), 0)
        XCTAssertGreaterThan(game.hop(.pet, at: flight.end - 0.05), 30)
    }
}
