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

/// The art style a critter is drawn in, picked when it hatches.
public enum CritterStyle: String, Codable, CaseIterable, Sendable {
    case vinyl, chibi, plush, doodle

    public var title: String {
        switch self {
        case .vinyl: "Mjuk vinyl"
        case .chibi: "Tecknad"
        case .plush: "Gosedjur"
        case .doodle: "Kludd"
        }
    }
}

/// How the critter looks overall, from freshly bathed to fading away.
public enum Condition: String, Sendable {
    case sparkly, clean, normal, dirty, filthy, sick, dying, dead
}

public enum Mood: String, Sendable {
    case dead, asleep, sick, furious, ignoring, excited, happy, content, hungry, sleepy, sad
}

/// How cross it is with you. Each step only comes from bothering it while it already wants space.
public enum Temper: Int, Comparable, Sendable {
    case calm, grumpy, upset, furious

    public static func < (lhs: Temper, rhs: Temper) -> Bool { lhs.rawValue < rhs.rawValue }
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
    /// While set and in the future, it wants to be left alone (no cuddles).
    public private(set) var cooldownUntil: Date?
    /// Food or drink during the cooldown takes the grumpiness away; it still wants space.
    public private(set) var soothed: Bool?
    public private(set) var lastStroke: Date?
    public private(set) var lastTickle: Date?
    /// Strokes given after love was already full.
    public private(set) var overPets: Int?
    /// 0...100: builds up while you keep bothering it after it asked to be left alone; fades with time.
    public private(set) var annoyance: Double?
    public private(set) var lastBother: Date?
    /// After sweets it beams for a while.
    public private(set) var sweetJoyUntil: Date?
    public private(set) var missedYouUntil: Date?
    public private(set) var deathDate: Date?
    public private(set) var causeOfDeath: CauseOfDeath?
    /// When the post-bath shine started and when it wears off.
    public private(set) var shineStart: Date?
    public private(set) var shineEnd: Date?
    /// Optional so saves from before styles existed still load; they are drawn as vinyl.
    public var style: CritterStyle?

    public var appearance: CritterStyle { style ?? .vinyl }

