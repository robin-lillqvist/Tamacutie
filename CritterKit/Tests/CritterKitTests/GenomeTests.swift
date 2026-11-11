import XCTest
@testable import CritterKit

final class GenomeTests: XCTestCase {
    func testSameSeedBuildsSameCritter() {
        XCTAssertEqual(Genome(seed: 1234), Genome(seed: 1234))
    }

    func testDifferentSeedsGiveVariety() {
        let genomes = (0..<200).map { Genome(seed: UInt64($0) &* 7919) }
        XCTAssertEqual(Set(genomes.map(\.head)).count, HeadFeature.allCases.count)
        XCTAssertEqual(Set(genomes.map(\.body)).count, BodyShape.allCases.count)
        XCTAssertEqual(Set(genomes.map(\.paletteIndex)).count, Palette.all.count)
        XCTAssertTrue(genomes.contains { $0.eyes == .cyclops })
    }

    func testEveryCritterHasTwoDifferentTraits() {
        for seed in 0..<100 {
            let traits = Genome(seed: UInt64(seed)).traits
            XCTAssertEqual(traits.count, 2)
            XCTAssertEqual(Set(traits).count, 2)
        }
    }

    func testNamesAreDeterministicAndBuiltFromParts() {
        XCTAssertEqual(NameGenerator.name(seed: 99), NameGenerator.name(seed: 99))
        for seed in 0..<200 as Range<UInt64> {
            let name = NameGenerator.name(seed: seed)
            let first = String(name.prefix { $0 != " " })
            XCTAssertTrue(NameGenerator.firstNames.contains(first), name)
            var rest = String(name.dropFirst(first.count + 1))
            if let prefix = NameGenerator.prefixes.first(where: { rest.hasPrefix($0) }) {
                rest.removeFirst(prefix.count)
            }
            XCTAssertTrue(NameGenerator.surnameStarts.contains { rest.hasPrefix($0) }, name)
            XCTAssertTrue(NameGenerator.surnameEnds.contains { rest.hasSuffix($0) }, name)
            XCTAssertFalse(rest.contains(" "), name)
        }
    }

    func testNamesMixPrefixesAndPlainSurnames() {
        let names = (0..<300 as Range<UInt64>).map { NameGenerator.name(seed: $0) }
        XCTAssertTrue(names.contains { $0.contains(" von ") })
        XCTAssertTrue(names.contains { $0.contains(" Mac") })
        XCTAssertTrue(names.contains { $0.split(separator: " ").count == 2 && !$0.contains("Mac") })
    }

    func testNamesVary() {
        let names = Set((0..<50).map { NameGenerator.name(seed: UInt64($0)) })
        XCTAssertGreaterThan(names.count, 40)
    }
}
