import Foundation
import CoreData

/// Manages NSUserActivity for Handoff — lets users continue viewing a trip
/// on another signed-in Apple device (iPad, Mac, Vision Pro).
enum HandoffManager {

    // MARK: - Activity Types

    /// Registered in Info.plist NSUserActivityTypes.
    static let viewTripActivityType = "com.kevinbuckley.travelplanner.viewTrip"
    static let viewStopActivityType = "com.kevinbuckley.travelplanner.viewStop"

    // MARK: - User Info Keys

    enum Key {
        static let tripID   = "tripID"
        static let tripName = "tripName"
        static let stopID   = "stopID"
        static let stopName = "stopName"
    }

    // MARK: - Activity Creation

    /// Creates an NSUserActivity for viewing a specific trip.
    static func activity(for trip: TripEntity) -> NSUserActivity {
        let activity = NSUserActivity(activityType: viewTripActivityType)
        activity.title = trip.wrappedName
        activity.isEligibleForHandoff = true
        activity.isEligibleForSearch = false   // CoreSpotlight handles search
        activity.userInfo = userInfo(for: trip)
        activity.becomeCurrent()
        return activity
    }

    /// Creates an NSUserActivity for viewing a specific stop.
    static func activity(forStop stop: StopEntity, in trip: TripEntity) -> NSUserActivity {
        let activity = NSUserActivity(activityType: viewStopActivityType)
        activity.title = stop.wrappedName
        activity.isEligibleForHandoff = true
        activity.userInfo = userInfo(forStop: stop, in: trip)
        activity.becomeCurrent()
        return activity
    }

    // MARK: - User Info Builders

    static func userInfo(for trip: TripEntity) -> [String: Any] {
        var info: [String: Any] = [:]
        if let id = trip.id {
            info[Key.tripID] = id.uuidString
        }
        info[Key.tripName] = trip.wrappedName
        return info
    }

    static func userInfo(forStop stop: StopEntity, in trip: TripEntity) -> [String: Any] {
        var info = userInfo(for: trip)
        if let id = stop.id {
            info[Key.stopID] = id.uuidString
        }
        info[Key.stopName] = stop.wrappedName
        return info
    }

    // MARK: - Restoration

    /// Extracts the trip UUID from an incoming Handoff activity's userInfo.
    static func tripID(from activity: NSUserActivity) -> UUID? {
        guard activity.activityType == viewTripActivityType ||
              activity.activityType == viewStopActivityType,
              let uuidString = activity.userInfo?[Key.tripID] as? String
        else { return nil }
        return UUID(uuidString: uuidString)
    }

    /// Extracts the stop UUID from an incoming Handoff activity's userInfo.
    static func stopID(from activity: NSUserActivity) -> UUID? {
        guard activity.activityType == viewStopActivityType,
              let uuidString = activity.userInfo?[Key.stopID] as? String
        else { return nil }
        return UUID(uuidString: uuidString)
    }
}
