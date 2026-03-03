import Foundation
import Testing

@testable import TripCore

@Suite("Model Tests")
struct ModelTests {

    // MARK: - Helpers

    private func makeDate(year: Int, month: Int, day: Int) -> Date {
        DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(identifier: "UTC"),
            year: year, month: month, day: day,
            hour: 12, minute: 0, second: 0
        ).date!
    }

    // MARK: - Trip Status Computed Properties

    @Test("Trip isPast for a trip that ended yesterday")
    func testTripStatusPast() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -3, to: Date())!
        let dayBefore = Calendar.current.date(byAdding: .day, value: -5, to: Date())!
        let trip = Trip(
            name: "Past Trip",
            destination: "Rome",
            startDate: dayBefore,
            endDate: yesterday
        )

        #expect(trip.isPast)
        #expect(!trip.isFuture)
        #expect(!trip.isActive)
    }

    @Test("Trip isFuture for a trip starting next week")
    func testTripStatusFuture() {
        let nextWeek = Calendar.current.date(byAdding: .day, value: 7, to: Date())!
        let weekAfter = Calendar.current.date(byAdding: .day, value: 14, to: Date())!
        let trip = Trip(
            name: "Future Trip",
            destination: "Tokyo",
            startDate: nextWeek,
            endDate: weekAfter
        )

        #expect(trip.isFuture)
        #expect(!trip.isPast)
        #expect(!trip.isActive)
    }

    @Test("Trip isActive for a trip spanning today")
    func testTripStatusActive() {
        let yesterday = Calendar.current.date(byAdding: .day, value: -1, to: Date())!
        let tomorrow = Calendar.current.date(byAdding: .day, value: 1, to: Date())!
        let trip = Trip(
            name: "Active Trip",
            destination: "Paris",
            startDate: yesterday,
            endDate: tomorrow
        )

        #expect(trip.isActive)
        #expect(!trip.isPast)
        #expect(!trip.isFuture)
    }

    // MARK: - Trip Duration

    @Test("Trip duration calculation")
    func testTripDuration() {
        let start = makeDate(year: 2026, month: 7, day: 1)
        let end = makeDate(year: 2026, month: 7, day: 5)
        let trip = Trip(
            name: "Summer Trip",
            destination: "Barcelona",
            startDate: start,
            endDate: end
        )

        #expect(trip.durationInDays == 5)
    }

    @Test("Single day trip has duration of 1")
    func testTripDurationSingleDay() {
        let date = makeDate(year: 2026, month: 7, day: 1)
        let trip = Trip(
            name: "Day Trip",
            destination: "Nearby",
            startDate: date,
            endDate: date
        )

        #expect(trip.durationInDays == 1)
    }

    // MARK: - Codable Round Trip

    @Test("Trip encodes and decodes correctly")
    func testCodableRoundTrip() throws {
        let tripId = UUID()
        let dayId = UUID()
        let stopId = UUID()
        let photoId = UUID()

        let start = makeDate(year: 2026, month: 8, day: 10)
        let end = makeDate(year: 2026, month: 8, day: 12)

        let photo = MatchedPhoto(
            id: photoId,
            assetIdentifier: "PHAsset-123",
            latitude: 41.9028,
            longitude: 12.4964,
            captureDate: start,
            matchConfidence: .high,
            matchedStopId: stopId,
            isManuallyAssigned: false
        )

        let stop = Stop(
            id: stopId,
            dayId: dayId,
            name: "Colosseum",
            latitude: 41.8902,
            longitude: 12.4922,
            arrivalTime: start,
            departureTime: start.addingTimeInterval(7200),
            category: .attraction,
            notes: "Book tickets in advance",
            sortOrder: 0,
            matchedPhotos: [photo]
        )

        let day = Day(
            id: dayId,
            tripId: tripId,
            date: start,
            dayNumber: 1,
            notes: "First day in Rome",
            stops: [stop]
        )

        let original = Trip(
            id: tripId,
            name: "Rome Adventure",
            destination: "Rome, Italy",
            startDate: start,
            endDate: end,
            status: .active,
            coverPhotoAssetId: "PHAsset-cover",
            notes: "Don't forget sunscreen",
            createdAt: start,
            updatedAt: start,
            days: [day]
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(original)

        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let decoded = try decoder.decode(Trip.self, from: data)

        #expect(decoded == original)
        #expect(decoded.id == tripId)
        #expect(decoded.name == "Rome Adventure")
        #expect(decoded.destination == "Rome, Italy")
        #expect(decoded.status == .active)
        #expect(decoded.coverPhotoAssetId == "PHAsset-cover")
        #expect(decoded.days.count == 1)
        #expect(decoded.days[0].stops.count == 1)
        #expect(decoded.days[0].stops[0].matchedPhotos.count == 1)
        #expect(decoded.days[0].stops[0].matchedPhotos[0].matchConfidence == .high)
    }

    // MARK: - Coordinate

    @Test("Coordinate distance calculation delegates to GeoUtils")
    func testCoordinateDistance() {
        let a = Coordinate(latitude: 0, longitude: 0)
        let b = Coordinate(latitude: 1, longitude: 0)

        let distance = a.distance(to: b)

        // ~111.19 km at equator for 1 degree
        #expect(distance > 110_000)
        #expect(distance < 112_000)
    }
}