    public init(name: String, genome: Genome, style: CritterStyle = .vinyl, now: Date) {
        self.style = style
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

    public var annoyanceLevel: Double { annoyance ?? 0 }

    /// Wants to be left alone: cuddles are turned down.
    public func isIgnoring(at now: Date) -> Bool {
        if annoyanceLevel >= Rules.upsetAt { return true }
        guard let cooldownUntil else { return false }
        return now < cooldownUntil
    }

    public func temper(at now: Date) -> Temper {
        guard isAlive else { return .calm }
        if annoyanceLevel >= Rules.furiousAt { return .furious }
        if annoyanceLevel >= Rules.upsetAt { return .upset }
        return isGrumpy(at: now) ? .grumpy : .calm
    }

    /// Wants to be alone and is cross about it. Food or drink fixes the cross part.
    public func isGrumpy(at now: Date) -> Bool {
        isIgnoring(at: now) && soothed != true
    }

    public func isBeaming(at now: Date) -> Bool {
        guard let sweetJoyUntil else { return false }
        return now < sweetJoyUntil
    }

    public func missesYou(at now: Date) -> Bool {
        guard let missedYouUntil else { return false }
        return now < missedYouUntil
    }

    public func expression(at now: Date) -> Mood {
        if !isAlive { return .dead }
        if isAsleep { return .asleep }
        if isSick { return .sick }
        switch temper(at: now) {
        case .furious: return .furious
        case .upset: return .sad
        case .grumpy: return .ignoring
        case .calm: break
        }
        if missesYou(at: now) { return .excited }
        if isBeaming(at: now) { return .happy }
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
        if let annoyance, annoyance > 0 {
            self.annoyance = max(0, annoyance - Rules.annoyanceDecay * dt)
        }

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
    /// Too soon after the last stroke to count. Nothing changes.
    case tooSoon
    /// Love just became full. Happy, not grumpy.
    case nowFull
    /// Love is full and you keep going: "that's enough soon".
    case enough
    /// You kept going after the warning: now it wants to be left alone.
    case grumpy
    case ignored
    case asleep
    case dead
}

public enum TickleResult: Equatable, Sendable {
    case giggled
    case tooSoon
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
        needs.love += food.love
        needs.clamp()
        if food.isSweet { sweetJoyUntil = now.addingTimeInterval(Rules.sweetJoyDuration) }
        soothe(at: now)
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
        soothe(at: now)
        touch(now)
        return true
    }

    public mutating func stroke(at now: Date) -> StrokeResult {
        guard isAlive else { return .dead }
        guard !isAsleep else { return .asleep }
        if isIgnoring(at: now) {
            bother(at: now)
            return .ignored
        }
        if let lastStroke, now.timeIntervalSince(lastStroke) < Rules.strokeInterval { return .tooSoon }
        if let lastStroke, now.timeIntervalSince(lastStroke) > Rules.overPetForgiveAfter { overPets = nil }
        lastStroke = now
        touch(now)
        if needs.love >= Rules.loveFullAt {
            let count = (overPets ?? 0) + 1
            overPets = count
            if count >= Rules.overPetLimit {
                cooldownUntil = now.addingTimeInterval(Rules.loveFullCooldown)
                soothed = false
                overPets = nil
                missedYouUntil = nil
                return .grumpy
            }
            return count >= Rules.overPetWarning ? .enough : .loved(gain: 0)
        }
        let gain = Rules.strokeLove * (missesYou(at: now) ? 2 : 1)
        needs.love = (needs.love + gain).clamped()
        overPets = nil
        return needs.love >= Rules.loveFullAt ? .nowFull : .loved(gain: gain)
    }

    public mutating func tickle(at now: Date) -> TickleResult {
        guard isAlive else { return .dead }
        guard !isAsleep else { return .asleep }
        if isIgnoring(at: now) {
            bother(at: now)
            return .ignored
        }
        if let lastTickle, now.timeIntervalSince(lastTickle) < Rules.tickleInterval { return .tooSoon }
        lastTickle = now
        needs.fun += Rules.tickleFun
        needs.love += Rules.tickleLove
        needs.clamp()
        touch(now)
        return .giggled
    }

    /// A tap on the critter. Only matters when it wants to be left alone: then it counts as bothering it.
    @discardableResult
    public mutating func poke(at now: Date) -> Bool {
        guard isAlive, !isAsleep, isIgnoring(at: now) else { return false }
        bother(at: now)
        return true
    }

    /// Bothering it while it wants space: it stays cross for longer, and keeping on makes it sad, then furious.
    /// Counted at most once per `botherInterval`, so it takes long, sustained pestering to get there.
    private mutating func bother(at now: Date) {
        if let lastBother, now.timeIntervalSince(lastBother) < Rules.botherInterval { return }
        lastBother = now
        annoyance = min(Rules.annoyanceMax, annoyanceLevel + Rules.annoyancePerBother)
        soothed = false
        cooldownUntil = max(cooldownUntil ?? now, now.addingTimeInterval(Rules.loveFullCooldown))
    }

    /// Food and drink take the grumpiness away and calm a sad or furious critter down a good bit,
    /// but it still wants to be left alone for now.
    private mutating func soothe(at now: Date) {
        if annoyanceLevel > 0 { annoyance = max(0, annoyanceLevel - Rules.treatCalms) }
        if isIgnoring(at: now) { soothed = true }
    }

    /// Playing on its own while you're away: a little fun, no attention from you.
    public mutating func amuseItself(fun: Double, energy: Double = 0) {
        guard isAlive, !isAsleep else { return }
        needs.fun += fun
        needs.energy -= energy
        needs.clamp()
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
