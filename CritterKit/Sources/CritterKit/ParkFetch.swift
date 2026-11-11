import Foundation

/// Fetch in the park. You throw, your sötis runs and always catches, then throws it back
/// for you to catch. A park friend can join in, so the ball goes you → sötis → friend → you.
/// Coordinates are park design points; y grows downwards. Times are seconds.
public struct ParkFetch: Sendable {
    public enum Player: Equatable, Sendable {
        case you, pet, friend
    }

    public struct Flight: Equatable, Sendable {
        public let from: Point2
        public let to: Point2
        public let start: Double
        public let duration: Double
        public let thrower: Player
        public let catcher: Player

        public var end: Double { start + duration }
        public var arc: Double { 110 + abs(to.x - from.x) * 0.25 }

        public func position(at t: Double) -> Point2 {
            let u = min(1, max(0, (t - start) / duration))
            return Point2(
                from.x + (to.x - from.x) * u,
                from.y + (to.y - from.y) * u - sin(u * .pi) * arc
            )
        }
    }

    public enum Ball: Equatable, Sendable {
        case held(Player, since: Double)
        case flying(Flight)
    }

    public enum Event: Equatable, Sendable {
        case thrown(by: Player)
        case caught(by: Player)
        /// The ball came back to you and you didn't catch it. It lands in your hand anyway.
        case dropped
    }

    public struct Layout: Sendable {
        public var groundY: Double
        public var hand: Point2
        public var minX: Double
        public var maxX: Double
        public var friendX: Double
        /// How far above the ground a critter catches the ball.
        public var catchHeight: Double

        public init(groundY: Double, hand: Point2, minX: Double, maxX: Double, friendX: Double, catchHeight: Double) {
            self.groundY = groundY
            self.hand = hand
            self.minX = minX
            self.maxX = maxX
            self.friendX = friendX
            self.catchHeight = catchHeight
        }
    }

    public static let runSpeed = 520.0
    public static let holdTime = 0.7
    public static let catchRadius = 150.0
    public static let catchLag = 0.6
    public static let catchLead = 0.3
    /// A tap just after the ball lands in your hand still counts as a catch.
    public static let landingGrace = 0.4
    /// The ball thrown to you flies slowly so a child can tap it: never quicker than this,
    /// and never faster than `throwToYouSpeed` however far away the thrower stands.
    public static let throwToYouDuration = 1.9
    public static let throwToYouSpeed = 380.0
    /// You can catch it once it is this far along its way to you.
    public static let catchableFrom = 0.3
    /// Distance kept between your sötis and the friend while the friend plays.
    public static let friendGap = 180.0

    public let layout: Layout
    public private(set) var ball: Ball
    public private(set) var petX: Double
    public private(set) var friendX: Double
    public private(set) var petTargetX: Double
    public private(set) var friendJoined = false
    /// Every catch, by anyone.
    public private(set) var catches = 0
    /// Rounds in a row that came all the way back into your hand.
    public private(set) var streak = 0

    public init(layout: Layout, petX: Double, now: Double) {
        self.layout = layout
        self.petX = petX
        petTargetX = petX
        friendX = layout.friendX
        ball = .held(.you, since: now)
    }

    public var canThrow: Bool {
        if case .held(.you, _) = ball { return true }
        return false
    }

    /// The ball is on its way to you, so a tap near it catches it.
    public func isComingToYou(at t: Double) -> Bool {
        if case .flying(let flight) = ball, flight.catcher == .you { return t >= flight.start + flight.duration * Self.catchableFrom }
        return false
    }

    public func ballPosition(at t: Double) -> Point2 {
        switch ball {
        case .flying(let flight): flight.position(at: t)
        case .held(let player, _): catchPoint(player)
        }
    }

    public func catchPoint(_ player: Player) -> Point2 {
        switch player {
        case .you: layout.hand
        case .pet: Point2(petX, layout.groundY - layout.catchHeight)
        case .friend: Point2(friendX, layout.groundY - layout.catchHeight)
        }
    }

