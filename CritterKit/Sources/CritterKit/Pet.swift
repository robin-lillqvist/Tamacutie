import Foundation

public struct Needs: Codable, Equatable, Sendable {
    public var hunger: Double
    public var thirst: Double
    public var energy: Double
    public var hygiene: Double
    public var fun: Double
    public var love: Double

    public init(hunger: Double = 80, thirst: Double = 80, energy: Double = 80, hygiene: Double = 80, fun: Double = 80, love: Double = 60) {
        self.hunger = hunger
        self.thirst = thirst
        self.energy = energy
        self.hygiene = hygiene
        self.fun = fun
        self.love = love
    }

    public var average: Double { (hunger + thirst + energy + hygiene + fun + love) / 6 }

    mutating func clamp() {
        hunger = hunger.clamped()
        thirst = thirst.clamped()
        energy = energy.clamped()
        hygiene = hygiene.clamped()
        fun = fun.clamped()
        love = love.clamped()
    }
}

public struct Poop: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    /// Normalised floor position, 0...1 on both axes.
    public let x: Double
    public let y: Double
    public let createdAt: Date
}

public enum CauseOfDeath: String, Codable, Sendable {
    case starvation, overeating
}

public enum WeightStage: String, Codable, CaseIterable, Sendable {
    case starving, thin, healthy, chubby, obese

    public init(weight: Double) {
        switch weight {
        case ..<15: self = .starving
        case ..<35: self = .thin
        case ...65: self = .healthy
        case ...85: self = .chubby
        default: self = .obese
        }
    }

    public var title: String {
        switch self {
        case .starving: "Utsvulten"
        case .thin: "Lite smal"
        case .healthy: "Lagom"
        case .chubby: "Lite rund"
        case .obese: "Alldeles för rund"
        }
    }

    public var isDangerous: Bool { self == .starving || self == .obese }
}

/// How the critter looks overall, from freshly bathed to fading away.
public enum Condition: String, Sendable {
    case sparkly, clean, normal, dirty, filthy, sick, dying, dead
}

public enum Mood: String, Sendable {
    case dead, asleep, sick, ignoring, excited, happy, content, hungry, sleepy, sad
}

public struct Pet: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public var name: String
    public let genome: Genome
    public let birthDate: Date
    public private(set) var lastUpdate: Date
    public var needs: Needs
    public var weight: Double
    public private(set) var isAsleep = false
    public private(set) var isSick = false
    public private(set) var dirtyHours = 0.0
    public private(set) var poops: [Poop] = []
    public private(set) var pendingPoops: [Date] = []
    public private(set) var lastInteraction: Date
    public private(set) var cooldownUntil: Date?
    public private(set) var missedYouUntil: Date?
    public private(set) var deathDate: Date?
    public private(set) var causeOfDeath: CauseOfDeath?
    /// When the post-bath shine started and when it wears off.
    public private(set) var shineStart: Date?
    public private(set) var shineEnd: Date?

    public init(name: String, genome: Genome, now: Date) {
        id = UUID()
        self.name = name
        self.genome = genome
        birthDate = now
        lastUpdate = now
        lastInteraction = now
        needs = Needs()
        weight = Rules.healthyWeight
    }

    public var isAlive: Bool { deathDate == nil }
    public var weightStage: WeightStage { WeightStage(weight: weight) }

    public func ageInDays(at now: Date) -> Int {
        let end = deathDate ?? now
        return max(0, Int(end.timeIntervalSince(birthDate) / 86400))
    }

    /// 0...100, how much dirt is in the room.
    public var roomCleanliness: Double { max(0, 100 - Double(poops.count) * 18) }

    /// 0...1: how much mud is caked on the coat. None until hygiene drops below 60.
    public var grime: Double {
        min(1, max(0, (60 - needs.hygiene) / 50))
    }

    public func condition(at now: Date) -> Condition {
        if !isAlive { return .dead }
        if weightStage.isDangerous { return .dying }
        if isSick { return .sick }
        if shine(at: now) > 0.05 { return .sparkly }
        if needs.hygiene < 20 { return .filthy }
        if needs.hygiene < 50 { return .dirty }
        if needs.hygiene >= 85 { return .clean }
        return .normal
    }

    /// 0...1: how shiny and sparkly the critter is after a bath. Fades with time and dirt.
    public func shine(at now: Date) -> Double {
        guard isAlive, let shineStart, let shineEnd, now < shineEnd, now >= shineStart else { return 0 }
        let timeLeft = shineEnd.timeIntervalSince(now) / shineEnd.timeIntervalSince(shineStart)
        let clean = min(1, max(0, (needs.hygiene - 50) / 40))
        return min(timeLeft, clean)
    }

    public func isIgnoring(at now: Date) -> Bool {
        guard let cooldownUntil else { return false }
        return now < cooldownUntil
    }

    public func missesYou(at now: Date) -> Bool {
        guard let missedYouUntil else { return false }
        return now < missedYouUntil
    }

    public func expression(at now: Date) -> Mood {
        if !isAlive { return .dead }
        if isAsleep { return .asleep }
        if isSick { return .sick }
        if isIgnoring(at: now) { return .ignoring }
        if missesYou(at: now) { return .excited }
        if weightStage.isDangerous { return .sad }
        if needs.hunger < 20 || needs.thirst < 20 { return .hungry }
        if needs.energy < 20 { return .sleepy }
        let mood = needs.average
        if mood >= 70 { return .happy }
        if mood < 35 { return .sad }
        return .content
    }
}

