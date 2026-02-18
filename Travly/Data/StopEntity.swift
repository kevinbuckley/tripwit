import SwiftData
import Foundation
import TripCore

@Model
final class StopEntity {

    // MARK: Stored Properties

    var id: UUID
    var name: String
    var latitude: Double
    var longitude: Double
    var arrivalTime: Date?
    var departureTime: Date?
    var categoryRaw: String
    var notes: String
    var sortOrder: Int
    var isVisited: Bool
    var visitedAt: Date?
    var rating: Int
    var address: String?
    var phone: String?
    var website: String?

    var day: DayEntity?

    @Relationship(deleteRule: .cascade, inverse: \CommentEntity.stop)
    var comments: [CommentEntity]

    // MARK: Computed Properties

    var category: StopCategory {
        get { StopCategory(rawValue: categoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    // MARK: Initializer

    init(
        name: String,
        latitude: Double,
        longitude: Double,
        category: StopCategory = .other,
        arrivalTime: Date? = nil,
        departureTime: Date? = nil,
        sortOrder: Int = 0,
        notes: String = "",
        isVisited: Bool = false,
        visitedAt: Date? = nil,
        address: String? = nil,
        phone: String? = nil,
        website: String? = nil
    ) {
        self.id = UUID()
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.arrivalTime = arrivalTime
        self.departureTime = departureTime
        self.categoryRaw = category.rawValue
        self.sortOrder = sortOrder
        self.notes = notes
        self.isVisited = isVisited
        self.visitedAt = visitedAt
        self.rating = 0
        self.address = address
        self.phone = phone
        self.website = website
        self.comments = []
    }
}
