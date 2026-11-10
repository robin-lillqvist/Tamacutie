/// Cute first name + an epic two-part surname: "Mochi" + "Stjärn" + "bubbel".
public enum NameGenerator {
    public static let firstNames = [
        "Mochi", "Zuko", "Pip", "Kiki", "Bao", "Nori", "Taro", "Yuzu", "Miso", "Boba",
        "Pudding", "Smulan", "Tofu", "Kiwi", "Juno", "Kexet", "Pärlan", "Pyret", "Ziggy", "Momo",
        "Nötis", "Luma", "Wasabi", "Coco", "Fia", "Bullen", "Poppy", "Mulle", "Suki", "Blopp",
    ]
    public static let surnameStarts = [
        "Stjärn", "Mån", "Åsk", "Glitter", "Vingel", "Moln", "Gnist", "Komet", "Sammet", "Honungs",
        "Pixel", "Regnbågs", "Frost", "Sol", "Kosmo", "Blänk", "Mys", "Pöl", "Dröm", "Snö",
    ]
    public static let surnameEnds = [
        "bubbel", "böna", "puff", "fena", "tass", "blomma", "nos", "pop", "fluff", "glans",
        "stövel", "knapp", "droppe", "bär", "kula", "mums", "plopp", "kind", "vippa", "tuss",
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
