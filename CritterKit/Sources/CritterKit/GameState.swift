import Foundation

public struct PlacedDecor: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let itemID: String
    /// Normalised position inside the room, 0...1 on both axes.
    public var x: Double
    public var y: Double
    public var flipped: Bool

    public init(itemID: String, x: Double, y: Double, flipped: Bool = false) {
        id = UUID()
        self.itemID = itemID
        self.x = x
        self.y = y
        self.flipped = flipped
    }
}

public struct MemorialEntry: Codable, Equatable, Identifiable, Sendable {
    public let id: UUID
    public let name: String
    public let genome: Genome
    public let birthDate: Date
    public let deathDate: Date
    public let cause: CauseOfDeath
    public var candles: Int

    public var daysLived: Int { max(0, Int(deathDate.timeIntervalSince(birthDate) / 86400)) }

    public var epitaph: String {
        let loved: String = switch genome.traits.first {
        case .glutton: "Never said no to a snack."
        case .superCuddly: "Gave the best cuddles."
        case .energetic, .parkLover: "Fastest fetcher in the park."
        case .sleepyhead: "Champion napper."
        case .shy: "Quiet, gentle and sweet."
        case .fussyEater: "Only ate the very best fish."
        case .independent: "Did things their own way."
        case .lovesBaths: "Loved a bubbly bath."
        case .curious: "Sniffed out every secret."
        case nil: "A very good critter."
        }
        let ending = switch cause {
        case .starvation: "Missed us while we were away."
        case .overeating: "One cupcake too many."
        }
        return "\(loved) \(ending)"
    }
}

public enum PurchaseResult: Equatable, Sendable {
    case bought, notEnoughCoins, unknownItem
}

public struct GameState: Codable, Equatable, Sendable {
    public static let currentVersion = 1

    public var version = GameState.currentVersion
    public var pet: Pet?
    public private(set) var coins: Int
    public private(set) var inventory: [String: Int]
    public private(set) var room: [PlacedDecor]
    public private(set) var memorial: [MemorialEntry]
    public private(set) var piggyBank: Double
    public private(set) var lastDailyGift: Date?
    public private(set) var giftStreak: Int
    public private(set) var lastUpdate: Date

    public init(now: Date) {
        coins = Rules.startingCoins
        inventory = ["kibble": 5, "water": 5, "cupcake": 1]
        room = []
        memorial = []
        piggyBank = 0
        giftStreak = 0
        lastUpdate = now
    }

    public var cosiness: Int {
        min(100, 20 + room.compactMap { Catalog.item($0.itemID)?.cosiness }.reduce(0, +))
    }

    public func count(of itemID: String) -> Int { inventory[itemID, default: 0] }

    // MARK: Time

    /// Advances the world in one-hour slices so the piggy bank sees mood changes along the way.
    public mutating func advance(to now: Date) {
        while lastUpdate < now {
            let sliceEnd = min(now, lastUpdate.addingTimeInterval(3600))
            let hours = sliceEnd.timeIntervalSince(lastUpdate) / 3600
            pet?.advance(to: sliceEnd)
            if let pet, pet.isAlive, !pet.isAsleep, pet.needs.average >= Rules.piggyMoodThreshold {
                piggyBank = min(Rules.piggyCap, piggyBank + Rules.piggyRatePerHour * hours)
            }
            lastUpdate = sliceEnd
        }
    }

    // MARK: Pets

    public mutating func adopt(genome: Genome, name: String, now: Date) -> Bool {
        guard pet == nil else { return false }
        pet = Pet(name: name, genome: genome, now: now)
        return true
    }

    /// Moves a pet that has died into the memorial so a new one can be adopted.
    public mutating func sayGoodbye() {
        guard let pet, let death = pet.deathDate, let cause = pet.causeOfDeath else { return }
        memorial.insert(MemorialEntry(id: pet.id, name: pet.name, genome: pet.genome, birthDate: pet.birthDate, deathDate: death, cause: cause, candles: 0), at: 0)
        self.pet = nil
    }

    public mutating func lightCandle(for entryID: UUID) {
        guard let index = memorial.firstIndex(where: { $0.id == entryID }) else { return }
        memorial[index].candles += 1
    }

    // MARK: Shopping

