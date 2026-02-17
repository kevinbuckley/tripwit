import SwiftData
import Foundation

@Model
final class DayEntity {

    // MARK: Stored Properties

    var id: UUID
    var date: Date
    var dayNumber: Int
    var notes: String
    var location: String
    var locationLatitude: Double
    var locationLongitude: Double

    var trip: TripEntity?

    @Relationship(deleteRule: .cascade, inverse: \StopEntity.day)
    var stops: [StopEntity]

    // MARK: Computed Properties

    /// A human-readable formatted date string (e.g. "Feb 14, 2026").
    var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: Initializer

    init(date: Date, dayNumber: Int, notes: String = "", location: String = "", locationLatitude: Double = 0, locationLongitude: Double = 0) {
        self.id = UUID()
        self.date = date
        self.dayNumber = dayNumber
        self.notes = notes
        self.location = location
        self.locationLatitude = locationLatitude
        self.locationLongitude = locationLongitude
        self.stops = []
    }
}
