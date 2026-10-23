import XCTest
import SwiftUI
import BatwalkCore
@testable import Batwalk

extension AppReliabilityTests {
    @MainActor
    func testRecapAndSixWeekMonthCardsExportAtTwelveHundredSquare() async throws {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let date = calendar.date(from: DateComponents(year: 2027, month: 5, day: 31))!
        let recap = WeeklyRecap.make(history: [], weekStart: date, calendar: calendar)
        let weekRenderer = ImageRenderer(content: WeeklyRecapCard(recap: recap))
        weekRenderer.scale = 3
        let week = try XCTUnwrap(weekRenderer.uiImage?.cgImage)
        XCTAssertEqual(week.width, 1_200); XCTAssertEqual(week.height, 1_200)
        // May 2027 occupies six calendar rows; none can depend on lazy visibility.
        for count in [0, 1, 3, 6] {
            let history = (0..<count).map { _ in
                HatchRecord(speciesID: "mochi", isShiny: true, eggType: .tiny,
                            hatchedAt: date, outcome: .duplicate)
            }
            let month = MonthlyChallenge.make(history: history, monthKey: "2027-05", calendar: calendar)
            let renderer = ImageRenderer(content: MonthlyChallengeCard(challenge: month))
            renderer.scale = 3
            let image = try XCTUnwrap(renderer.uiImage?.cgImage)
            XCTAssertEqual(image.width, 1_200); XCTAssertEqual(image.height, 1_200)
        }
    }
}
