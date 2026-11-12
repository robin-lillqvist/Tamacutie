import Foundation

/// Which part of a wide world is on screen. `x` is the world point at the screen's left edge.
/// You swipe to look around; when you leave it be, it gently follows the sötis.
public struct Camera: Equatable, Sendable {
    public let worldWidth: Double
    public let viewportWidth: Double
    public private(set) var x: Double
    public private(set) var velocity = 0.0
    /// After you swipe, it doesn't follow the sötis until this time (seconds on `step`'s clock).
    public private(set) var holdUntil = 0.0
    public private(set) var time = 0.0
    /// A glide toward this x, e.g. from an edge arrow or a button.
    public private(set) var glideTarget: Double?

    /// Momentum fades to this fraction per second.
    public static let friction = 0.04
    public static let followPause = 4.0
    /// The sötis can roam this far from the middle of the screen before the camera moves.
    public static let followSlack = 0.28
    /// It only follows something on screen or just walking off it, never something you left behind.
    public static let followReach = 300.0

    public init(worldWidth: Double, viewportWidth: Double, x: Double = 0) {
        self.worldWidth = max(worldWidth, viewportWidth)
        self.viewportWidth = viewportWidth
        self.x = 0
        self.x = clamp(x)
    }

    public var maxX: Double { worldWidth - viewportWidth }
    public var canScrollLeft: Bool { x > 1 }
    public var canScrollRight: Bool { x < maxX - 1 }

    public func isVisible(_ worldX: Double, margin: Double = 0) -> Bool {
        worldX >= x - margin && worldX <= x + viewportWidth + margin
    }

    /// Your finger moved by `dx` (positive means dragging to the right, which looks left).
    public mutating func pan(by dx: Double) {
        x = clamp(x - dx)
        velocity = 0
        glideTarget = nil
        holdUntil = time + Self.followPause
    }

    /// Let go with this finger velocity: keeps sliding and slows down.
    public mutating func fling(velocity fingerVelocity: Double) {
        velocity = -max(-4000, min(4000, fingerVelocity))
        holdUntil = time + Self.followPause
    }

    /// Glide smoothly so `worldX` ends up at the left edge (clamped).
    public mutating func glide(toX worldX: Double) {
        glideTarget = clamp(worldX)
        velocity = 0
        holdUntil = time + Self.followPause
    }

    /// Glide one screen to the left or right.
    public mutating func page(right: Bool) {
        glide(toX: (glideTarget ?? x) + (right ? 1 : -1) * viewportWidth * 0.8)
    }

    /// Glide so `worldX` is in the middle of the screen.
    public mutating func center(on worldX: Double) {
        glide(toX: worldX - viewportWidth / 2)
    }

    /// Jump straight there, no glide.
    public mutating func jump(toX worldX: Double) {
        x = clamp(worldX)
        velocity = 0
        glideTarget = nil
    }

    /// Keeps `targetX` comfortably on screen, unless you swiped a moment ago
    /// or scrolled somewhere else on purpose.
    public mutating func follow(_ targetX: Double) {
        guard time >= holdUntil, glideTarget == nil, velocity == 0, isVisible(targetX, margin: Self.followReach) else { return }
        let slack = viewportWidth * Self.followSlack
        let center = x + viewportWidth / 2
        if targetX > center + slack {
            glideTarget = clamp(targetX - slack - viewportWidth / 2)
        } else if targetX < center - slack {
            glideTarget = clamp(targetX + slack - viewportWidth / 2)
        }
    }

    public mutating func step(_ dt: Double) {
        time += dt
        if velocity != 0 {
            x += velocity * dt
            velocity *= pow(Self.friction, dt)
            if abs(velocity) < 20 { velocity = 0 }
            let clamped = clamp(x)
            if clamped != x {
                x = clamped
                velocity = 0
            }
        } else if let target = glideTarget {
            let blend = 1 - pow(0.002, dt)
            x += (target - x) * blend
            if abs(target - x) < 0.5 {
                x = target
                glideTarget = nil
            }
        }
    }

    private func clamp(_ value: Double) -> Double {
        min(max(value, 0), max(0, worldWidth - viewportWidth))
    }
}
