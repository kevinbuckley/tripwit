import CoreData
import Foundation

@objc(CommentEntity)
public class CommentEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var text: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var stop: StopEntity?
}

extension CommentEntity: Identifiable {}

extension CommentEntity {
    // MARK: - Safe accessors (non-optional wrappers)
    var wrappedText: String { text ?? "" }
    var wrappedCreatedAt: Date { createdAt ?? Date() }

    @discardableResult
    static func create(
        in context: NSManagedObjectContext,
        text: String
    ) -> CommentEntity {
        let comment = CommentEntity(context: context)
        comment.id = UUID()
        comment.text = text
        comment.createdAt = Date()
        return comment
    }
}