// MARK: - Real-time simulation

extension Pet {
    /// Brings the pet up to `now`, replaying every minute that passed (also while the app was closed).
    public mutating func advance(to now: Date) {
        while isAlive && lastUpdate < now {
            let stepEnd = min(now, lastUpdate.addingTimeInterval(Rules.simulationStep))
            step(hours: stepEnd.timeIntervalSince(lastUpdate) / 3600, endingAt: stepEnd)
            lastUpdate = stepEnd
        }
        if !isAlive { lastUpdate = max(lastUpdate, now) }
    }

    private func factor(_ trait: Trait) -> Double {
        genome.has(trait) ? Rules.traitFactor : 1
    }

    private mutating func step(hours dt: Double, endingAt time: Date) {
        let sick = isSick ? Rules.sickDecayFactor : 1
        let hungerThirst = isAsleep ? Rules.asleepHungerThirstFactor : 1

        needs.hunger -= Rules.hungerDecay * hungerThirst * factor(.glutton) * dt
        needs.thirst -= Rules.thirstDecay * hungerThirst * dt
        if isAsleep {
            needs.energy += Rules.energyGainAsleep * dt
        } else {
            needs.energy -= Rules.energyDecayAwake * sick * factor(.sleepyhead) * dt
        }
        needs.hygiene -= (Rules.hygieneDecay + Rules.hygieneDecayPerPoop * Double(poops.count)) * dt
        needs.fun -= Rules.funDecay * sick * factor(.energetic) * dt
        let independent = genome.has(.independent) ? 1 / Rules.traitFactor : 1
        needs.love -= Rules.loveDecay * sick * factor(.superCuddly) * independent * dt
        needs.clamp()

        if !isAsleep && needs.energy < Rules.fallAsleepBelowEnergy {
            isAsleep = true
        } else if isAsleep && needs.energy >= 100 {
            isAsleep = false
        }

        while let due = pendingPoops.first, due <= time {
            pendingPoops.removeFirst()
            dropPoop(at: due)
        }

        if poops.count >= Rules.dirtyPoopCount || needs.hygiene < Rules.dirtyHygieneBelow {
            dirtyHours += dt
            if dirtyHours >= Rules.hoursDirtyUntilSick { isSick = true }
        } else {
            dirtyHours = max(0, dirtyHours - dt)
        }

        updateWeight(hours: dt)

        if weight <= 0 {
            die(.starvation, at: time)
        } else if weight >= 100 {
            die(.overeating, at: time)
        }
    }

    private mutating func updateWeight(hours dt: Double) {
        if needs.hunger <= 0 {
            weight -= Rules.weightLossStarving * dt
        } else if needs.hunger < Rules.hungryBelow {
            weight -= Rules.weightLossHungry * dt
        } else if needs.hunger >= 30 {
            if weight < Rules.healthyWeight {
                weight = min(Rules.healthyWeight, weight + Rules.weightRecoveryRate * dt)
            } else if weight > Rules.healthyWeight {
                weight = max(Rules.healthyWeight, weight - Rules.weightSettleRate * dt)
            }
        }
        if needs.thirst <= 0 {
            weight -= Rules.weightLossDehydrated * dt
        }
    }

    private mutating func dropPoop(at date: Date) {
        var rng = SeededRandom(seed: genome.seed &+ UInt64(date.timeIntervalSince1970))
        poops.append(Poop(
            id: UUID(),
            x: Double.random(in: 0.08...0.92, using: &rng),
            y: Double.random(in: 0.15...0.95, using: &rng),
            createdAt: date
        ))
    }

    private mutating func die(_ cause: CauseOfDeath, at date: Date) {
        weight = weight.clamped()
        deathDate = date
        causeOfDeath = cause
        isAsleep = false
    }
}

// MARK: - Care actions

