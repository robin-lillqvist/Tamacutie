import CritterKit
import Foundation
import Observation

/// Owns the saved game, keeps it ticking in real time and saves after every change.
@MainActor
@Observable
final class GameStore {
    private(set) var state: GameState
    private(set) var now: Date
    /// Debug-only fast-forward, so the passing of time can be tried out without waiting.
    private(set) var timeOffset: TimeInterval

    private let saveURL: URL
    private let defaults: UserDefaults
    private let clock: () -> Date

    init(saveURL: URL = GameStore.defaultSaveURL, defaults: UserDefaults = .standard, clock: @escaping () -> Date = Date.init) {
        self.saveURL = saveURL
        self.defaults = defaults
        self.clock = clock
        let offset = defaults.double(forKey: "timeOffset")
        let start = clock().addingTimeInterval(offset)
        var loaded = SaveFile.load(from: saveURL) ?? GameState(now: start)
        loaded.advance(to: start)
        timeOffset = offset
        now = start
        state = loaded
    }

    nonisolated static var defaultSaveURL: URL {
        URL.applicationSupportDirectory.appending(path: "CritterCorner/save.json")
    }

    var pet: Pet? { state.pet }

    /// Brings the world up to the current real time.
    func tick() {
        now = clock().addingTimeInterval(timeOffset)
        state.advance(to: now)
    }

    func skipAhead(hours: Double) {
        timeOffset += hours * 3600
        defaults.set(timeOffset, forKey: "timeOffset")
        tick()
        save()
    }

    @discardableResult
    func perform<TResult>(_ change: (inout GameState, Date) -> TResult) -> TResult {
        tick()
        let result = change(&state, now)
        save()
        return result
    }

    func save() {
        try? SaveFile.save(state, to: saveURL)
    }
}