    private var throwMaxX: Double { friendJoined ? layout.friendX - Self.friendGap : layout.maxX }

    /// Throw toward a spot on the field. Your sötis gets there in time, always.
    @discardableResult
    public mutating func throwBall(towardX x: Double, at t: Double) -> Bool {
        guard canThrow else { return false }
        let targetX = min(throwMaxX, max(layout.minX, x))
        let to = Point2(targetX, layout.groundY - layout.catchHeight)
        let runTime = abs(targetX - petX) / Self.runSpeed
        petTargetX = targetX
        ball = .flying(Flight(from: layout.hand, to: to, start: t, duration: max(1.2, runTime + 0.3), thrower: .you, catcher: .pet))
        return true
    }

    /// The park friend joins the game. Your sötis steps aside if it stands in the friend's spot.
    @discardableResult
    public mutating func joinFriend() -> Bool {
        guard !friendJoined else { return false }
        friendJoined = true
        if case .flying = ball { return true }
        petTargetX = min(petTargetX, throwMaxX)
        return true
    }

    /// Walk your sötis somewhere, e.g. to a mound to dig.
    public mutating func walkPet(to x: Double) {
        petTargetX = min(layout.maxX, max(layout.minX, x))
    }

    public func isRunning(_ player: Player) -> Bool {
        player == .pet && abs(petX - petTargetX) > 1
    }

    public var petFacingRight: Bool { petTargetX >= petX }

    /// How high a critter is jumping right now, in points: up to meet the ball, then down again.
    public func hop(_ player: Player, at t: Double) -> Double {
        let rise = 0.35
        switch ball {
        case .flying(let flight) where flight.catcher == player:
            let left = flight.end - t
            return left < rise ? (1 - max(0, left) / rise) * 50 : 0
        case .held(let holder, let since) where holder == player:
            let fall = (t - since) / rise
            return fall < 1 ? (1 - fall) * 50 : 0
        default:
            return 0
        }
    }

    /// Tap to catch the ball coming back to you. Fingers lag behind what eyes see, so a tap
    /// counts if it lands near where the ball was a moment ago, or is about to be.
    public mutating func tryCatch(at point: Point2, at t: Double) -> Bool {
        guard isComingToYou(at: t), case .flying(let flight) = ball else { return false }
        let near = stride(from: t - Self.catchLag, through: t + Self.catchLead, by: 0.05).contains { moment in
            let p = flight.position(at: max(flight.start, moment))
            return hypot(p.x - point.x, p.y - point.y) <= Self.catchRadius
        }
        guard near else { return false }
        ball = .held(.you, since: t)
        catches += 1
        streak += 1
        return true
    }

    public mutating func update(to t: Double, dt: Double) -> [Event] {
        let step = Self.runSpeed * dt
        petX += max(-step, min(step, petTargetX - petX))

        var events: [Event] = []
        switch ball {
        case .flying(let flight) where t >= flight.end + (flight.catcher == .you ? Self.landingGrace : 0):
            if flight.catcher == .you {
                ball = .held(.you, since: t)
                streak = 0
                events.append(.dropped)
            } else {
                if flight.catcher == .pet { petX = flight.to.x; petTargetX = petX }
                ball = .held(flight.catcher, since: t)
                catches += 1
                events.append(.caught(by: flight.catcher))
            }
        case .held(let holder, let since) where holder != .you && t - since >= Self.holdTime:
            let next: Player = holder == .pet && friendJoined ? .friend : .you
            let from = catchPoint(holder)
            let to = catchPoint(next)
            let distance = abs(to.x - from.x)
            let duration = next == .you ? max(Self.throwToYouDuration, distance / Self.throwToYouSpeed) : max(1.1, distance / 600)
            ball = .flying(Flight(from: from, to: to, start: t, duration: duration, thrower: holder, catcher: next))
            events.append(.thrown(by: holder))
        default:
            break
        }
        return events
    }
}
