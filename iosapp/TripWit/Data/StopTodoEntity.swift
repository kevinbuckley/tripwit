import CoreData
import Foundation

@objc(StopTodoEntity)
public class StopTodoEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var text: String?
    @NSManaged public var isCompleted: Bool
    @NSManaged public var sortOrder: Int32
    @NSManaged public var stop: StopEntity?
}

extension StopTodoEntity: Identifiable {}

extension StopTodoEntity {
    var wrappedText: String { text ?? "" }

    @discardableResult
    static func create(
        in context: NSManagedObjectContext,
        text: String,
        sortOrder: Int = 0
    ) -> StopTodoEntity {
        let todo = StopTodoEntity(context: context)
        todo.id = UUID()
        todo.text = text
        todo.isCompleted = false
        todo.sortOrder = Int32(sortOrder)
        return todo
    }
}
