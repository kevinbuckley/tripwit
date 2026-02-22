import CoreData
import Foundation
import TripCore

@objc(TripEntity)
public class TripEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var name: String?
    @NSManaged public var destination: String?
    @NSManaged public var startDate: Date?
    @NSManaged public var endDate: Date?
    @NSManaged public var statusRaw: String?
    @NSManaged public var coverPhotoAssetId: String?
    @NSManaged public var notes: String?
    @NSManaged public var createdAt: Date?
    @NSManaged public var updatedAt: Date?
    @NSManaged public var hasCustomDates: Bool
    @NSManaged public var budgetAmount: Double
    @NSManaged public var budgetCurrencyCode: String?
    @NSManaged public var days: NSSet?
    @NSManaged public var bookings: NSSet?
    @NSManaged public var lists: NSSet?
    @NSManaged public var expenses: NSSet?
}

extension TripEntity: Identifiable {}

extension TripEntity {
    // MARK: - Safe accessors (non-optional wrappers)
    var wrappedName: String { name ?? "" }
    var wrappedDestination: String { destination ?? "" }
    var wrappedStartDate: Date { startDate ?? Date() }
    var wrappedEndDate: Date { endDate ?? Date() }
    var wrappedStatusRaw: String { statusRaw ?? "planning" }
    var wrappedNotes: String { notes ?? "" }
    var wrappedBudgetCurrencyCode: String { budgetCurrencyCode ?? "USD" }
    var wrappedCreatedAt: Date { createdAt ?? Date() }
    var wrappedUpdatedAt: Date { updatedAt ?? Date() }

    var status: TripStatus {
        get { TripStatus(rawValue: wrappedStatusRaw) ?? .planning }
        set { statusRaw = newValue.rawValue }
    }

    var durationInDays: Int {
        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: wrappedStartDate)
        let startOfEnd = calendar.startOfDay(for: wrappedEndDate)
        let components = calendar.dateComponents([.day], from: startOfStart, to: startOfEnd)
        return (components.day ?? 0) + 1
    }

    var isActive: Bool {
        let now = Date()
        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: wrappedStartDate)
        let endOfEnd = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: wrappedEndDate) ?? wrappedEndDate)
        return now >= startOfStart && now < endOfEnd
    }

    var isPast: Bool {
        let calendar = Calendar.current
        let endOfEnd = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: wrappedEndDate) ?? wrappedEndDate)
        return Date() >= endOfEnd
    }

    var isFuture: Bool {
        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: wrappedStartDate)
        return Date() < startOfStart
    }

    var daysArray: [DayEntity] {
        (days as? Set<DayEntity>)?.sorted { $0.dayNumber < $1.dayNumber } ?? []
    }

    var bookingsArray: [BookingEntity] {
        (bookings as? Set<BookingEntity>)?.sorted { $0.sortOrder < $1.sortOrder } ?? []
    }

    var listsArray: [TripListEntity] {
        (lists as? Set<TripListEntity>)?.sorted { $0.sortOrder < $1.sortOrder } ?? []
    }

    var expensesArray: [ExpenseEntity] {
        (expenses as? Set<ExpenseEntity>)?.sorted { $0.sortOrder < $1.sortOrder } ?? []
    }

    @discardableResult
    static func create(
        in context: NSManagedObjectContext,
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        status: TripStatus = .planning,
        coverPhotoAssetId: String? = nil,
        notes: String = ""
    ) -> TripEntity {
        let trip = TripEntity(context: context)
        trip.id = UUID()
        trip.name = name
        trip.destination = destination
        trip.startDate = startDate
        trip.endDate = endDate
        trip.statusRaw = status.rawValue
        trip.coverPhotoAssetId = coverPhotoAssetId
        trip.notes = notes
        trip.createdAt = Date()
        trip.updatedAt = Date()
        trip.hasCustomDates = true
        trip.budgetAmount = 0
        trip.budgetCurrencyCode = "USD"
        return trip
    }

    // NSSet mutators for relationships
    @objc(addDaysObject:)
    @NSManaged public func addToDays(_ value: DayEntity)
    @objc(removeDaysObject:)
    @NSManaged public func removeFromDays(_ value: DayEntity)
    @objc(addBookingsObject:)
    @NSManaged public func addToBookings(_ value: BookingEntity)
    @objc(removeBookingsObject:)
    @NSManaged public func removeFromBookings(_ value: BookingEntity)
    @objc(addListsObject:)
    @NSManaged public func addToLists(_ value: TripListEntity)
    @objc(removeListsObject:)
    @NSManaged public func removeFromLists(_ value: TripListEntity)
    @objc(addExpensesObject:)
    @NSManaged public func addToExpenses(_ value: ExpenseEntity)
    @objc(removeExpensesObject:)
    @NSManaged public func removeFromExpenses(_ value: ExpenseEntity)
}