public enum FeedResult: Equatable, Sendable {
    case yummy, tooFull, asleep, dead
}

public enum StrokeResult: Equatable, Sendable {
    case loved(gain: Double)
    case nowFull
    case ignored
    case asleep
    case dead
}

extension Pet {
    /// Call when the player opens the game; a long absence makes the pet extra cuddly.
    @discardableResult
    public mutating func registerVisit(at now: Date) -> Bool {
        guard isAlive, now.timeIntervalSince(lastInteraction) >= Rules.missedYouAfter else { return false }
        missedYouUntil = now.addingTimeInterval(Rules.missedYouDuration)
        return true
    }

    public mutating func feed(_ food: FoodEffect, at now: Date) -> FeedResult {
        guard isAlive else { return .dead }
        guard !isAsleep else { return .asleep }
        let wasFull = needs.hunger >= 85
        needs.hunger += food.hunger
        let overflow = max(0, needs.hunger - 100)
        weight += overflow * Rules.overflowToWeight + food.fattening
        needs.fun += food.fun
        needs.thirst += food.thirst
        needs.clamp()
        if food.hunger > 0 {
            pendingPoops.append(now.addingTimeInterval(Rules.digestionDelay))
            pendingPoops.sort()
        }
        touch(now)
        checkOvereating(at: now)
        return wasFull || overflow > 0 ? .tooFull : .yummy
    }

    public mutating func drink(_ amount: Double, at now: Date) -> Bool {
        guard isAlive, !isAsleep else { return false }
        needs.thirst = (needs.thirst + amount).clamped()
        touch(now)
        return true
    }

    public mutating func stroke(at now: Date) -> StrokeResult {
        guard isAlive else { return .dead }
        guard !isAsleep else { return .asleep }
        if isIgnoring(at: now) { return .ignored }
        let gain = Rules.strokeLove * (missesYou(at: now) ? 2 : 1)
        needs.love = (needs.love + gain).clamped()
        touch(now)
        if needs.love >= 100 {
            cooldownUntil = now.addingTimeInterval(Rules.loveFullCooldown)
            missedYouUntil = nil
            return .nowFull
        }
        return .loved(gain: gain)
    }

    public mutating func play(at now: Date, fun: Double = 12, energy: Double = 4) -> Bool {
        guard isAlive, !isAsleep, needs.energy >= 5 else { return false }
        needs.fun += fun
        needs.energy -= energy
        needs.love += 2
        needs.clamp()
        exercise(by: energy / 8)
        touch(now)
        return true
    }

    public mutating func goToSleep(at now: Date) -> Bool {
        guard isAlive, !isAsleep, needs.energy < 95 else { return false }
        isAsleep = true
        touch(now)
        return true
    }

    public mutating func wakeUp(at now: Date) {
        guard isAlive, isAsleep else { return }
        isAsleep = false
        if needs.energy < 60 { needs.fun = (needs.fun - 5).clamped() }
        touch(now)
    }

    @discardableResult
    public mutating func scoop(_ poopID: UUID) -> Bool {
        guard let index = poops.firstIndex(where: { $0.id == poopID }) else { return false }
        poops.remove(at: index)
        return true
    }

    public mutating func bathe(at now: Date, shampoo: Bool = false) {
        guard isAlive else { return }
        shineStart = now
        shineEnd = now.addingTimeInterval(shampoo ? Rules.shampooShineDuration : Rules.shineDuration)
        needs.hygiene = 100
        needs.fun = (needs.fun + (genome.has(.lovesBaths) ? 10 : -5)).clamped()
        dirtyHours = 0
        touch(now)
    }

    public mutating func visitPark(at now: Date) {
        guard isAlive else { return }
        let lover = genome.has(.parkLover) ? 1.5 : 1
        needs.fun += 30 * lover
        needs.energy -= 15
        needs.hygiene -= 15
        needs.thirst -= 10
        needs.love += 5
        needs.clamp()
        exercise(by: 3)
        touch(now)
    }

    public mutating func cure(at now: Date) {
        guard isAlive else { return }
        isSick = false
        dirtyHours = 0
        touch(now)
    }

    private mutating func exercise(by amount: Double) {
        if weight > Rules.healthyWeight {
            weight = max(Rules.healthyWeight, weight - amount)
        }
    }

    private mutating func touch(_ now: Date) {
        lastInteraction = max(lastInteraction, now)
    }

    private mutating func checkOvereating(at now: Date) {
        if weight >= 100 { die(.overeating, at: now) }
    }
}

extension Double {
    func clamped(_ low: Double = 0, _ high: Double = 100) -> Double {
        Swift.min(high, Swift.max(low, self))
    }
}
