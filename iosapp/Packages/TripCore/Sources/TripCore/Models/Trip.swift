import Foundation

// MARK: - TripStatus

public enum TripStatus: String, Codable, Hashable, Sendable, CaseIterable {
    case planning
    case active
    case completed
}

// MARK: - Trip

public struct Trip: Codable, Identifiable, Hashable, Sendable {

    // MARK: Stored Properties

    public var id: UUID
    public var name: String
    public var destination: String
    public var startDate: Date
    public var endDate: Date
    public var status: TripStatus
    public var coverPhotoAssetId: String?
    public var notes: String
    public var createdAt: Date
    public var updatedAt: Date
    public var days: [Day]

    // MARK: Computed Properties

    /// The number of calendar days the trip spans (inclusive of both start and end date).
    public var durationInDays: Int {
        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: startDate)
        let startOfEnd = calendar.startOfDay(for: endDate)
        let components = calendar.dateComponents([.day], from: startOfStart, to: startOfEnd)
        return (components.day ?? 0) + 1
    }

    /// Whether the trip is currently active based on today's date.
    public var isActive: Bool {
        let now = Date()
        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: startDate)
        let endOfEnd = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate)
        return now >= startOfStart && now < endOfEnd
    }

    /// Whether the trip end date is in the past.
    public var isPast: Bool {
        let calendar = Calendar.current
        let endOfEnd = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: endDate) ?? endDate)
        return Date() >= endOfEnd
    }

    /// Whether the trip start date is in the future.
    public var isFuture: Bool {
        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: startDate)
        return Date() < startOfStart
    }

    // MARK: Initializer

    public init(
        id: UUID = UUID(),
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        status: TripStatus = .planning,
        coverPhotoAssetId: String? = nil,
        notes: String = "",
        createdAt: Date = Date(),
        updatedAt: Date = Date(),
        days: [Day] = []
    ) {
        self.id = id
        self.name = name
        self.destination = destination
        self.startDate = startDate
        self.endDate = endDate
        self.status = status
        self.coverPhotoAssetId = coverPhotoAssetId
        self.notes = notes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
        self.days = days
    }
}
