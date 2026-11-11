public struct FoodEffect: Equatable, Sendable {
    public let hunger: Double
    public let thirst: Double
    public let fun: Double
    /// Extra weight on top of any overflow; treats are fattening.
    public let fattening: Double
    /// Sweets: love on top, and a happy face for a while.
    public let love: Double

    public init(hunger: Double, thirst: Double = 0, fun: Double = 0, fattening: Double = 0, love: Double = 0) {
        self.hunger = hunger
        self.thirst = thirst
        self.fun = fun
        self.fattening = fattening
        self.love = love
    }

    public var isSweet: Bool { love > 0 }
}

public enum Aisle: String, CaseIterable, Sendable {
    case food, drinks, treats, bath, medicine

    public var title: String {
        switch self {
        case .food: "Mat"
        case .drinks: "Dricka"
        case .treats: "Godis"
        case .bath: "Badsaker"
        case .medicine: "Medicin"
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
        case .furniture: "Möbler"
        case .walls: "Väggar"
        case .plants: "Växter"
        case .lights: "Lampor"
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
        Item(id: "kibble", name: "Foderkulor", price: 10, blurb: "+20 mat", kind: .food(FoodEffect(hunger: 20)), packSize: 5),
        Item(id: "fish", name: "Färsk fisk", price: 8, blurb: "+35 mat", kind: .food(FoodEffect(hunger: 35)), packSize: 1),
        Item(id: "carrot", name: "Knaprig morot", price: 4, blurb: "+15 mat", kind: .food(FoodEffect(hunger: 15)), packSize: 1),
        Item(id: "berries", name: "Månbär", price: 6, blurb: "+10 mat, +5 kul", kind: .food(FoodEffect(hunger: 10, thirst: 5, fun: 5)), packSize: 1),
        Item(id: "cupcake", name: "Muffin", price: 5, blurb: "+15 kul, gör en rund", kind: .food(FoodEffect(hunger: 10, fun: 15, fattening: 6)), packSize: 1),
        Item(id: "cookie", name: "Stjärnkaka", price: 3, blurb: "+8 kul, gör en rund", kind: .food(FoodEffect(hunger: 6, fun: 8, fattening: 3)), packSize: 1),
        Item(id: "lollipop", name: "Regnbågsklubba", price: 45, blurb: "Gör en jätteglad!", kind: .food(FoodEffect(hunger: 4, fun: 30, fattening: 4, love: 15)), packSize: 1),
        Item(id: "icecream", name: "Glasstrut", price: 40, blurb: "Gör en jätteglad!", kind: .food(FoodEffect(hunger: 8, thirst: 5, fun: 25, fattening: 5, love: 15)), packSize: 1),
        Item(id: "soda", name: "Bubbelsaft", price: 35, blurb: "Söt dricka, gör en glad!", kind: .food(FoodEffect(hunger: 0, thirst: 35, fun: 20, fattening: 3, love: 10)), packSize: 1),
        Item(id: "water", name: "Källvatten", price: 5, blurb: "Fyller skålen", kind: .water(45), packSize: 5),
        Item(id: "shampoo", name: "Bubbelschampo", price: 12, blurb: "Extra glittrigt bad", kind: .shampoo, packSize: 3),
        Item(id: "medicine", name: "Må-bra-piller", price: 20, blurb: "Gör en frisk igen", kind: .medicine, packSize: 1),

        Item(id: "sofa", name: "Molnsoffa", price: 150, blurb: "Så mjuk", kind: .decor(category: .furniture, layer: .floor, cosiness: 18), packSize: 1),
        Item(id: "royalBed", name: "Kungasäng", price: 120, blurb: "Sov så gott", kind: .decor(category: .furniture, layer: .floor, cosiness: 15), packSize: 1),
        Item(id: "bookshelf", name: "Bokhylla", price: 90, blurb: "Jättesmart", kind: .decor(category: .furniture, layer: .floor, cosiness: 10), packSize: 1),
        Item(id: "rug", name: "Hjärtmatta", price: 45, blurb: "Mjukt för tassarna", kind: .decor(category: .furniture, layer: .floor, cosiness: 8), packSize: 1),
        Item(id: "fern", name: "Fluffig ormbunke", price: 35, blurb: "Frisk luft", kind: .decor(category: .plants, layer: .floor, cosiness: 6), packSize: 1),
        Item(id: "cactus", name: "Glad kaktus", price: 25, blurb: "Kramas inte!", kind: .decor(category: .plants, layer: .floor, cosiness: 4), packSize: 1),
        Item(id: "moonLamp", name: "Månlampa", price: 60, blurb: "Mysigt sken", kind: .decor(category: .lights, layer: .floor, cosiness: 9), packSize: 1),
        Item(id: "fairyLights", name: "Ljusslinga", price: 40, blurb: "Blinka blinka", kind: .decor(category: .lights, layer: .wall, cosiness: 8), packSize: 1),
        Item(id: "starPoster", name: "Stjärnaffisch", price: 25, blurb: "Lys starkt", kind: .decor(category: .walls, layer: .wall, cosiness: 4), packSize: 1),
        Item(id: "clock", name: "Gökur", price: 55, blurb: "Tick tack", kind: .decor(category: .walls, layer: .wall, cosiness: 6), packSize: 1),
        Item(id: "rainbow", name: "Regnbågstavla", price: 30, blurb: "Glada färger", kind: .decor(category: .walls, layer: .wall, cosiness: 5), packSize: 1),
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
