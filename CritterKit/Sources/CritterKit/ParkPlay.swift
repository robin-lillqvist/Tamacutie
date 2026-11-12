import Foundation

/// Everything to do in the park besides fetch: swings, the slide, a sandcastle, ducks to feed
/// and butterflies to chase. Coordinates are park design points (y grows downwards); times are seconds.
public struct ParkPlay: Sendable {
    public struct Config: Sendable {
        /// The duck pond is an ellipse.
        public var pondCenter: Point2
        public var pondRadii: Point2
        /// Butterflies flutter over this flowerbed.
        public var flowers: Point2

        public init(pondCenter: Point2, pondRadii: Point2, flowers: Point2) {
            self.pondCenter = pondCenter
            self.pondRadii = pondRadii
            self.flowers = flowers
        }
    }

    public let config: Config

    public init(config: Config) {
        self.config = config
        ducks = (0..<3).map { index in
            let angle = Double(index) / 3 * 2 * .pi
            return Duck(id: index, position: Point2(config.pondCenter.x + cos(angle) * config.pondRadii.x * 0.5,
                                                    config.pondCenter.y + sin(angle) * config.pondRadii.y * 0.4))
        }
    }

    // MARK: Swing

    public static let swingMaxAngle = 40.0
    public static let swingPeriod = 2.4
    public static let pushGain = 0.22
    /// Without pushes the swing slows down: this much of the swing is left after a second.
    public static let swingKeep = 0.85
    /// Pushes closer together than this still push, but only count once for fun.
    public static let pushInterval = 0.8

    public private(set) var swingAmplitude = 0.0
    private var lastCountedPush = -Double.infinity

    /// The swing's angle in degrees right now.
    public func swingAngle(at t: Double) -> Double {
        swingAmplitude * Self.swingMaxAngle * sin(2 * .pi * t / Self.swingPeriod)
    }

    /// A push from you. Returns true if it counts toward fun (rate-limited, like strokes).
    @discardableResult
    public mutating func push(at t: Double) -> Bool {
        swingAmplitude = min(1, swingAmplitude + Self.pushGain)
        guard t - lastCountedPush >= Self.pushInterval else { return false }
        lastCountedPush = t
        return true
    }

    public mutating func stepSwing(_ dt: Double) {
        swingAmplitude *= pow(Self.swingKeep, dt)
        if swingAmplitude < 0.01 { swingAmplitude = 0 }
    }

    // MARK: Slide

    public enum SlidePhase: Equatable, Sendable {
        /// 0...1 up the ladder, then down the ramp, then the little hop at the bottom.
        case climbing(Double), sliding(Double), landing(Double)
    }

    public static let climbTime = 1.3
    public static let slideTime = 0.8
    public static let landTime = 0.4
    public private(set) var slideStart: Double?
    public private(set) var slides = 0

    @discardableResult
    public mutating func startSlide(at t: Double) -> Bool {
        guard slideStart == nil else { return false }
        slideStart = t
        return true
    }

    public func slidePhase(at t: Double) -> SlidePhase? {
        guard let slideStart else { return nil }
        let u = t - slideStart
        if u < Self.climbTime { return .climbing(u / Self.climbTime) }
        if u < Self.climbTime + Self.slideTime { return .sliding((u - Self.climbTime) / Self.slideTime) }
        if u < Self.climbTime + Self.slideTime + Self.landTime { return .landing((u - Self.climbTime - Self.slideTime) / Self.landTime) }
        return nil
    }

    /// True once, when a slide has just ended.
    public mutating func finishSlide(at t: Double) -> Bool {
        guard slideStart != nil, slidePhase(at: t) == nil else { return false }
        slideStart = nil
        slides += 1
        return true
    }

    // MARK: Sandcastle

    public static let castleStages = 4

    public enum CastleResult: Equatable, Sendable {
        case built(stage: Int)
        /// The last tower went on: done! Worth a coin.
        case finished
        /// Tapping a finished castle stomps it flat, to build again.
        case knockedDown
    }

    /// 0 is a flat sandbox, `castleStages` is a castle with a flag.
    public private(set) var castle = 0
    public private(set) var castlesBuilt = 0

    public mutating func dig() -> CastleResult {
        if castle >= Self.castleStages {
            castle = 0
            return .knockedDown
        }
        castle += 1
        if castle == Self.castleStages {
            castlesBuilt += 1
            return .finished
        }
        return .built(stage: castle)
    }

    // MARK: Ducks

    public struct Duck: Identifiable, Equatable, Sendable {
        public let id: Int
        public var position: Point2
        public var facingRight = true
    }

