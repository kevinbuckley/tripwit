import Foundation
import Testing

@testable import TripCore

@Suite("PhotoMatcher Tests")
struct PhotoMatcherTests {

    // MARK: - Helpers

    /// Creates a Stop at the given coordinates with optional arrival/departure times.
    private func makeStop(
        latitude: Double,
        longitude: Double,
        arrival: Date? = nil,
        departure: Date? = nil,
        name: String = "Test Stop"
    ) -> Stop {
        Stop(
            dayId: UUID(),
            name: name,
            latitude: latitude,
            longitude: longitude,
            arrivalTime: arrival,
            departureTime: departure,
            category: .attraction,
            sortOrder: 0
        )
    }

    /// Creates a PhotoMetadata at the given coordinates and time.
    private func makePhoto(
        latitude: Double,
        longitude: Double,
        captureDate: Date = Date(),
        assetId: String = "photo-1"
    ) -> PhotoMetadata {
        PhotoMetadata(
            assetIdentifier: assetId,
            latitude: latitude,
            longitude: longitude,
            captureDate: captureDate
        )
    }

    /// A reference date for building time-based test data.
    private var referenceDate: Date {
        // 2026-01-15 10:00:00 UTC
        DateComponents(
            calendar: .init(identifier: .gregorian),
            timeZone: TimeZone(identifier: "UTC"),
            year: 2026, month: 1, day: 15,
            hour: 10, minute: 0, second: 0
        ).date!
    }

    // MARK: - Tests

    @Test("Photo at exact same GPS as stop, within time window -> HIGH")
    func testExactLocationMatch() {
        let arrival = referenceDate
        let departure = referenceDate.addingTimeInterval(3600) // +1h
        let stop = makeStop(
            latitude: 48.8584, longitude: 2.2945,
            arrival: arrival, departure: departure
        )
        let photo = makePhoto(
            latitude: 48.8584, longitude: 2.2945,
            captureDate: referenceDate.addingTimeInterval(1800) // 30 min after arrival
        )

        let matcher = PhotoMatcher()
        let results = matcher.matchPhotos([photo], to: [stop])

        #expect(results.count == 1)
        #expect(results[0].matchedStop != nil)
        #expect(results[0].confidence == .high)
        #expect(results[0].distanceMeters < 1)
    }

    @Test("Photo ~100m from stop, within time window -> HIGH")
    func testNearbyMatch() {
        let arrival = referenceDate
        let departure = referenceDate.addingTimeInterval(3600)
        // Eiffel Tower area: 48.8584, 2.2945
        // ~100m offset in latitude is roughly 0.0009 degrees
        let stop = makeStop(
            latitude: 48.8584, longitude: 2.2945,
            arrival: arrival, departure: departure
        )
        let photo = makePhoto(
            latitude: 48.8593, longitude: 2.2945,
            captureDate: referenceDate.addingTimeInterval(1800)
        )

        let matcher = PhotoMatcher()
        let results = matcher.matchPhotos([photo], to: [stop])

        #expect(results.count == 1)
        #expect(results[0].matchedStop != nil)
        #expect(results[0].confidence == .high)
        #expect(results[0].distanceMeters > 50)
        #expect(results[0].distanceMeters < 200)
    }

    @Test("Photo at stop location but hours after departure -> MEDIUM")
    func testOutsideTimeWindow() {
        let arrival = referenceDate
        let departure = referenceDate.addingTimeInterval(3600)
        let stop = makeStop(
            latitude: 48.8584, longitude: 2.2945,
            arrival: arrival, departure: departure
        )
        // Photo taken 4 hours after departure (well beyond 2h window)
        let photo = makePhoto(
            latitude: 48.8584, longitude: 2.2945,
            captureDate: departure.addingTimeInterval(14400)
        )

        let matcher = PhotoMatcher()
        let results = matcher.matchPhotos([photo], to: [stop])

        #expect(results.count == 1)
        #expect(results[0].matchedStop != nil)
        #expect(results[0].confidence == .medium)
    }

    @Test("Photo ~300m away from stop -> LOW")
    func testFarButReasonable() {
        let arrival = referenceDate
        let stop = makeStop(
            latitude: 48.8584, longitude: 2.2945,
            arrival: arrival, departure: arrival.addingTimeInterval(3600)
        )
        // ~300m offset: roughly 0.0027 degrees latitude
        let photo = makePhoto(
            latitude: 48.8611, longitude: 2.2945,
            captureDate: referenceDate.addingTimeInterval(1800)
        )

        let matcher = PhotoMatcher()
        let results = matcher.matchPhotos([photo], to: [stop])

        #expect(results.count == 1)
        #expect(results[0].matchedStop != nil)
        #expect(results[0].confidence == .low)
        #expect(results[0].distanceMeters > 200)
        #expect(results[0].distanceMeters <= 400)
    }

    @Test("Photo ~1km away from stop -> no match")
    func testTooFar() {
        let stop = makeStop(
            latitude: 48.8584, longitude: 2.2945,
            arrival: referenceDate, departure: referenceDate.addingTimeInterval(3600)
        )
        // ~1km offset: roughly 0.009 degrees latitude
        let photo = makePhoto(
            latitude: 48.8674, longitude: 2.2945,
            captureDate: referenceDate.addingTimeInterval(1800)
        )

        let matcher = PhotoMatcher()
        let results = matcher.matchPhotos([photo], to: [stop])

        #expect(results.count == 1)
        #expect(results[0].matchedStop == nil)
        #expect(results[0].distanceMeters > 400)
    }

    @Test("Photo between two stops matches the nearest one")
    func testMultipleStopsPicksClosest() {
        let stopA = makeStop(
            latitude: 48.8584, longitude: 2.2945,
            arrival: referenceDate, departure: referenceDate.addingTimeInterval(3600),
            name: "Stop A"
        )
        // Stop B is ~500m north
        let stopB = makeStop(
            latitude: 48.8630, longitude: 2.2945,
            arrival: referenceDate, departure: referenceDate.addingTimeInterval(3600),
            name: "Stop B"
        )
        // Photo placed ~50m from Stop A
        let photo = makePhoto(
            latitude: 48.8588, longitude: 2.2945,
            captureDate: referenceDate.addingTimeInterval(1800)
        )

        let matcher = PhotoMatcher()
        let results = matcher.matchPhotos([photo], to: [stopA, stopB])

        #expect(results.count == 1)
        #expect(results[0].matchedStop?.name == "Stop A")
        #expect(results[0].confidence == .high)
    }

    @Test("Empty stops array returns all photos unmatched")
    func testNoStops() {
        let photo = makePhoto(latitude: 48.8584, longitude: 2.2945)
        let matcher = PhotoMatcher()
        let results = matcher.matchPhotos([photo], to: [])

        #expect(results.count == 1)
        #expect(results[0].matchedStop == nil)
    }

    @Test("Empty photos array returns empty results")
    func testNoPhotos() {
        let stop = makeStop(latitude: 48.8584, longitude: 2.2945)
        let matcher = PhotoMatcher()
        let results = matcher.matchPhotos([], to: [stop])

        #expect(results.isEmpty)
    }
}
