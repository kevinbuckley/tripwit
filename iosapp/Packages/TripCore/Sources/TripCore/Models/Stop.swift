import Foundation

// MARK: - StopCategory

public enum StopCategory: String, Codable, Hashable, Sendable, CaseIterable {
    case accommodation
    case restaurant
    case attraction
    case transport
    case activity
    case other
}

// MARK: - Stop

public struct Stop: Codable, Identifiable, Hashable, Sendable {

    // MARK: Stored Properties

    public var id: UUID
    public var dayId: UUID
    public var name: String
    public var latitude: Double
    public var longitude: Double
    public var arrivalTime: Date?
    public var departureTime: Date?
    public var category: StopCategory
    public var notes: String
    public var sortOrder: Int
    public var matchedPhotos: [MatchedPhoto]

    // MARK: Initializer

    public init(
        id: UUID = UUID(),
        dayId: UUID,
        name: String,
        latitude: Double,
        longitude: Double,
        arrivalTime: Date? = nil,
        departureTime: Date? = nil,
        category: StopCategory = .other,
        notes: String = "",
        sortOrder: Int = 0,
        matchedPhotos: [MatchedPhoto] = []
    ) {
        self.id = id
        self.dayId = dayId
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.arrivalTime = arrivalTime
        self.departureTime = departureTime
        self.category = category
        self.notes = notes
        self.sortOrder = sortOrder
        self.matchedPhotos = matchedPhotos
    }
}
