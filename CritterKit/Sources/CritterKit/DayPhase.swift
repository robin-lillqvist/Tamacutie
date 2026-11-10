import Foundation

/// The part of the real day the room's window shows.
public enum DayPhase: String, CaseIterable, Sendable {
    case dawn, day, dusk, night

    public init(date: Date, calendar: Calendar = .current) {
        let hour = Self.hourFraction(date, calendar: calendar)
        switch hour {
        case 5..<7: self = .dawn
        case 7..<18: self = .day
        case 18..<21: self = .dusk
        default: self = .night
        }
    }

    /// 0 at sunrise (05:00), 1 at sunset (21:00); where the sun is on its arc across the sky.
    public static func sunProgress(_ date: Date, calendar: Calendar = .current) -> Double {
        min(1, max(0, (hourFraction(date, calendar: calendar) - 5) / 16))
    }

    /// 0...1 through the night (21:00 to 05:00), for the moon's arc.
    public static func moonProgress(_ date: Date, calendar: Calendar = .current) -> Double {
        let hour = hourFraction(date, calendar: calendar)
        let sinceDusk = hour >= 21 ? hour - 21 : hour + 3
        return min(1, max(0, sinceDusk / 8))
    }

    public var isDark: Bool { self == .night }

    private static func hourFraction(_ date: Date, calendar: Calendar) -> Double {
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        return Double(parts.hour ?? 0) + Double(parts.minute ?? 0) / 60
    }
}
