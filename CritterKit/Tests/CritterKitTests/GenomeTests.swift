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

    func testNamesAreDeterministicAndThreeParts() {
        XCTAssertEqual(NameGenerator.name(seed: 99), NameGenerator.name(seed: 99))
        let name = NameGenerator.name(seed: 99)
        let parts = name.split(separator: " ")
        XCTAssertEqual(parts.count, 2)
        XCTAssertTrue(NameGenerator.firstNames.contains(String(parts[0])))
        XCTAssertTrue(NameGenerator.surnameStarts.contains { parts[1].hasPrefix($0) })
        XCTAssertTrue(NameGenerator.surnameEnds.contains { parts[1].hasSuffix($0) })
    }

    func testNamesVary() {
        let names = Set((0..<50).map { NameGenerator.name(seed: UInt64($0)) })
        XCTAssertGreaterThan(names.count, 40)
    }
}
