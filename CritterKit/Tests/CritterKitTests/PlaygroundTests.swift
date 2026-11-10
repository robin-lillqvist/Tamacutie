import XCTest
@testable import CritterKit

final class PlaygroundTests: XCTestCase {
    private func makePlayground() -> Playground {
        Playground(config: .init(floorY: 700, leftX: 60, rightX: 1130, homeX: 600, ceilingY: 100), critterX: 600)
    }

    /// Runs the simulation for `seconds`, collecting every event.
    private func run(_ playground: inout Playground, seconds: Double) -> [Playground.Event] {
        var events: [Playground.Event] = []
        for _ in 0..<Int(seconds * 60) {
            events += playground.step(1.0 / 60)
        }
        return events
    }

    func testBallRestsWhereItIsUntilThrown() {
        var playground = makePlayground()
        let start = playground.ball
        XCTAssertTrue(run(&playground, seconds: 2).isEmpty)
        XCTAssertEqual(playground.ball, start)
        XCTAssertEqual(playground.task, .idle, "An untouched ball is not interesting")
    }

    func testThrownBallBouncesThenSettlesOnTheFloor() {
        var playground = makePlayground()
        playground.isTired = true
        XCTAssertTrue(playground.grabBall(at: playground.ball))
        playground.dragBall(to: Point2(700, 400))
        playground.throwBall(velocity: Point2(600, -900))
        let events = run(&playground, seconds: 6)
        XCTAssertTrue(events.contains(.bounced))
        XCTAssertEqual(playground.ballState, .resting)
        XCTAssertEqual(playground.ball.y, playground.ballRestY, accuracy: 0.01)
        XCTAssertTrue((60...1130).contains(playground.ball.x), "Walls keep the ball in the room")
    }

    func testCannotGrabBallFromFarAway() {
        var playground = makePlayground()
        XCTAssertFalse(playground.grabBall(at: Point2(100, 200)))
    }

    func testCritterFetchesThrownBallAndBringsItBack() {
        var playground = makePlayground()
        XCTAssertTrue(playground.grabBall(at: playground.ball))
        playground.throwBall(velocity: Point2(1400, -600))
        let events = run(&playground, seconds: 8)
        XCTAssertTrue(events.contains { if case .caughtBall = $0 { true } else { false } })
        XCTAssertTrue(events.contains(.deliveredBall))
        XCTAssertEqual(playground.fetches, 1)
        XCTAssertEqual(playground.critterX, 600, accuracy: 10)
        XCTAssertEqual(playground.ballState, .resting)
        XCTAssertEqual(playground.task, .idle)
    }

    func testDeliveredBallIsNotFetchedAgainUntilThrown() {
        var playground = makePlayground()
        _ = playground.grabBall(at: playground.ball)
        playground.throwBall(velocity: Point2(-1200, -500))
        _ = run(&playground, seconds: 8)
        XCTAssertEqual(playground.fetches, 1)
        _ = run(&playground, seconds: 4)
        XCTAssertEqual(playground.fetches, 1)
    }

    func testPlayerCannotSnatchACarriedBall() {
        var playground = makePlayground()
        _ = playground.grabBall(at: playground.ball)
        playground.throwBall(velocity: Point2(1000, -300))
        for _ in 0..<600 {
            _ = playground.step(1.0 / 60)
            if playground.ballState == .carried { break }
        }
        XCTAssertEqual(playground.ballState, .carried)
        XCTAssertFalse(playground.grabBall(at: playground.ball))
    }

    func testTiredCritterIgnoresTheBall() {
        var playground = makePlayground()
        playground.isTired = true
        _ = playground.grabBall(at: playground.ball)
        playground.throwBall(velocity: Point2(900, -300))
        XCTAssertFalse(run(&playground, seconds: 5).contains(.deliveredBall))
        XCTAssertEqual(playground.critterX, 600)
    }

    func testCritterJumpsToPopBubbles() {
        var playground = makePlayground()
        playground.blowBubble(at: Point2(820, 420))
        let events = run(&playground, seconds: 6)
        XCTAssertTrue(events.contains { if case .poppedBubble = $0 { true } else { false } })
        XCTAssertEqual(playground.pops, 1)
        XCTAssertTrue(playground.bubbles.isEmpty)
    }

    func testBubblesFloatAwayEventually() {
        var playground = makePlayground()
        playground.isTired = true
        playground.blowBubble(at: Point2(300, 300))
        _ = run(&playground, seconds: 12)
        XCTAssertTrue(playground.bubbles.isEmpty)
        XCTAssertEqual(playground.pops, 0)
    }

    func testBubbleLimit() {
        var playground = makePlayground()
        for i in 0..<20 { playground.blowBubble(at: Point2(Double(100 + i * 10), 300)) }
        XCTAssertEqual(playground.bubbles.count, 8)
    }
}
