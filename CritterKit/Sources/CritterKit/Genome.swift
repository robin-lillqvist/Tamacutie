import Foundation

public enum BodyShape: String, Codable, CaseIterable, Sendable {
    case round, bean, blob
}

public enum HeadFeature: String, Codable, CaseIterable, Sendable {
    case floppyEars, pointyEars, antennae, roundEars, finAndHorns, sprout
}

public enum EyeStyle: String, Codable, CaseIterable, Sendable {
    case big, cyclops
}

public enum TailStyle: String, Codable, CaseIterable, Sendable {
    case none, lightning, fin
}

public enum Marking: String, Codable, CaseIterable, Sendable {
    case none, spots, sparkles, forehead
}

public struct Palette: Codable, Equatable, Sendable {
    public let name: String
    public let body: UInt32
    public let belly: UInt32
    public let shade: UInt32
    public let stage: UInt32

    public static let all: [Palette] = [
        Palette(name: "Tuggummi", body: 0xFF9EB5, belly: 0xFFD1DC, shade: 0xF27D9B, stage: 0xFFEFF3),
        Palette(name: "Mint", body: 0x7ED9C3, belly: 0xC9F2E6, shade: 0x5CC2A8, stage: 0xE6F8F2),
        Palette(name: "Lavendel", body: 0xC3A8FF, belly: 0xE2D6FF, shade: 0xA98BFF, stage: 0xF1EAFF),
        Palette(name: "Smör", body: 0xFFD66B, belly: 0xFFF1C4, shade: 0xF5B83D, stage: 0xFFF6D9),
        Palette(name: "Himmel", body: 0x8EC9FF, belly: 0xD6ECFF, shade: 0x5AA9F0, stage: 0xE4F2FF),
        Palette(name: "Persika", body: 0xFFB38A, belly: 0xFFE0CC, shade: 0xF2956A, stage: 0xFFEDE2),
        Palette(name: "Mandarin", body: 0xFF9550, belly: 0xFFE2CC, shade: 0xEB7432, stage: 0xFFEADF),
        Palette(name: "Druva", body: 0xA285EE, belly: 0xE6DCFF, shade: 0x8563DE, stage: 0xF0EAFF),
        Palette(name: "Löv", body: 0x8FD16B, belly: 0xE0F5D1, shade: 0x6DB64A, stage: 0xEAF7E2),
        Palette(name: "Körsbär", body: 0xFF6F86, belly: 0xFFD8DF, shade: 0xE5506A, stage: 0xFFE8EC),
    ]
}

public enum Trait: String, Codable, CaseIterable, Sendable {
    case glutton, superCuddly, energetic, parkLover, sleepyhead, shy, fussyEater, independent, lovesBaths, curious

    public var title: String {
        switch self {
        case .glutton: "Matvrak"
        case .superCuddly: "Supergosig"
        case .energetic: "Pigg"
        case .parkLover: "Älskar parken"
        case .sleepyhead: "Sjusovare"
        case .shy: "Blyg"
        case .fussyEater: "Kräsen"
        case .independent: "Självständig"
        case .lovesBaths: "Älskar bad"
        case .curious: "Nyfiken"
        }
    }
}

public struct Genome: Codable, Equatable, Sendable {
    public let seed: UInt64
    public let body: BodyShape
    public let head: HeadFeature
    public let eyes: EyeStyle
    public let tail: TailStyle
    public let marking: Marking
    public let paletteIndex: Int
    public let traits: [Trait]

    public var palette: Palette { Palette.all[paletteIndex % Palette.all.count] }

    public func has(_ trait: Trait) -> Bool { traits.contains(trait) }

    public init(seed: UInt64) {
        var rng = SeededRandom(seed: seed)
        self.seed = seed
        body = BodyShape.allCases.randomElement(using: &rng)!
        head = HeadFeature.allCases.randomElement(using: &rng)!
        // Cyclops is a rare treat.
        eyes = Int.random(in: 0..<5, using: &rng) == 0 ? .cyclops : .big
        tail = TailStyle.allCases.randomElement(using: &rng)!
        marking = Marking.allCases.randomElement(using: &rng)!
        paletteIndex = Int.random(in: 0..<Palette.all.count, using: &rng)
        traits = Array(Trait.allCases.shuffled(using: &rng).prefix(2))
    }

    public init(seed: UInt64, body: BodyShape, head: HeadFeature, eyes: EyeStyle, tail: TailStyle, marking: Marking, paletteIndex: Int, traits: [Trait]) {
        self.seed = seed
        self.body = body
        self.head = head
        self.eyes = eyes
        self.tail = tail
        self.marking = marking
        self.paletteIndex = paletteIndex
        self.traits = traits
    }

    public static func random() -> Genome {
        Genome(seed: UInt64.random(in: .min ... .max))
    }
}
