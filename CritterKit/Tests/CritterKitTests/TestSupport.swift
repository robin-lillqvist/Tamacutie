import Foundation
@testable import CritterKit

let t0 = Date(timeIntervalSince1970: 1_800_000_000)

func hours(_ h: Double) -> TimeInterval { h * 3600 }

/// A trait-free genome so tests measure the base rules.
func plainGenome(traits: [Trait] = []) -> Genome {
    Genome(seed: 42, body: .round, head: .floppyEars, eyes: .big, tail: .none, marking: .none, paletteIndex: 0, traits: traits)
}

func makePet(traits: [Trait] = [], at date: Date = t0) -> Pet {
    Pet(name: "Mochi Starfizz", genome: plainGenome(traits: traits), now: date)
}

func makeGame(with pet: Pet? = makePet()) -> GameState {
    var game = GameState(now: t0)
    if let pet { _ = game.adopt(genome: pet.genome, name: pet.name, now: t0) }
    return game
}
