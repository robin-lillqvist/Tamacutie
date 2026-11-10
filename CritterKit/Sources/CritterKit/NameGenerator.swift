/// Cute first name + an epic two-part surname: "Mochi" + "Star" + "fizz".
public enum NameGenerator {
    public static let firstNames = [
        "Mochi", "Zuko", "Pip", "Kiki", "Bao", "Nori", "Taro", "Yuzu", "Miso", "Boba",
        "Pudding", "Sprout", "Tofu", "Kiwi", "Juno", "Biscuit", "Pebble", "Nugget", "Ziggy", "Momo",
        "Peanut", "Luma", "Wasabi", "Coco", "Fig", "Dumpling", "Poppy", "Bean", "Suki", "Bloop",
    ]
    public static let surnameStarts = [
        "Star", "Moon", "Thunder", "Glimmer", "Wobble", "Cloud", "Sparkle", "Comet", "Velvet", "Honey",
        "Pixel", "Rainbow", "Frost", "Sunny", "Nebu", "Twinkle", "Marsh", "Cosmo", "Puddle", "Dream",
    ]
    public static let surnameEnds = [
        "fizz", "bean", "puff", "fin", "sprout", "whisk", "paws", "bloom", "dust", "toes",
        "wiggle", "drop", "berry", "lon", "snout", "pop", "fluff", "glow", "boots", "nibble",
    ]

    public static func name(seed: UInt64) -> String {
        var rng = SeededRandom(seed: seed ^ 0xC0FF_EE00_BEEF_CAFE)
        return name(using: &rng)
    }

    public static func name<TGenerator: RandomNumberGenerator>(using rng: inout TGenerator) -> String {
        let first = firstNames.randomElement(using: &rng)!
        let start = surnameStarts.randomElement(using: &rng)!
        let end = surnameEnds.randomElement(using: &rng)!
        return "\(first) \(start)\(end)"
    }
}
