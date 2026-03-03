import Foundation

public enum GeoUtils: Sendable {

    /// Mean radius of the Earth in meters.
    private static let earthRadiusMeters: Double = 6_371_000

    /// Haversine distance in meters between two coordinates specified by latitude and longitude
    /// in degrees.
    public static func distance(lat1: Double, lon1: Double, lat2: Double, lon2: Double) -> Double {
        let dLat = (lat2 - lat1) * .pi / 180.0
        let dLon = (lon2 - lon1) * .pi / 180.0

        let lat1Rad = lat1 * .pi / 180.0
        let lat2Rad = lat2 * .pi / 180.0

        let a = sin(dLat / 2) * sin(dLat / 2)
            + cos(lat1Rad) * cos(lat2Rad) * sin(dLon / 2) * sin(dLon / 2)
        let c = 2 * atan2(sqrt(a), sqrt(1 - a))

        return earthRadiusMeters * c
    }

    /// Check if a coordinate is within a given radius (in meters) of another coordinate.
    public static func isWithinRadius(
        _ coord1: Coordinate,
        _ coord2: Coordinate,
        radiusMeters: Double
    ) -> Bool {
        let d = distance(
            lat1: coord1.latitude,
            lon1: coord1.longitude,
            lat2: coord2.latitude,
            lon2: coord2.longitude
        )
        return d <= radiusMeters
    }

    /// Find the geographic center point of multiple coordinates.
    /// Returns `nil` if the array is empty.
    public static func centerPoint(of coordinates: [Coordinate]) -> Coordinate? {
        guard !coordinates.isEmpty else { return nil }

        var x: Double = 0
        var y: Double = 0
        var z: Double = 0

        for coord in coordinates {
            let latRad = coord.latitude * .pi / 180.0
            let lonRad = coord.longitude * .pi / 180.0

            x += cos(latRad) * cos(lonRad)
            y += cos(latRad) * sin(lonRad)
            z += sin(latRad)
        }

        let count = Double(coordinates.count)
        x /= count
        y /= count
        z /= count

        let centerLon = atan2(y, x) * 180.0 / .pi
        let hyp = sqrt(x * x + y * y)
        let centerLat = atan2(z, hyp) * 180.0 / .pi

        return Coordinate(latitude: centerLat, longitude: centerLon)
    }
}
