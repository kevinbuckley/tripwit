import Foundation
import MapKit

/// Calculates driving/walking travel time between two coordinates using MapKit directions.
@Observable
final class TravelTimeService {

    struct TravelEstimate: Identifiable {
        let id = UUID()
        let fromStopID: UUID
        let toStopID: UUID
        let drivingMinutes: Int?
        let walkingMinutes: Int?
        let distanceMeters: Double?
        let isLoading: Bool
    }

    private(set) var estimates: [String: TravelEstimate] = [:]

    /// Returns a cache key for a pair of stops.
    static func key(from: UUID, to: UUID) -> String {
        "\(from.uuidString)-\(to.uuidString)"
    }

    /// Calculate travel time between two stops.
    func calculateTravelTime(from fromStop: StopEntity, to toStop: StopEntity) async {
        guard let fromID = fromStop.id, let toID = toStop.id else { return }
        let key = Self.key(from: fromID, to: toID)

        // Skip if already calculated or loading
        if let existing = estimates[key], !existing.isLoading {
            return
        }

        let fromCoord = CLLocationCoordinate2D(latitude: fromStop.latitude, longitude: fromStop.longitude)
        let toCoord = CLLocationCoordinate2D(latitude: toStop.latitude, longitude: toStop.longitude)

        // Skip if either stop has no location
        guard fromCoord.latitude != 0 || fromCoord.longitude != 0,
              toCoord.latitude != 0 || toCoord.longitude != 0 else {
            return
        }

        // Mark as loading
        estimates[key] = TravelEstimate(
            fromStopID: fromID,
            toStopID: toID,
            drivingMinutes: nil,
            walkingMinutes: nil,
            distanceMeters: nil,
            isLoading: true
        )

        let fromPlacemark = MKPlacemark(coordinate: fromCoord)
        let toPlacemark = MKPlacemark(coordinate: toCoord)

        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: fromPlacemark)
        request.destination = MKMapItem(placemark: toPlacemark)
        request.transportType = .automobile

        let directions = MKDirections(request: request)

        do {
            let response = try await directions.calculate()
            if let route = response.routes.first {
                let drivingMins = Int(route.expectedTravelTime / 60)
                let distanceM = route.distance

                // Also try walking if distance is short (< 3km)
                var walkingMins: Int? = nil
                if distanceM < 3000 {
                    walkingMins = await calculateWalkingTime(from: fromCoord, to: toCoord)
                }

                estimates[key] = TravelEstimate(
                    fromStopID: fromID,
                    toStopID: toID,
                    drivingMinutes: drivingMins,
                    walkingMinutes: walkingMins,
                    distanceMeters: distanceM,
                    isLoading: false
                )
            }
        } catch {
            // Mark as failed (not loading, no data)
            estimates[key] = TravelEstimate(
                fromStopID: fromID,
                toStopID: toID,
                drivingMinutes: nil,
                walkingMinutes: nil,
                distanceMeters: nil,
                isLoading: false
            )
        }
    }

    private func calculateWalkingTime(from: CLLocationCoordinate2D, to: CLLocationCoordinate2D) async -> Int? {
        let request = MKDirections.Request()
        request.source = MKMapItem(placemark: MKPlacemark(coordinate: from))
        request.destination = MKMapItem(placemark: MKPlacemark(coordinate: to))
        request.transportType = .walking

        let directions = MKDirections(request: request)
        do {
            let response = try await directions.calculate()
            if let route = response.routes.first {
                return Int(route.expectedTravelTime / 60)
            }
        } catch {
            // Walking not available
        }
        return nil
    }

    /// Get the estimate for a pair of stops.
    func estimate(from: UUID, to: UUID) -> TravelEstimate? {
        estimates[Self.key(from: from, to: to)]
    }
}
