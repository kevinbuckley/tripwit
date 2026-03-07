import CoreSpotlight
import CoreData
import Foundation
import TripCore

/// Indexes TripWit trips and stops in Spotlight so users can find them from the home screen.
struct SpotlightService {

    static let tripDomain = "com.kevinbuckley.travelplanner.trips"
    static let stopDomain = "com.kevinbuckley.travelplanner.stops"

    // MARK: - Index

    /// Index a single trip and all its stops.
    static func indexTrip(_ trip: TripEntity) {
        var items: [CSSearchableItem] = []

        // Trip item
        let tripAttr = CSSearchableItemAttributeSet(contentType: .text)
        tripAttr.title = trip.wrappedName
        tripAttr.contentDescription = "Trip to \(trip.wrappedDestination)"
        if let start = trip.startDate, let end = trip.endDate {
            let df = DateFormatter()
            df.dateStyle = .medium
            tripAttr.contentDescription = "\(trip.wrappedDestination) · \(df.string(from: start)) – \(df.string(from: end))"
        }
        tripAttr.keywords = [trip.wrappedName, trip.wrappedDestination, "trip", "travel"]
        items.append(CSSearchableItem(
            uniqueIdentifier: tripIdentifier(trip),
            domainIdentifier: tripDomain,
            attributeSet: tripAttr
        ))

        // Stop items
        for day in trip.daysArray {
            for stop in day.stopsArray {
                items.append(stopItem(stop, tripName: trip.wrappedName))
            }
        }

        CSSearchableIndex.default().indexSearchableItems(items) { _ in }
    }

    /// Index all trips in the context.
    static func indexAllTrips(in context: NSManagedObjectContext) {
        let request = TripEntity.fetchRequest() as! NSFetchRequest<TripEntity>
        let trips = (try? context.fetch(request)) ?? []
        for trip in trips { indexTrip(trip) }
    }

    // MARK: - Deindex

    static func deindexTrip(_ trip: TripEntity) {
        var ids = [tripIdentifier(trip)]
        for day in trip.daysArray {
            for stop in day.stopsArray {
                ids.append(stopIdentifier(stop))
            }
        }
        CSSearchableIndex.default().deleteSearchableItems(withIdentifiers: ids) { _ in }
    }

    static func deindexAllTrips() {
        CSSearchableIndex.default().deleteAllSearchableItems { _ in }
    }

    // MARK: - Deep link identifiers

    static func tripIdentifier(_ trip: TripEntity) -> String {
        "trip-\(trip.id?.uuidString ?? trip.wrappedName)"
    }

    static func stopIdentifier(_ stop: StopEntity) -> String {
        "stop-\(stop.id?.uuidString ?? stop.wrappedName)"
    }

    /// Returns the trip ID and stop ID encoded in a Spotlight identifier.
    static func decode(identifier: String) -> (kind: String, id: String)? {
        if identifier.hasPrefix("trip-") {
            return ("trip", String(identifier.dropFirst(5)))
        }
        if identifier.hasPrefix("stop-") {
            return ("stop", String(identifier.dropFirst(5)))
        }
        return nil
    }

    // MARK: - Helpers

    private static func stopItem(_ stop: StopEntity, tripName: String) -> CSSearchableItem {
        let attr = CSSearchableItemAttributeSet(contentType: .text)
        attr.title = stop.wrappedName
        attr.contentDescription = "\(stop.category.rawValue.capitalized) · \(tripName)"
        attr.latitude = stop.latitude as NSNumber
        attr.longitude = stop.longitude as NSNumber
        if let address = stop.address { attr.thoroughfare = address }
        attr.keywords = [stop.wrappedName, tripName, stop.category.rawValue, "stop", "travel"]
        return CSSearchableItem(
            uniqueIdentifier: stopIdentifier(stop),
            domainIdentifier: stopDomain,
            attributeSet: attr
        )
    }
}
