import Foundation

public struct Coordinate: Codable, Hashable, Sendable {

    // MARK: Stored Properties

    public var latitude: Double
    public var longitude: Double

    // MARK: Initializer

    public init(latitude: Double, longitude: Double) {
        self.latitude = latitude
        self.longitude = longitude
    }

    // MARK: Distance

    /// Calculates the Haversine distance in meters to another coordinate.
    public func distance(to other: Coordinate) -> Double {
        GeoUtils.distance(
            lat1: latitude,
            lon1: longitude,
            lat2: other.latitude,
            lon2: other.longitude
        )
    }
}