    public struct Crumb: Identifiable, Equatable, Sendable {
        public let id: UUID
        public let position: Point2
    }

    public static let duckSpeed = 110.0
    public static let maxCrumbs = 6
    public static let eatRadius = 16.0

    public private(set) var ducks: [Duck]
    public private(set) var crumbs: [Crumb] = []
    public private(set) var crumbsEaten = 0

    public func isInPond(_ point: Point2) -> Bool {
        let dx = (point.x - config.pondCenter.x) / config.pondRadii.x
        let dy = (point.y - config.pondCenter.y) / config.pondRadii.y
        return dx * dx + dy * dy <= 1
    }

    /// Toss a crumb onto the water. Not on dry land, and not too many at once.
    @discardableResult
    public mutating func toss(at point: Point2) -> Bool {
        guard isInPond(point), crumbs.count < Self.maxCrumbs else { return false }
        crumbs.append(Crumb(id: UUID(), position: point))
        return true
    }

    /// Ducks paddle to the nearest crumb and gobble it up; with nothing to eat they drift about.
    /// Returns the ducks that ate a crumb this step.
    public mutating func stepDucks(_ dt: Double, at t: Double) -> [Int] {
        var ate: [Int] = []
        for index in ducks.indices {
            let here = ducks[index].position
            let target: Point2
            if let crumb = crumbs.min(by: { distance($0.position, here) < distance($1.position, here) }) {
                target = crumb.position
            } else {
                let angle = t * 0.25 + Double(index) * 2.1
                target = Point2(config.pondCenter.x + cos(angle) * config.pondRadii.x * 0.55,
                                config.pondCenter.y + sin(angle) * config.pondRadii.y * 0.45)
            }
            let dx = target.x - here.x, dy = target.y - here.y
            let gap = hypot(dx, dy)
            let speed = crumbs.isEmpty ? Self.duckSpeed * 0.3 : Self.duckSpeed
            let step = min(gap, speed * dt)
            if gap > 0.5 {
                ducks[index].position = Point2(here.x + dx / gap * step, here.y + dy / gap * step)
                if abs(dx) > 2 { ducks[index].facingRight = dx > 0 }
            }
            if let eaten = crumbs.firstIndex(where: { distance($0.position, ducks[index].position) <= Self.eatRadius }) {
                crumbs.remove(at: eaten)
                crumbsEaten += 1
                ate.append(ducks[index].id)
            }
        }
        return ate
    }

    // MARK: Butterflies

    public static let butterflyCount = 3
    public static let catchDistance = 60.0
    /// A caught butterfly flutters off and comes back after this long.
    public static let butterflyAway = 6.0

    public private(set) var chasing: Int?
    public private(set) var butterfliesCaught = 0
    private var awayUntil: [Int: Double] = [:]

    /// Where butterfly `index` is: a lazy figure-of-eight over the flowers.
    public func butterfly(_ index: Int, at t: Double) -> Point2 {
        let phase = Double(index) * 2.3
        let speed = 0.5 + Double(index) * 0.12
        return Point2(config.flowers.x + sin(t * speed + phase) * 150,
                      config.flowers.y - 150 + sin(t * speed * 2 + phase) * 55 - Double(index) * 30)
    }

    public func isHere(_ index: Int, at t: Double) -> Bool {
        t >= awayUntil[index, default: -.infinity]
    }

    /// The butterfly near `point` you tapped, if any.
    public func butterfly(near point: Point2, at t: Double, radius: Double = 90) -> Int? {
        (0..<Self.butterflyCount).filter { isHere($0, at: t) }
            .min { distance(butterfly($0, at: t), point) < distance(butterfly($1, at: t), point) }
            .flatMap { distance(butterfly($0, at: t), point) <= radius ? $0 : nil }
    }

    public mutating func chase(_ index: Int) {
        chasing = index
    }

    public mutating func stopChasing() {
        chasing = nil
    }

    /// Your sötis catches the butterfly it chases once it is right underneath.
    public mutating func checkCatch(petX: Double, at t: Double) -> Int? {
        guard let index = chasing, isHere(index, at: t) else { return nil }
        guard abs(butterfly(index, at: t).x - petX) <= Self.catchDistance else { return nil }
        chasing = nil
        awayUntil[index] = t + Self.butterflyAway
        butterfliesCaught += 1
        return index
    }

    private func distance(_ a: Point2, _ b: Point2) -> Double {
        hypot(a.x - b.x, a.y - b.y)
    }
}
