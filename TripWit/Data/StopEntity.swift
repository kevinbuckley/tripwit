import CoreData
import Foundation
import TripCore

@objc(StopEntity)
public class StopEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var arrivalTime: Date?
    @NSManaged public var departureTime: Date?
    @NSManaged public var categoryRaw: String?
    @NSManaged public var notes: String?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var isVisited: Bool
    @NSManaged public var visitedAt: Date?
    @NSManaged public var rating: Int32
    @NSManaged public var address: String?
    @NSManaged public var phone: String?
    @NSManaged public var website: String?
    @NSManaged public var day: DayEntity?
    @NSManaged public var comments: NSSet?
    @NSManaged public var links: NSSet?
    @NSManaged public var todos: NSSet?
}

extension StopEntity: Identifiable {}

extension StopEntity {
    // MARK: - Safe accessors (non-optional wrappers)
    var wrappedName: String { name ?? "" }
    var wrappedCategoryRaw: String { categoryRaw ?? "other" }
    var wrappedNotes: String { notes ?? "" }

    var category: StopCategory {
        get { StopCategory(rawValue: wrappedCategoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    var commentsArray: [CommentEntity] {
        (comments as? Set<CommentEntity>)?.sorted { ($0.createdAt ?? .distantPast) < ($1.createdAt ?? .distantPast) } ?? []
    }

    var linksArray: [StopLinkEntity] {
        (links as? Set<StopLinkEntity>)?.sorted { $0.sortOrder < $1.sortOrder } ?? []
    }

    var todosArray: [StopTodoEntity] {
        (todos as? Set<StopTodoEntity>)?.sorted { $0.sortOrder < $1.sortOrder } ?? []
    }

    @discardableResult
    static func create(
        in context: NSManagedObjectContext,
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
    ) -> StopEntity {
        let stop = StopEntity(context: context)
        stop.id = UUID()
        stop.name = name
        stop.latitude = latitude
        stop.longitude = longitude
        stop.arrivalTime = arrivalTime
        stop.departureTime = departureTime
        stop.categoryRaw = category.rawValue
        stop.sortOrder = Int32(sortOrder)
        stop.notes = notes
        stop.isVisited = isVisited
        stop.visitedAt = visitedAt
        stop.rating = 0
        stop.address = address
        stop.phone = phone
        stop.website = website
        return stop
    }

    @objc(addCommentsObject:)
    @NSManaged public func addToComments(_ value: CommentEntity)
    @objc(removeCommentsObject:)
    @NSManaged public func removeFromComments(_ value: CommentEntity)
}
