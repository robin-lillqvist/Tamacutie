import XCTest
@testable import CritterKit

final class DayPhaseTests: XCTestCase {
    private var calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Europe/Stockholm")!
        return calendar
    }()

    private func at(_ hour: Int, _ minute: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: hour, minute: minute))!
    }

    func testPhasesFollowTheClock() {
        XCTAssertEqual(DayPhase(date: at(3), calendar: calendar), .night)
        XCTAssertEqual(DayPhase(date: at(6), calendar: calendar), .dawn)
        XCTAssertEqual(DayPhase(date: at(12), calendar: calendar), .day)
        XCTAssertEqual(DayPhase(date: at(19, 30), calendar: calendar), .dusk)
        XCTAssertEqual(DayPhase(date: at(23), calendar: calendar), .night)
    }

    func testSunCrossesTheSkyDuringTheDay() {
        XCTAssertEqual(DayPhase.sunProgress(at(5), calendar: calendar), 0)
        XCTAssertEqual(DayPhase.sunProgress(at(13), calendar: calendar), 0.5, accuracy: 0.001)
        XCTAssertEqual(DayPhase.sunProgress(at(21), calendar: calendar), 1)
        XCTAssertLessThan(DayPhase.sunProgress(at(9), calendar: calendar), DayPhase.sunProgress(at(15), calendar: calendar))
    }

    func testMoonCrossesTheSkyAtNight() {
        XCTAssertEqual(DayPhase.moonProgress(at(21), calendar: calendar), 0)
        XCTAssertEqual(DayPhase.moonProgress(at(1), calendar: calendar), 0.5, accuracy: 0.001)
        XCTAssertEqual(DayPhase.moonProgress(at(5), calendar: calendar), 1)
    }
}
