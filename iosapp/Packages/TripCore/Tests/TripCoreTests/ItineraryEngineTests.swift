import Foundation
import Testing

@testable import TripCore

@Suite("ItineraryEngine Tests")
struct ItineraryEngineTests {

    // MARK: - Helpers

    private var calendar: Calendar { Calendar.current }

    /// Builds a date from components in the current calendar.
    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(identifier: "UTC"),
            year: year, month: month, day: day,
            hour: 12, minute: 0, second: 0
        ).date!
    }

    /// Builds a minimal Trip with the given date range.
    private func makeTrip(
        start: Date,
        end: Date,
        days: [Day] = []
    ) -> Trip {
        Trip(
            name: "Test Trip",
            destination: "Nowhere",
            startDate: start,
            endDate: end,
            days: days
        )
    }

    // MARK: - Tests

    @Test("Generate days for a 5-day trip")
    func testGenerateDays() {
        let start = makeDate(year: 2026, month: 3, day: 10)
        let end = makeDate(year: 2026, month: 3, day: 14)
        let trip = makeTrip(start: start, end: end)

        let days = ItineraryEngine.generateDays(for: trip)

        #expect(days.count == 5)
        #expect(days[0].dayNumber == 1)
        #expect(days[4].dayNumber == 5)

        // Verify each day's date is sequential.
        let cal = Calendar.current
        for (index, day) in days.enumerated() {
            let expectedDate = cal.date(byAdding: .day, value: index, to: cal.startOfDay(for: start))!
            #expect(cal.isDate(day.date, inSameDayAs: expectedDate),
                    "Day \(index + 1) date mismatch")
            #expect(day.tripId == trip.id)
        }
    }

    @Test("Generate days for a single-day trip")
    func testGenerateDaysSingleDay() {
        let date = makeDate(year: 2026, month: 6, day: 1)
        let trip = makeTrip(start: date, end: date)

        let days = ItineraryEngine.generateDays(for: trip)

        #expect(days.count == 1)
        #expect(days[0].dayNumber == 1)
    }

    @Test("Reorder stops moves element and updates sortOrder")
    func testReorderStops() {
        let dayId = UUID()
        var stops = (0..<4).map { i in
            Stop(
                dayId: dayId,
                name: "Stop \(i)",
                latitude: 0,
                longitude: 0,
                sortOrder: i
            )
        }

        // Move Stop 0 to index 2
        ItineraryEngine.reorderStops(&stops, moving: 0, to: 2)

        #expect(stops[0].name == "Stop 1")
        #expect(stops[1].name == "Stop 2")
        #expect(stops[2].name == "Stop 0")
        #expect(stops[3].name == "Stop 3")

        // Verify sortOrder is sequential
        for i in stops.indices {
            #expect(stops[i].sortOrder == i)
        }
    }

    // MARK: - syncDays Tests

    @Test("Extend trip end date — old days preserved, new days added")
    func testSyncDaysExtendEnd() {
        let mar10 = makeDate(year: 2026, month: 3, day: 10)
        let mar12 = makeDate(year: 2026, month: 3, day: 12)
        let mar14 = makeDate(year: 2026, month: 3, day: 14)

        let existingDays = [
            Day(tripId: UUID(), date: mar10, dayNumber: 1, stops: []),
            Day(tripId: UUID(), date: makeDate(year: 2026, month: 3, day: 11), dayNumber: 2, stops: []),
            Day(tripId: UUID(), date: mar12, dayNumber: 3, stops: []),
        ]

        let result = ItineraryEngine.syncDays(
            newStart: mar10,
            newEnd: mar14,
            existingDays: existingDays
        )

        // All 3 existing days kept
        #expect(result.keepDayIDs.count == 3)
        for day in existingDays {
            #expect(result.keepDayIDs.contains(day.id))
        }
        // No days removed
        #expect(result.removeDayIDs.isEmpty)
        // 2 new days needed (Mar 13, Mar 14)
        #expect(result.datesToAdd.count == 2)
    }

    @Test("Move start date forward — first days removed, rest preserved")
    func testSyncDaysMoveStartForward() {
        let mar10 = makeDate(year: 2026, month: 3, day: 10)
        let mar11 = makeDate(year: 2026, month: 3, day: 11)
        let mar12 = makeDate(year: 2026, month: 3, day: 12)
        let mar14 = makeDate(year: 2026, month: 3, day: 14)

        let day1 = Day(tripId: UUID(), date: mar10, dayNumber: 1)
        let day2 = Day(tripId: UUID(), date: mar11, dayNumber: 2)
        let day3 = Day(tripId: UUID(), date: mar12, dayNumber: 3)

        let result = ItineraryEngine.syncDays(
            newStart: mar12,
            newEnd: mar14,
            existingDays: [day1, day2, day3]
        )

        // Only day3 (Mar 12) kept
        #expect(result.keepDayIDs == [day3.id])
        // day1 and day2 removed
        #expect(result.removeDayIDs == [day1.id, day2.id])
        // 2 new days needed (Mar 13, Mar 14)
        #expect(result.datesToAdd.count == 2)
    }

    @Test("Move start date earlier — new day added at front, rest preserved")
    func testSyncDaysMoveStartEarlier() {
        let mar10 = makeDate(year: 2026, month: 3, day: 10)
        let mar11 = makeDate(year: 2026, month: 3, day: 11)
        let mar12 = makeDate(year: 2026, month: 3, day: 12)
        let mar8 = makeDate(year: 2026, month: 3, day: 8)

        let day1 = Day(tripId: UUID(), date: mar10, dayNumber: 1)
        let day2 = Day(tripId: UUID(), date: mar11, dayNumber: 2)
        let day3 = Day(tripId: UUID(), date: mar12, dayNumber: 3)

        let result = ItineraryEngine.syncDays(
            newStart: mar8,
            newEnd: mar12,
            existingDays: [day1, day2, day3]
        )

        // All 3 existing days kept
        #expect(result.keepDayIDs.count == 3)
        // None removed
        #expect(result.removeDayIDs.isEmpty)
        // 2 new days at front (Mar 8, Mar 9)
        #expect(result.datesToAdd.count == 2)
    }

    @Test("Shrink both ends — only middle days preserved")
    func testSyncDaysShrinkBothEnds() {
        let mar10 = makeDate(year: 2026, month: 3, day: 10)
        let mar11 = makeDate(year: 2026, month: 3, day: 11)
        let mar12 = makeDate(year: 2026, month: 3, day: 12)
        let mar13 = makeDate(year: 2026, month: 3, day: 13)
        let mar14 = makeDate(year: 2026, month: 3, day: 14)

        let day1 = Day(tripId: UUID(), date: mar10, dayNumber: 1)
        let day2 = Day(tripId: UUID(), date: mar11, dayNumber: 2)
        let day3 = Day(tripId: UUID(), date: mar12, dayNumber: 3)
        let day4 = Day(tripId: UUID(), date: mar13, dayNumber: 4)
        let day5 = Day(tripId: UUID(), date: mar14, dayNumber: 5)

        let result = ItineraryEngine.syncDays(
            newStart: mar11,
            newEnd: mar13,
            existingDays: [day1, day2, day3, day4, day5]
        )

        // Middle 3 days kept
        #expect(result.keepDayIDs == [day2.id, day3.id, day4.id])
        // First and last removed
        #expect(result.removeDayIDs == [day1.id, day5.id])
        // No new days needed
        #expect(result.datesToAdd.isEmpty)
    }

    @Test("No overlap — all days replaced")
    func testSyncDaysNoOverlap() {
        let mar10 = makeDate(year: 2026, month: 3, day: 10)
        let mar11 = makeDate(year: 2026, month: 3, day: 11)
        let mar20 = makeDate(year: 2026, month: 3, day: 20)
        let mar22 = makeDate(year: 2026, month: 3, day: 22)

        let day1 = Day(tripId: UUID(), date: mar10, dayNumber: 1)
        let day2 = Day(tripId: UUID(), date: mar11, dayNumber: 2)

        let result = ItineraryEngine.syncDays(
            newStart: mar20,
            newEnd: mar22,
            existingDays: [day1, day2]
        )

        // No days kept
        #expect(result.keepDayIDs.isEmpty)
        // Both old days removed
        #expect(result.removeDayIDs == [day1.id, day2.id])
        // 3 brand new days
        #expect(result.datesToAdd.count == 3)
    }

    @Test("Trip stats computes totals correctly")
    func testTripStats() {
        let dayId1 = UUID()
        let dayId2 = UUID()

        let photo = MatchedPhoto(
            assetIdentifier: "asset-1",
            latitude: 0, longitude: 0,
            captureDate: Date(),
            matchConfidence: .high
        )

        // Day 1: two stops ~111km apart (1 degree latitude at equator)
        let stop1 = Stop(
            dayId: dayId1,
            name: "Stop A",
            latitude: 0.0, longitude: 0.0,
            category: .attraction,
            sortOrder: 0,
            matchedPhotos: [photo]
        )
        let stop2 = Stop(
            dayId: dayId1,
            name: "Stop B",
            latitude: 1.0, longitude: 0.0,
            category: .restaurant,
            sortOrder: 1
        )

        let day1 = Day(
            tripId: UUID(),
            date: Date(),
            dayNumber: 1,
            stops: [stop1, stop2]
        )

        // Day 2: one stop
        let stop3 = Stop(
            dayId: dayId2,
            name: "Stop C",
            latitude: 2.0, longitude: 0.0,
            category: .attraction,
            sortOrder: 0
        )
        let day2 = Day(
            tripId: UUID(),
            date: Date(),
            dayNumber: 2,
            stops: [stop3]
        )

        let trip = makeTrip(
            start: Date(),
            end: Date().addingTimeInterval(86400),
            days: [day1, day2]
        )

        let stats = ItineraryEngine.tripStats(trip)

        #expect(stats.totalStops == 3)
        #expect(stats.totalPhotos == 1)
        #expect(stats.categoryCounts[.attraction] == 2)
        #expect(stats.categoryCounts[.restaurant] == 1)
        // Distance between (0,0) and (1,0) is ~111.19 km
        #expect(stats.totalDistanceKm > 100)
        #expect(stats.totalDistanceKm < 120)
    }
}
