/// A cute first name plus a grand surname, often with a noble or clan prefix:
/// "Tindra MacKnasgurka", "Smulan von Krambulle", "Mochi Stjärnbubbel".
public enum NameGenerator {
    public static let firstNames = [
        "Mochi", "Pip", "Kiki", "Bao", "Nori", "Yuzu", "Miso", "Boba", "Momo", "Coco",
        "Pudding", "Smulan", "Kexet", "Pärlan", "Pyret", "Nötis", "Bullen", "Mulle", "Blopp", "Fia",
        "Tindra", "Sötis", "Majken", "Ebbe", "Stina", "Totte", "Saga", "Lillan", "Tussan", "Knytte",
        "Gullan", "Bosse", "Vilda", "Pelle", "Doris", "Sigge", "Elsa", "Bamse", "Mysan", "Pippi",
    ]
    /// Written as their own word ("von Krambulle") or glued on ("MacKnasgurka").
    public static let prefixes = ["von ", "af ", "Mac", "van der ", "de la "]
    public static let surnameStarts = [
        "Stjärn", "Mån", "Glitter", "Moln", "Gnist", "Sammet", "Honungs", "Regnbågs", "Mys", "Dröm",
        "Kram", "Knas", "Gos", "Kanel", "Fnitter", "Smul", "Pussel", "Socker", "Busig", "Lingon",
        "Hallon", "Bus", "Pannkaks", "Snuttig", "Krusidull",
    ]
    public static let surnameEnds = [
        "bubbel", "böna", "puff", "tass", "blomma", "nos", "fluff", "knapp", "droppe", "mums",
        "bulle", "gurka", "korv", "tuss", "kaka", "boll", "knopp", "sylt", "pudding", "strumpa",
        "näsa", "klump", "plutt", "snigel", "tofs",
    ]

    public static func name(seed: UInt64) -> String {
        var rng = SeededRandom(seed: seed ^ 0xC0FF_EE00_BEEF_CAFE)
        return name(using: &rng)
    }

    public static func name<TGenerator: RandomNumberGenerator>(using rng: inout TGenerator) -> String {
        let first = firstNames.randomElement(using: &rng)!
        let surname = surnameStarts.randomElement(using: &rng)! + surnameEnds.randomElement(using: &rng)!
        // Two in three get a prefix; the rest keep a plain grand surname.
        let prefix = Int.random(in: 0..<3, using: &rng) == 0 ? "" : prefixes.randomElement(using: &rng)!
        return "\(first) \(prefix)\(surname)"
    }
}
