import Foundation

public struct Point2: Equatable, Sendable {
    public var x: Double
    public var y: Double

    public init(_ x: Double, _ y: Double) {
        self.x = x
        self.y = y
    }
}

/// Physics and critter behaviour for playtime in the room: fetch with a ball, and popping bubbles.
/// Coordinates are room design points; y grows downwards.
public struct Playground: Sendable {
    public enum BallState: Equatable, Sendable {
        case resting, flying, heldByPlayer, carried
    }

    public enum Task: Equatable, Sendable {
        case idle, chasingBall, carryingBall, celebrating(until: Double), chasingBubble(UUID), tired
    }

    public enum Event: Equatable, Sendable {
        case caughtBall(inAir: Bool), deliveredBall, poppedBubble(Point2), bounced
    }

    public struct Bubble: Identifiable, Equatable, Sendable {
        public let id: UUID
        public var position: Point2
        public let born: Double
        public let phase: Double
    }

    public struct Config: Sendable {
        public var floorY: Double
        public var leftX: Double
        public var rightX: Double
        public var homeX: Double
        public var ceilingY: Double
        public var ballRadius = 30.0
        public var critterSize = 300.0
        public var gravity = 2400.0
        public var bounce = 0.55
        public var critterSpeed = 520.0

        public init(floorY: Double, leftX: Double, rightX: Double, homeX: Double, ceilingY: Double) {
            self.floorY = floorY
            self.leftX = leftX
            self.rightX = rightX
            self.homeX = homeX
            self.ceilingY = ceilingY
        }
    }

    public let config: Config
    public private(set) var time = 0.0
    public private(set) var ball: Point2
    public private(set) var ballVelocity = Point2(0, 0)
    public private(set) var ballState = BallState.resting
    public private(set) var critterX: Double
    /// Height of the critter's jump above the floor.
    public private(set) var hop = 0.0
    public private(set) var facingRight = true
    public private(set) var task = Task.idle
    public private(set) var bubbles: [Bubble] = []
    public private(set) var fetches = 0
    public private(set) var pops = 0
    public var isTired = false {
        didSet { if isTired { task = .tired } else if task == .tired { task = .idle } }
    }

    private var hopVelocity = 0.0
    /// Only a ball the player threw is worth fetching.
    private var ballIsFresh = false

    public init(config: Config, critterX: Double) {
        self.config = config
        self.critterX = critterX
        ball = Point2(config.homeX + 160, config.floorY - config.ballRadius)
    }

    public var ballRestY: Double { config.floorY - config.ballRadius }
    public var critterHeadY: Double { config.floorY - config.critterSize * 0.62 - hop }
    public var isWalking: Bool {
        switch task {
        case .chasingBall, .carryingBall, .chasingBubble: true
        default: false
        }
    }

    // MARK: Player input

    @discardableResult
    public mutating func grabBall(at point: Point2) -> Bool {
        guard ballState != .carried, distance(point, ball) < config.ballRadius * 3 else { return false }
        ballState = .heldByPlayer
        ballVelocity = Point2(0, 0)
        ball = point
        return true
    }

    public mutating func dragBall(to point: Point2) {
        guard ballState == .heldByPlayer else { return }
        ball = Point2(min(max(point.x, config.leftX), config.rightX), min(max(point.y, config.ceilingY), ballRestY))
    }

    public mutating func throwBall(velocity: Point2) {
        guard ballState == .heldByPlayer else { return }
        let maxSpeed = 2600.0
        ballVelocity = Point2(min(max(velocity.x, -maxSpeed), maxSpeed), min(max(velocity.y, -maxSpeed), maxSpeed))
        ballState = .flying
        ballIsFresh = true
    }

    public mutating func blowBubble(at point: Point2) {
        guard bubbles.count < 8 else { return }
        bubbles.append(Bubble(id: UUID(), position: point, born: time, phase: Double(bubbles.count) * 1.7))
    }

    /// The critter throws the ball itself, to go and fetch it. Only when it is free and the ball lies still.
    @discardableResult
    public mutating func tossBallItself(towardRight: Bool, strength: Double = 700) -> Bool {
        guard ballState == .resting, task == .idle else { return false }
        facingRight = towardRight
        let side = towardRight ? 1.0 : -1.0
        ball = Point2(critterX + side * 40, config.floorY - config.critterSize * 0.5)
        ballVelocity = Point2(side * strength, -900)
        ballState = .flying
        ballIsFresh = true
        return true
    }

    // MARK: Simulation

    public mutating func step(_ dt: Double) -> [Event] {
        time += dt
        var events: [Event] = []
        stepBall(dt, events: &events)
        stepBubbles(dt)
        stepCritter(dt, events: &events)
        stepHop(dt)
        return events
    }

