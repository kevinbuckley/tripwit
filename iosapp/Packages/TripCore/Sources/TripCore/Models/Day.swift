import Foundation

public struct Day: Codable, Identifiable, Hashable, Sendable {

    // MARK: Stored Properties

    public var id: UUID
    public var tripId: UUID
    public var date: Date
    public var dayNumber: Int
    public var notes: String
    public var stops: [Stop]

    // MARK: Computed Properties

    /// A human-readable formatted date string (e.g. "Feb 14, 2026").
    public var formattedDate: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    // MARK: Initializer

    public init(
        id: UUID = UUID(),
        tripId: UUID,
        date: Date,
        dayNumber: Int,
        notes: String = "",
        stops: [Stop] = []
    ) {
        self.id = id
        self.tripId = tripId
        self.date = date
        self.dayNumber = dayNumber
        self.notes = notes
        self.stops = stops
    }
}
