public struct FoodEffect: Equatable, Sendable {
    public let hunger: Double
    public let thirst: Double
    public let fun: Double
    /// Extra weight on top of any overflow; treats are fattening.
    public let fattening: Double

    public init(hunger: Double, thirst: Double = 0, fun: Double = 0, fattening: Double = 0) {
        self.hunger = hunger
        self.thirst = thirst
        self.fun = fun
        self.fattening = fattening
    }
}

public enum Aisle: String, CaseIterable, Sendable {
    case food, drinks, treats, bath, medicine

    public var title: String {
        switch self {
        case .food: "Food"
        case .drinks: "Drinks"
        case .treats: "Treats"
        case .bath: "Bath stuff"
        case .medicine: "Medicine"
        }
    }
}

public enum DecorLayer: String, Codable, Sendable {
    case wall, floor
}

public enum DecorCategory: String, CaseIterable, Sendable {
    case furniture, walls, plants, lights

    public var title: String {
        switch self {
        case .furniture: "Furniture"
        case .walls: "Walls"
        case .plants: "Plants"
        case .lights: "Lights"
        }
    }
}

public enum ItemKind: Equatable, Sendable {
    case food(FoodEffect)
    case water(Double)
    case medicine
    case shampoo
    case decor(category: DecorCategory, layer: DecorLayer, cosiness: Int)
}

public struct Item: Identifiable, Equatable, Sendable {
    public let id: String
    public let name: String
    public let price: Int
    public let blurb: String
    public let kind: ItemKind
    /// Store bundles, e.g. kibble comes in fives.
    public let packSize: Int

    public var aisle: Aisle? {
        switch kind {
        case .food(let effect): effect.fattening > 0 ? .treats : .food
        case .water: .drinks
        case .shampoo: .bath
        case .medicine: .medicine
        case .decor: nil
        }
    }

    public var foodEffect: FoodEffect? {
        if case .food(let effect) = kind { return effect }
        return nil
    }

    public var decorLayer: DecorLayer? {
        if case .decor(_, let layer, _) = kind { return layer }
        return nil
    }

    public var cosiness: Int {
        if case .decor(_, _, let cosiness) = kind { return cosiness }
        return 0
    }

    public var decorCategory: DecorCategory? {
        if case .decor(let category, _, _) = kind { return category }
        return nil
    }
}

public enum Catalog {
    public static let items: [Item] = [
        Item(id: "kibble", name: "Kibble", price: 10, blurb: "+20 hunger", kind: .food(FoodEffect(hunger: 20)), packSize: 5),
        Item(id: "fish", name: "Fresh fish", price: 8, blurb: "+35 hunger", kind: .food(FoodEffect(hunger: 35)), packSize: 1),
        Item(id: "carrot", name: "Crunchy carrot", price: 4, blurb: "+15 hunger", kind: .food(FoodEffect(hunger: 15)), packSize: 1),
        Item(id: "berries", name: "Moon berries", price: 6, blurb: "+10 hunger, +5 fun", kind: .food(FoodEffect(hunger: 10, thirst: 5, fun: 5)), packSize: 1),
        Item(id: "cupcake", name: "Cupcake", price: 5, blurb: "+15 fun, fattening", kind: .food(FoodEffect(hunger: 10, fun: 15, fattening: 6)), packSize: 1),
        Item(id: "cookie", name: "Star cookie", price: 3, blurb: "+8 fun, fattening", kind: .food(FoodEffect(hunger: 6, fun: 8, fattening: 3)), packSize: 1),
        Item(id: "water", name: "Spring water", price: 5, blurb: "Fills the bowl", kind: .water(45), packSize: 5),
        Item(id: "shampoo", name: "Bubble shampoo", price: 12, blurb: "Extra sparkly bath", kind: .shampoo, packSize: 3),
        Item(id: "medicine", name: "Feel-good pill", price: 20, blurb: "Cures sickness", kind: .medicine, packSize: 1),

        Item(id: "sofa", name: "Cloud sofa", price: 150, blurb: "So squishy", kind: .decor(category: .furniture, layer: .floor, cosiness: 18), packSize: 1),
        Item(id: "royalBed", name: "Royal bed", price: 120, blurb: "Sweet dreams", kind: .decor(category: .furniture, layer: .floor, cosiness: 15), packSize: 1),
        Item(id: "bookshelf", name: "Bookshelf", price: 90, blurb: "Very clever", kind: .decor(category: .furniture, layer: .floor, cosiness: 10), packSize: 1),
        Item(id: "rug", name: "Heart rug", price: 45, blurb: "Soft paws", kind: .decor(category: .furniture, layer: .floor, cosiness: 8), packSize: 1),
        Item(id: "fern", name: "Fluffy fern", price: 35, blurb: "Fresh air", kind: .decor(category: .plants, layer: .floor, cosiness: 6), packSize: 1),
        Item(id: "cactus", name: "Smiley cactus", price: 25, blurb: "Don't hug", kind: .decor(category: .plants, layer: .floor, cosiness: 4), packSize: 1),
        Item(id: "moonLamp", name: "Moon lamp", price: 60, blurb: "Cosy glow", kind: .decor(category: .lights, layer: .floor, cosiness: 9), packSize: 1),
        Item(id: "fairyLights", name: "Fairy lights", price: 40, blurb: "Twinkle", kind: .decor(category: .lights, layer: .wall, cosiness: 8), packSize: 1),
        Item(id: "starPoster", name: "Star poster", price: 25, blurb: "Shine on", kind: .decor(category: .walls, layer: .wall, cosiness: 4), packSize: 1),
        Item(id: "clock", name: "Cuckoo clock", price: 55, blurb: "Tick tock", kind: .decor(category: .walls, layer: .wall, cosiness: 6), packSize: 1),
        Item(id: "rainbow", name: "Rainbow art", price: 30, blurb: "Happy colours", kind: .decor(category: .walls, layer: .wall, cosiness: 5), packSize: 1),
    ]

    public static func item(_ id: String) -> Item? {
        items.first { $0.id == id }
    }

    public static func items(in aisle: Aisle) -> [Item] {
        items.filter { $0.aisle == aisle }
    }

    public static func decor(in category: DecorCategory) -> [Item] {
        items.filter { $0.decorCategory == category }
    }
}
