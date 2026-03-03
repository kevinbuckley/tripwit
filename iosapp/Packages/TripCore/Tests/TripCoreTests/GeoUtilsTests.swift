import Foundation
import Testing

@testable import TripCore

@Suite("GeoUtils Tests")
struct GeoUtilsTests {

    @Test("Haversine distance for known city pair (NYC to LA)")
    func testHaversineKnownDistance() {
        // New York City: 40.7128, -74.0060
        // Los Angeles:   34.0522, -118.2437
        // Known great-circle distance: ~3,944 km
        let distanceMeters = GeoUtils.distance(
            lat1: 40.7128, lon1: -74.0060,
            lat2: 34.0522, lon2: -118.2437
        )
        let distanceKm = distanceMeters / 1000.0

        // Allow 1% tolerance.
        let knownKm = 3944.0
        let tolerance = knownKm * 0.01
        #expect(abs(distanceKm - knownKm) < tolerance,
                "Expected ~\(knownKm) km, got \(distanceKm) km")
    }

    @Test("Same point yields zero distance")
    func testSamePointZeroDistance() {
        let d = GeoUtils.distance(
            lat1: 51.5074, lon1: -0.1278,
            lat2: 51.5074, lon2: -0.1278
        )
        #expect(d == 0)
    }

    @Test("isWithinRadius returns true for nearby points and false for far ones")
    func testIsWithinRadius() {
        let london = Coordinate(latitude: 51.5074, longitude: -0.1278)
        // A point ~100m from London (roughly 0.0009 degrees latitude offset)
        let nearby = Coordinate(latitude: 51.5083, longitude: -0.1278)
        // Paris
        let paris = Coordinate(latitude: 48.8566, longitude: 2.3522)

        #expect(GeoUtils.isWithinRadius(london, nearby, radiusMeters: 200))
        #expect(!GeoUtils.isWithinRadius(london, paris, radiusMeters: 200))
    }

    @Test("Center point of coordinates")
    func testCenterPoint() {
        // Two symmetric points on the equator
        let coords = [
            Coordinate(latitude: 0, longitude: -10),
            Coordinate(latitude: 0, longitude: 10),
        ]
        let center = GeoUtils.centerPoint(of: coords)

        #expect(center != nil)
        if let c = center {
            #expect(abs(c.latitude) < 0.01, "Expected latitude ~0, got \(c.latitude)")
            #expect(abs(c.longitude) < 0.01, "Expected longitude ~0, got \(c.longitude)")
        }

        // Empty array
        let empty = GeoUtils.centerPoint(of: [])
        #expect(empty == nil)
    }
}
