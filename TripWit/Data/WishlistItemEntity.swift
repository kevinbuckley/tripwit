import CoreData
import Foundation
import TripCore

@objc(WishlistItemEntity)
public class WishlistItemEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var destination: String?
    @NSManaged public var latitude: Double
    @NSManaged public var longitude: Double
    @NSManaged public var categoryRaw: String?
    @NSManaged public var notes: String?
    @NSManaged public var address: String?
    @NSManaged public var phone: String?
    @NSManaged public var website: String?
    @NSManaged public var createdAt: Date?
}

extension WishlistItemEntity: Identifiable {}

extension WishlistItemEntity {
    // MARK: - Safe accessors (non-optional wrappers)
    var wrappedName: String { name ?? "" }
    var wrappedDestination: String { destination ?? "" }
    var wrappedCategoryRaw: String { categoryRaw ?? "other" }
    var wrappedNotes: String { notes ?? "" }
    var wrappedCreatedAt: Date { createdAt ?? Date() }

    var category: StopCategory {
        get { StopCategory(rawValue: wrappedCategoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    @discardableResult
    static func create(
        in context: NSManagedObjectContext,
        name: String,
        destination: String = "",
        latitude: Double = 0,
        longitude: Double = 0,
        category: StopCategory = .attraction,
        notes: String = "",
        address: String? = nil,
        phone: String? = nil,
        website: String? = nil
    ) -> WishlistItemEntity {
        let item = WishlistItemEntity(context: context)
        item.id = UUID()
        item.name = name
        item.destination = destination
        item.latitude = latitude
        item.longitude = longitude
        item.categoryRaw = category.rawValue
        item.notes = notes
        item.address = address
        item.phone = phone
        item.website = website
        item.createdAt = Date()
        return item
    }
}
