import Foundation

/// Things the critter gets up to on its own when you leave it be.
public enum SoloActivity: String, CaseIterable, Sendable {
    /// Sits in the window with a book.
    case reading
    /// Sits in the window looking at the moon and the stars (at night, instead of reading).
    case stargazing
    case dancing
    /// Tosses the ball and fetches it for itself.
    case playingBall
    case watchingFish
    /// Down the slide in the play corner.
    case sliding
    /// Bounces on the big cushion.
    case bouncing
    /// Plinks away on the xylophone.
    case makingMusic
}

public enum SoloLife {
    /// What to do after `idle` seconds without you touching anything, or nil to just potter about.
    /// `roll` is a random number in 0..<1.
    public static func pick(for pet: Pet, at now: Date, idle: TimeInterval, phase: DayPhase, roll: Double) -> SoloActivity? {
        guard pet.isAlive, !pet.isAsleep, !pet.isSick, idle >= Rules.soloAfterIdle else { return nil }
        let temper = pet.temper(at: now)
        guard temper < .upset else { return nil }
        let needs = pet.needs
        guard needs.hunger >= 35, needs.thirst >= 35, needs.energy >= 25 else { return nil }

        let window: SoloActivity = phase.isDark ? .stargazing : .reading
        if temper == .grumpy { return window }

        let weighted: [(SoloActivity, Double)] = if needs.energy < 45 {
            [(window, 3), (.watchingFish, 1)]
        } else if needs.fun < 50 {
            [(.playingBall, 3), (.dancing, 2), (.sliding, 2), (.bouncing, 2), (window, 1)]
        } else {
            [(window, 2), (.playingBall, 2), (.dancing, 1), (.watchingFish, 1), (.sliding, 1), (.bouncing, 1), (.makingMusic, 1)]
        }
        var target = min(max(roll, 0), 0.999_999) * weighted.reduce(0) { $0 + $1.1 }
        for (activity, weight) in weighted {
            if target < weight { return activity }
            target -= weight
        }
        return weighted.last?.0
    }
}
