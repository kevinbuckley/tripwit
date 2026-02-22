import CoreData
import Foundation

@objc(StopLinkEntity)
public class StopLinkEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var url: String?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var stop: StopEntity?
}

extension StopLinkEntity: Identifiable {}

extension StopLinkEntity {
    var wrappedTitle: String { title ?? "" }
    var wrappedURL: String { url ?? "" }

    /// Display label: uses title if set, otherwise the URL hostname.
    var displayLabel: String {
        if !wrappedTitle.isEmpty { return wrappedTitle }
        if let parsed = URL(string: wrappedURL), let host = parsed.host {
            return host
        }
        return wrappedURL
    }

    @discardableResult
    static func create(
        in context: NSManagedObjectContext,
        title: String = "",
        url: String,
        sortOrder: Int = 0
    ) -> StopLinkEntity {
        let link = StopLinkEntity(context: context)
        link.id = UUID()
        link.title = title
        link.url = url
        link.sortOrder = Int32(sortOrder)
        return link
    }
}
