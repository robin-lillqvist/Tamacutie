import Foundation

/// One bath, step by step. Positions are normalised to the critter's 0...1 frame.
public struct BathSession: Sendable {
    public enum Step: Int, CaseIterable, Sendable {
        case fill, scrub, rinse, dry, done
    }

    /// A mud spot, a foam blob or a water drop on the critter.
    public struct Mark: Identifiable, Equatable, Sendable {
        public let id: Int
        public let x: Double
        public let y: Double
        public let size: Double
        public var amount: Double
    }

    public static let fillSeconds = 2.5
    public static let toolRadius = 0.13
    public static let foamGoal = 10

    public private(set) var step = Step.fill
    public private(set) var water = 0.0
    public private(set) var isFilling = false
    public private(set) var dirt: [Mark]
    public private(set) var foam: [Mark] = []
    public private(set) var drops: [Mark] = []
    private let initialDirt: Double
    private var nextID = 1000
    private var rng: SeededRandom

    /// `dirtiness` is 0...1; a grubbier critter gets more and darker mud spots.
    public init(seed: UInt64, dirtiness: Double) {
        rng = SeededRandom(seed: seed)
        let count = 3 + Int(min(1, max(0, dirtiness)) * 6)
        var spots: [Mark] = []
        for index in 0..<count {
            // Mud lands on the head, cheeks and sides, never over the eyes and mouth.
            var x = 0.5
            var y = 0.5
            repeat {
                x = Double.random(in: 0.24...0.76, using: &rng)
                y = Double.random(in: 0.34...0.68, using: &rng)
            } while hypot(x - 0.5, y - 0.57) < 0.21
            spots.append(Mark(
                id: index,
                x: x,
                y: y,
                size: Double.random(in: 0.05...0.09, using: &rng),
                amount: 0.5 + 0.5 * min(1, max(0, dirtiness))
            ))
        }
        dirt = spots
        initialDirt = spots.reduce(0) { $0 + $1.amount }
    }

    /// 0...1 progress through the current step, for the sparkle meter.
    public var stepProgress: Double {
        switch step {
        case .fill: water
        case .scrub: 0.7 * cleaned + 0.3 * min(1, Double(foam.count) / Double(Self.foamGoal))
        case .rinse: foam.isEmpty ? 1 : 1 - foam.reduce(0) { $0 + $1.amount } / Double(max(foam.count, Self.foamGoal))
        case .dry: drops.isEmpty ? 1 : 1 - drops.reduce(0) { $0 + $1.amount } / 12
        case .done: 1
        }
    }

    /// 0...1 over the whole bath.
    public var overallProgress: Double {
        step == .done ? 1 : (Double(step.rawValue) + stepProgress) / 4
    }

    public var cleaned: Double {
        guard initialDirt > 0 else { return 1 }
        return 1 - dirt.reduce(0) { $0 + $1.amount } / initialDirt
    }

    // MARK: Fill

    public mutating func turnOnTap() {
        guard step == .fill else { return }
        isFilling = true
    }

    /// Advances running water. Returns true when the tub just became full.
    public mutating func update(_ dt: Double) -> Bool {
        guard isFilling, step == .fill else { return false }
        water = min(1, water + dt / Self.fillSeconds)
        if water >= 1 {
            isFilling = false
            step = .scrub
            return true
        }
        return false
    }

    // MARK: Scrub

    /// Rubs the sponge at a point; returns true if this stroke made new foam.
    @discardableResult
    public mutating func scrub(at x: Double, _ y: Double) -> Bool {
        guard step == .scrub else { return false }
        for index in dirt.indices where distance(dirt[index], x, y) < Self.toolRadius + dirt[index].size {
            dirt[index].amount = max(0, dirt[index].amount - 0.035)
        }
        dirt.removeAll { $0.amount <= 0.02 }
        var madeFoam = false
        if onBody(x, y), foam.count < 40, !foam.contains(where: { distance($0, x, y) < 0.06 }) {
            foam.append(Mark(id: makeID(), x: x, y: y, size: Double.random(in: 0.05...0.08, using: &rng), amount: 1))
            madeFoam = true
        }
        if dirt.isEmpty, foam.count >= Self.foamGoal {
            step = .rinse
        }
        return madeFoam
    }

    // MARK: Rinse

    /// The shower stream hits the critter at `x`; foam under it washes away and leaves drops behind.
    public mutating func rinse(atX x: Double, dt: Double) {
        guard step == .rinse else { return }
        for index in foam.indices where abs(foam[index].x - x) < 0.12 {
            foam[index].amount -= dt * 1.6
        }
        let washed = foam.filter { $0.amount <= 0 }
        foam.removeAll { $0.amount <= 0 }
        for blob in washed where drops.count < 14 {
            drops.append(Mark(id: makeID(), x: blob.x, y: min(0.7, blob.y + 0.03), size: 0.03, amount: 1))
        }
        if foam.isEmpty {
            while drops.count < 8 {
                drops.append(Mark(
                    id: makeID(),
                    x: Double.random(in: 0.3...0.7, using: &rng),
                    y: Double.random(in: 0.34...0.66, using: &rng),
                    size: 0.03,
                    amount: 1
                ))
            }
            step = .dry
        }
    }

    // MARK: Dry

    public mutating func dry(at x: Double, _ y: Double) {
        guard step == .dry else { return }
        for index in drops.indices where distance(drops[index], x, y) < Self.toolRadius + 0.04 {
            drops[index].amount -= 0.12
        }
        drops.removeAll { $0.amount <= 0 }
        if drops.isEmpty {
            step = .done
        }
    }

    // MARK: Helpers

    private func onBody(_ x: Double, _ y: Double) -> Bool {
        (0.18...0.82).contains(x) && (0.26...0.72).contains(y)
    }

    private func distance(_ mark: Mark, _ x: Double, _ y: Double) -> Double {
        hypot(mark.x - x, mark.y - y)
    }

    private mutating func makeID() -> Int {
        nextID += 1
        return nextID
    }
}
