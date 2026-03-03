import CoreData
import SwiftUI
import Foundation

@objc(ExpenseEntity)
public class ExpenseEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var title: String?
    @NSManaged public var amount: Double
    @NSManaged public var currencyCode: String?
    @NSManaged public var dateIncurred: Date?
    @NSManaged public var categoryRaw: String?
    @NSManaged public var notes: String?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var createdAt: Date?
    @NSManaged public var trip: TripEntity?
}

extension ExpenseEntity: Identifiable {}

extension ExpenseEntity {
    // MARK: - Safe accessors (non-optional wrappers)
    var wrappedTitle: String { title ?? "" }
    var wrappedCurrencyCode: String { currencyCode ?? "USD" }
    var wrappedDateIncurred: Date { dateIncurred ?? Date() }
    var wrappedCategoryRaw: String { categoryRaw ?? "other" }
    var wrappedNotes: String { notes ?? "" }
    var wrappedCreatedAt: Date { createdAt ?? Date() }

    var category: ExpenseCategory {
        get { ExpenseCategory(rawValue: wrappedCategoryRaw) ?? .other }
        set { categoryRaw = newValue.rawValue }
    }

    @discardableResult
    static func create(
        in context: NSManagedObjectContext,
        title: String,
        amount: Double,
        currencyCode: String = "USD",
        dateIncurred: Date = Date(),
        category: ExpenseCategory = .other,
        notes: String = "",
        sortOrder: Int = 0
    ) -> ExpenseEntity {
        let expense = ExpenseEntity(context: context)
        expense.id = UUID()
        expense.title = title
        expense.amount = amount
        expense.currencyCode = currencyCode
        expense.dateIncurred = dateIncurred
        expense.categoryRaw = category.rawValue
        expense.notes = notes
        expense.sortOrder = Int32(sortOrder)
        expense.createdAt = Date()
        return expense
    }
}

// MARK: - ExpenseCategory
enum ExpenseCategory: String, Codable, CaseIterable {
    case accommodation
    case food
    case transport
    case activity
    case shopping
    case other

    var label: String {
        switch self {
        case .accommodation: "Accommodation"
        case .food: "Food & Drink"
        case .transport: "Transport"
        case .activity: "Activities"
        case .shopping: "Shopping"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .accommodation: "bed.double.fill"
        case .food: "fork.knife"
        case .transport: "car.fill"
        case .activity: "ticket.fill"
        case .shopping: "bag.fill"
        case .other: "ellipsis.circle.fill"
        }
    }

    var color: Color {
        switch self {
        case .accommodation: .purple
        case .food: .orange
        case .transport: .blue
        case .activity: .green
        case .shopping: .pink
        case .other: .gray
        }
    }
}
