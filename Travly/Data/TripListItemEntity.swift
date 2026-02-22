import CoreData
import Foundation

@objc(TripListItemEntity)
public class TripListItemEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var text: String?
    @NSManaged public var isChecked: Bool
    @NSManaged public var sortOrder: Int32
    @NSManaged public var list: TripListEntity?
}

extension TripListItemEntity: Identifiable {}

extension TripListItemEntity {
    // MARK: - Safe accessors (non-optional wrappers)
    var wrappedText: String { text ?? "" }

    @discardableResult
    static func create(
        in context: NSManagedObjectContext,
        text: String,
        sortOrder: Int = 0
    ) -> TripListItemEntity {
        let item = TripListItemEntity(context: context)
        item.id = UUID()
        item.text = text
        item.isChecked = false
        item.sortOrder = Int32(sortOrder)
        return item
    }
}