    public mutating func buy(_ itemID: String, quantity: Int = 1) -> PurchaseResult {
        guard let item = Catalog.item(itemID) else { return .unknownItem }
        let cost = item.price * quantity
        guard coins >= cost else { return .notEnoughCoins }
        coins -= cost
        inventory[itemID, default: 0] += item.packSize * quantity
        return .bought
    }

    public mutating func earn(_ amount: Int) {
        coins += max(0, amount)
    }

    private mutating func consume(_ itemID: String) -> Bool {
        guard count(of: itemID) > 0 else { return false }
        inventory[itemID]! -= 1
        if inventory[itemID] == 0 { inventory[itemID] = nil }
        return true
    }

    // MARK: Care

    public mutating func feed(_ itemID: String, now: Date) -> FeedResult? {
        guard let effect = Catalog.item(itemID)?.foodEffect, var pet, pet.isAlive, !pet.isAsleep else { return nil }
        guard consume(itemID) else { return nil }
        let result = pet.feed(effect, at: now)
        self.pet = pet
        return result
    }

    public mutating func refillWater(now: Date) -> Bool {
        guard case .water(let amount) = Catalog.item("water")?.kind, var pet, pet.isAlive, !pet.isAsleep, count(of: "water") > 0 else { return false }
        _ = consume("water")
        let drank = pet.drink(amount, at: now)
        self.pet = pet
        return drank
    }

    public mutating func giveMedicine(now: Date) -> Bool {
        guard var pet, pet.isAlive, pet.isSick, consume("medicine") else { return false }
        pet.cure(at: now)
        self.pet = pet
        return true
    }

    /// Returns the coins earned, or nil if that poop was already gone.
    public mutating func scoop(_ poopID: UUID) -> Int? {
        guard var pet, pet.scoop(poopID) else { return nil }
        self.pet = pet
        coins += Rules.scoopReward
        return Rules.scoopReward
    }

    public mutating func finishBath(useShampoo: Bool, now: Date) -> Int {
        guard var pet, pet.isAlive else { return 0 }
        let shampoo = useShampoo && consume("shampoo")
        pet.bathe(at: now, shampoo: shampoo)
        if shampoo {
            pet.needs.love = min(100, pet.needs.love + 10)
            pet.needs.fun = min(100, pet.needs.fun + 10)
        }
        self.pet = pet
        coins += Rules.bathReward
        return Rules.bathReward
    }

    public mutating func finishPark(coinsFound: Int, now: Date) {
        guard var pet, pet.isAlive else { return }
        pet.visitPark(at: now)
        self.pet = pet
        earn(coinsFound)
    }

    // MARK: Rewards

    /// One gift per calendar day; coming back on consecutive days grows the gift.
    public mutating func claimDailyGift(now: Date, calendar: Calendar = .current) -> Int? {
        if let last = lastDailyGift {
            if calendar.isDate(last, inSameDayAs: now) { return nil }
            let yesterday = calendar.date(byAdding: .day, value: -1, to: now)!
            giftStreak = calendar.isDate(last, inSameDayAs: yesterday) ? giftStreak + 1 : 1
        } else {
            giftStreak = 1
        }
        lastDailyGift = now
        let amount = min(Rules.dailyGiftMax, Rules.dailyGiftBase + Rules.dailyGiftStreakBonus * (giftStreak - 1))
        coins += amount
        return amount
    }

    public mutating func collectPiggyBank() -> Int {
        let amount = Int(piggyBank)
        coins += amount
        piggyBank -= Double(amount)
        return amount
    }

    // MARK: Decor

    public mutating func place(_ itemID: String, x: Double, y: Double) -> PlacedDecor? {
        guard Catalog.item(itemID)?.decorLayer != nil, consume(itemID) else { return nil }
        let placed = PlacedDecor(itemID: itemID, x: x.clamped(0, 1), y: y.clamped(0, 1))
        room.append(placed)
        return placed
    }

    public mutating func move(_ decorID: UUID, x: Double, y: Double) {
        guard let index = room.firstIndex(where: { $0.id == decorID }) else { return }
        room[index].x = x.clamped(0, 1)
        room[index].y = y.clamped(0, 1)
    }

    public mutating func flip(_ decorID: UUID) {
        guard let index = room.firstIndex(where: { $0.id == decorID }) else { return }
        room[index].flipped.toggle()
    }

    public mutating func putAway(_ decorID: UUID) {
        guard let index = room.firstIndex(where: { $0.id == decorID }) else { return }
        inventory[room[index].itemID, default: 0] += 1
        room.remove(at: index)
    }
}
