import SwiftData
import Foundation
import TripCore

@Model
final class TripEntity {

    // MARK: Stored Properties

    var id: UUID
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var statusRaw: String
    var coverPhotoAssetId: String?
    var notes: String
    var createdAt: Date
    var updatedAt: Date

    @Relationship(deleteRule: .cascade, inverse: \DayEntity.trip)
    var days: [DayEntity]

    @Relationship(deleteRule: .cascade, inverse: \BookingEntity.trip)
    var bookings: [BookingEntity]

    // MARK: Computed Properties

    var status: TripStatus {
        get { TripStatus(rawValue: statusRaw) ?? .planning }
        set { statusRaw = newValue.rawValue }
    }

    /// The number of calendar days the trip spans (inclusive of both start and end date).
    var durationInDays: Int {
        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: startDate)
        let startOfEnd = calendar.startOfDay(for: endDate)
        let components = calendar.dateComponents([.day], from: startOfStart, to: startOfEnd)
        return (components.day ?? 0) + 1
    }

    /// Whether the trip is currently active based on today's date.
    var isActive: Bool {
        let now = Date()
        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: startDate)
        let endOfEnd = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        )
        return now >= startOfStart && now < endOfEnd
    }

    /// Whether the trip end date is in the past.
    var isPast: Bool {
        let calendar = Calendar.current
        let endOfEnd = calendar.startOfDay(
            for: calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate
        )
        return Date() >= endOfEnd
    }

    /// Whether the trip start date is in the future.
    var isFuture: Bool {
        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: startDate)
        return Date() < startOfStart
    }

    // MARK: Initializer

    init(
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        status: TripStatus = .planning,
        coverPhotoAssetId: String? = nil,
        notes: String = ""
    ) {
        self.id = UUID()
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.statusRaw = status.rawValue
        self.coverPhotoAssetId = coverPhotoAssetId
        self.notes = notes
        self.createdAt = Date()
        self.updatedAt = Date()
        self.days = []
        self.bookings = []
    }
}
