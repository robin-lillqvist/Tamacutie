import XCTest
@testable import CritterKit

final class ParkPlayTests: XCTestCase {
    private func makePlay() -> ParkPlay {
        ParkPlay(config: ParkPlay.Config(pondCenter: Point2(2800, 650), pondRadii: Point2(260, 70), flowers: Point2(3250, 640)))
    }

    func testPushingTheSwingMakesItSwingHigherThenItSlowsDown() {
        var play = makePlay()
        XCTAssertEqual(play.swingAngle(at: 0.6), 0, "still")
        XCTAssertTrue(play.push(at: 0))
        let once = play.swingAmplitude
        XCTAssertTrue(play.push(at: 1))
        XCTAssertGreaterThan(play.swingAmplitude, once)
        for second in 2..<10 { play.push(at: Double(second)) }
        XCTAssertEqual(play.swingAmplitude, 1, "never over the top")
        XCTAssertLessThanOrEqual(abs(play.swingAngle(at: 0.6)), ParkPlay.swingMaxAngle)
        for _ in 0..<(60 * 30) { play.stepSwing(1 / 60) }
        XCTAssertEqual(play.swingAmplitude, 0, "left alone it stops")
    }

    func testFastPushesCountOnceForFun() {
        var play = makePlay()
        let counted = (0..<20).filter { play.push(at: Double($0) * 0.1) }.count
        XCTAssertEqual(counted, 3, "two seconds of frantic pushing count three times")
    }

    func testTheSlideClimbsSlidesAndLands() {
        var play = makePlay()
        XCTAssertNil(play.slidePhase(at: 0))
        XCTAssertTrue(play.startSlide(at: 10))
        XCTAssertFalse(play.startSlide(at: 10.5), "one slide at a time")
        guard case .climbing(let up) = play.slidePhase(at: 10.65) else { return XCTFail("should be climbing") }
        XCTAssertEqual(up, 0.5, accuracy: 0.001)
        guard case .sliding = play.slidePhase(at: 10 + ParkPlay.climbTime + 0.1) else { return XCTFail("should be sliding") }
        guard case .landing = play.slidePhase(at: 10 + ParkPlay.climbTime + ParkPlay.slideTime + 0.1) else { return XCTFail("should be landing") }
        XCTAssertFalse(play.finishSlide(at: 11), "not done yet")
        XCTAssertTrue(play.finishSlide(at: 13))
        XCTAssertFalse(play.finishSlide(at: 13.1), "counts once")
        XCTAssertEqual(play.slides, 1)
    }

    func testBuildingASandcastle() {
        var play = makePlay()
        XCTAssertEqual(play.dig(), .built(stage: 1))
        XCTAssertEqual(play.dig(), .built(stage: 2))
        XCTAssertEqual(play.dig(), .built(stage: 3))
        XCTAssertEqual(play.dig(), .finished)
        XCTAssertEqual(play.castlesBuilt, 1)
        XCTAssertEqual(play.dig(), .knockedDown)
        XCTAssertEqual(play.castle, 0)
    }

    func testDucksPaddleToCrumbsAndEatThem() {
        var play = makePlay()
        XCTAssertFalse(play.toss(at: Point2(2800, 400)), "crumbs on dry land don't count")
        XCTAssertTrue(play.toss(at: Point2(2900, 660)))
        var eaten: [Int] = []
        var t = 0.0
        for _ in 0..<(60 * 10) where eaten.isEmpty {
            t += 1 / 60
            eaten = play.stepDucks(1 / 60, at: t)
        }
        XCTAssertEqual(eaten.count, 1)
        XCTAssertTrue(play.crumbs.isEmpty)
        XCTAssertEqual(play.crumbsEaten, 1)
    }

    func testOnlyAFewCrumbsAtOnce() {
        var play = makePlay()
        let tossed = (0..<10).filter { play.toss(at: Point2(2800 + Double($0), 650)) }.count
        XCTAssertEqual(tossed, ParkPlay.maxCrumbs)
    }

    func testChasingAButterfly() {
        var play = makePlay()
        let t = 5.0
        let spot = play.butterfly(1, at: t)
        let index = play.butterfly(near: spot, at: t)
        XCTAssertNotNil(index)
        play.chase(index!)
        XCTAssertNil(play.checkCatch(petX: spot.x + 500, at: t), "too far away")
        XCTAssertEqual(play.checkCatch(petX: play.butterfly(index!, at: t).x, at: t), index)
        XCTAssertEqual(play.butterfliesCaught, 1)
        XCTAssertFalse(play.isHere(index!, at: t + 1), "it flutters off for a bit")
        XCTAssertTrue(play.isHere(index!, at: t + ParkPlay.butterflyAway + 0.1))
        XCTAssertNil(play.butterfly(near: Point2(0, 0), at: t), "no butterfly there")
    }
}

final class WideParkTests: XCTestCase {
    func testFetchStaysInTheMeadowButTheSötisRoamsThePark() {
        let layout = ParkFetch.Layout(groundY: 640, hand: Point2(150, 520), minX: 100, maxX: 3480, throwMinX: 360, throwMaxX: 1060, friendX: 1040, catchHeight: 190)
        var fetch = ParkFetch(layout: layout, petX: 560, now: 0)
        fetch.walkPet(to: 3000)
        XCTAssertEqual(fetch.petTargetX, 3000, "it can walk over to the pond")
        for step in 0..<(60 * 8) { _ = fetch.update(to: Double(step) / 60, dt: 1 / 60) }
        XCTAssertEqual(fetch.petX, 3000, accuracy: 1)
        XCTAssertTrue(fetch.throwBall(towardX: 2500, at: 9))
        XCTAssertEqual(fetch.petTargetX, 1060, "throws land in the meadow; it runs back for it")
        fetch.placePet(at: 2200)
        XCTAssertEqual(fetch.petX, 2200)
        XCTAssertFalse(fetch.isRunning(.pet))
    }

    func testAnIceCreamFromTheKiosk() {
        var game = makeGame()
        game.earn(100)
        let coins = game.coins
        let price = Catalog.item("icecream")!.price
        XCTAssertNotNil(game.buyAndEat("icecream", now: t0))
        XCTAssertEqual(game.coins, coins - price)
        XCTAssertEqual(game.count(of: "icecream"), 0, "eaten on the spot")
        XCTAssertTrue(game.pet!.isBeaming(at: t0 + 60))

        var broke = makeGame()
        while broke.buy("icecream") == .bought {}
        let left = broke.coins
        XCTAssertNil(broke.buyAndEat("icecream", now: t0))
        XCTAssertEqual(broke.coins, left, "nothing spent")
    }
}
