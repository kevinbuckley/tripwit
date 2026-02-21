import CoreData
import Foundation

@objc(TripListEntity)
public class TripListEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var icon: String?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var trip: TripEntity?
    @NSManaged public var items: NSSet?
}

extension TripListEntity: Identifiable {}

extension TripListEntity {
    // MARK: - Safe accessors (non-optional wrappers)
    var wrappedName: String { name ?? "" }
    var wrappedIcon: String { icon ?? "list.bullet" }

    var itemsArray: [TripListItemEntity] {
        (items as? Set<TripListItemEntity>)?.sorted { $0.sortOrder < $1.sortOrder } ?? []
    }

    @discardableResult
    static func create(
        in context: NSManagedObjectContext,
        name: String,
        icon: String = "list.bullet",
        sortOrder: Int = 0
    ) -> TripListEntity {
        let list = TripListEntity(context: context)
        list.id = UUID()
        list.name = name
        list.icon = icon
        list.sortOrder = Int32(sortOrder)
        return list
    }

    @objc(addItemsObject:)
    @NSManaged public func addToItems(_ value: TripListItemEntity)
    @objc(removeItemsObject:)
    @NSManaged public func removeFromItems(_ value: TripListItemEntity)
}