    private mutating func stepBall(_ dt: Double, events: inout [Event]) {
        switch ballState {
        case .flying:
            ballVelocity.y += config.gravity * dt
            ball.x += ballVelocity.x * dt
            ball.y += ballVelocity.y * dt
            if ball.x < config.leftX {
                ball.x = config.leftX
                ballVelocity.x = abs(ballVelocity.x) * 0.6
            } else if ball.x > config.rightX {
                ball.x = config.rightX
                ballVelocity.x = -abs(ballVelocity.x) * 0.6
            }
            if ball.y < config.ceilingY {
                ball.y = config.ceilingY
                ballVelocity.y = abs(ballVelocity.y) * 0.5
            }
            if ball.y >= ballRestY {
                ball.y = ballRestY
                if ballVelocity.y > 160 {
                    ballVelocity.y = -ballVelocity.y * config.bounce
                    events.append(.bounced)
                } else {
                    ballVelocity.y = 0
                }
                ballVelocity.x *= pow(0.25, dt)
                if ballVelocity.y == 0 && abs(ballVelocity.x) < 20 {
                    ballState = .resting
                    ballVelocity = Point2(0, 0)
                }
            }
        case .carried:
            ball = Point2(critterX + (facingRight ? 1 : -1) * config.critterSize * 0.12, config.floorY - config.critterSize * 0.38 - hop)
        case .resting, .heldByPlayer:
            break
        }
    }

    private mutating func stepBubbles(_ dt: Double) {
        for index in bubbles.indices {
            bubbles[index].position.y -= 22 * dt
            bubbles[index].position.x += sin(time * 2 + bubbles[index].phase) * 30 * dt
        }
        let now = time
        let ceiling = config.ceilingY
        bubbles.removeAll { now - $0.born > 10 || $0.position.y < ceiling }
    }

    private mutating func stepCritter(_ dt: Double, events: inout [Event]) {
        let speed = config.critterSpeed
        switch task {
        case .tired:
            return
        case .celebrating(let until):
            if time >= until { task = .idle }
        case .idle:
            if ballIsFresh, ballState == .flying || ballState == .resting {
                task = .chasingBall
            } else if let target = nearestBubble() {
                task = .chasingBubble(target.id)
            }
        case .chasingBall:
            guard ballState == .flying || ballState == .resting else {
                task = .idle
                return
            }
            walk(toward: ball.x, speed: speed, dt: dt)
            let lowEnough = ball.y > config.floorY - config.critterSize * 0.75
            if abs(ball.x - critterX) < 50, lowEnough {
                let inAir = ballState == .flying && ball.y < ballRestY - 30
                if inAir && hop == 0 { hopVelocity = 520 }
                ballState = .carried
                ballVelocity = Point2(0, 0)
                ballIsFresh = false
                task = .carryingBall
                events.append(.caughtBall(inAir: inAir))
            }
        case .carryingBall:
            walk(toward: config.homeX, speed: speed * 0.75, dt: dt)
            if abs(critterX - config.homeX) < 8 {
                ballState = .resting
                ball = Point2(critterX + (facingRight ? 1 : -1) * 90, ballRestY)
                fetches += 1
                hopVelocity = 620
                task = .celebrating(until: time + 0.9)
                events.append(.deliveredBall)
            }
        case .chasingBubble(let id):
            guard let bubble = bubbles.first(where: { $0.id == id }) else {
                task = .idle
                return
            }
            walk(toward: bubble.position.x, speed: speed * 0.8, dt: dt)
            let dx = abs(bubble.position.x - critterX)
            if dx < 70, hop == 0, bubble.position.y > critterHeadY - 260 {
                hopVelocity = min(900, max(450, (critterHeadY - bubble.position.y) * 3.2 + 450))
            }
            if dx < 80, abs(bubble.position.y - critterHeadY) < 80 {
                bubbles.removeAll { $0.id == id }
                pops += 1
                task = .idle
                events.append(.poppedBubble(bubble.position))
            }
        }
    }

    private mutating func stepHop(_ dt: Double) {
        guard hop > 0 || hopVelocity > 0 else { return }
        hop += hopVelocity * dt
        hopVelocity -= 2200 * dt
        if hop <= 0 {
            hop = 0
            hopVelocity = 0
        }
    }

    private mutating func walk(toward x: Double, speed: Double, dt: Double) {
        let dx = x - critterX
        guard abs(dx) > 1 else { return }
        facingRight = dx > 0
        let stepSize = min(abs(dx), speed * dt)
        critterX = min(max(critterX + (dx > 0 ? stepSize : -stepSize), config.leftX), config.rightX)
    }

    private func nearestBubble() -> Bubble? {
        bubbles.min { abs($0.position.x - critterX) < abs($1.position.x - critterX) }
    }

    private func distance(_ a: Point2, _ b: Point2) -> Double {
        hypot(a.x - b.x, a.y - b.y)
    }
}
