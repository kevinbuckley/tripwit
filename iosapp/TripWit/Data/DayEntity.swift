import CoreData
import Foundation

@objc(DayEntity)
public class DayEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var date: Date?
    @NSManaged public var dayNumber: Int32
    @NSManaged public var notes: String?
    @NSManaged public var location: String?
    @NSManaged public var locationLatitude: Double
    @NSManaged public var locationLongitude: Double
    @NSManaged public var trip: TripEntity?
    @NSManaged public var stops: NSSet?
}

extension DayEntity: Identifiable {}

extension DayEntity {
    // MARK: - Safe accessors (non-optional wrappers)
    var wrappedDate: Date { date ?? Date() }
    var wrappedNotes: String { notes ?? "" }
    var wrappedLocation: String { location ?? "" }

    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: wrappedDate)
    }

    var stopsArray: [StopEntity] {
        (stops as? Set<StopEntity>)?.sorted { $0.sortOrder < $1.sortOrder } ?? []
    }

    @discardableResult
    static func create(
        in context: NSManagedObjectContext,
        date: Date,
        dayNumber: Int,
        notes: String = "",
        location: String = "",
        locationLatitude: Double = 0,
        locationLongitude: Double = 0
    ) -> DayEntity {
        let day = DayEntity(context: context)
        day.id = UUID()
        day.date = date
        day.dayNumber = Int32(dayNumber)
        day.notes = notes
        day.location = location
        day.locationLatitude = locationLatitude
        day.locationLongitude = locationLongitude
        return day
    }

    @objc(addStopsObject:)
    @NSManaged public func addToStops(_ value: StopEntity)
    @objc(removeStopsObject:)
    @NSManaged public func removeFromStops(_ value: StopEntity)
}
