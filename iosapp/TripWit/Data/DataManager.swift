import CoreData
import SwiftUI
import Foundation
import TripCore

// MARK: - Validation

enum ValidationError: LocalizedError, Equatable {
    case emptyTripName
    case emptyDestination
    case endDateBeforeStartDate
    case emptyStopName
    case departureBeforeArrival
    case emptyExpenseTitle
    case negativeExpenseAmount
    case emptyBookingTitle
    case bookingArrivalBeforeDeparture

    var errorDescription: String? {
        switch self {
        case .emptyTripName: "Trip name cannot be empty"
        case .emptyDestination: "Destination cannot be empty"
        case .endDateBeforeStartDate: "End date must be on or after start date"
        case .emptyStopName: "Stop name cannot be empty"
        case .departureBeforeArrival: "Departure time must be after arrival time"
        case .emptyExpenseTitle: "Expense title cannot be empty"
        case .negativeExpenseAmount: "Expense amount cannot be negative"
        case .emptyBookingTitle: "Booking title cannot be empty"
        case .bookingArrivalBeforeDeparture: "Arrival time must be after departure time"
        }
    }
}

@Observable
final class DataManager {

    let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Validation Helpers

    static func validateTrip(name: String, destination: String, startDate: Date, endDate: Date) throws {
        let trimmedName = name.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedDest = destination.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedName.isEmpty { throw ValidationError.emptyTripName }
        if trimmedDest.isEmpty { throw ValidationError.emptyDestination }
        let calendar = Calendar.current
        let startDay = calendar.startOfDay(for: startDate)
        let endDay = calendar.startOfDay(for: endDate)
        if endDay < startDay { throw ValidationError.endDateBeforeStartDate }
    }

    static func validateStop(name: String, arrivalTime: Date? = nil, departureTime: Date? = nil) throws {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw ValidationError.emptyStopName }
        if let arrival = arrivalTime, let departure = departureTime, departure <= arrival {
            throw ValidationError.departureBeforeArrival
        }
    }

    static func validateExpense(title: String, amount: Double) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw ValidationError.emptyExpenseTitle }
        if amount < 0 { throw ValidationError.negativeExpenseAmount }
    }

    static func validateBooking(title: String, departureTime: Date? = nil, arrivalTime: Date? = nil) throws {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty { throw ValidationError.emptyBookingTitle }
        if let dep = departureTime, let arr = arrivalTime, arr <= dep {
            throw ValidationError.bookingArrivalBeforeDeparture
        }
    }

    // MARK: - Validated Create Methods

    @discardableResult
    func createValidatedTrip(
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        notes: String = ""
    ) throws -> TripEntity {
        try Self.validateTrip(name: name, destination: destination, startDate: startDate, endDate: endDate)
        return createTrip(name: name, destination: destination, startDate: startDate, endDate: endDate, notes: notes)
    }

    @discardableResult
    func addValidatedStop(
        to day: DayEntity,
        name: String,
        latitude: Double,
        longitude: Double,
        category: StopCategory,
        arrivalTime: Date? = nil,
        departureTime: Date? = nil,
        notes: String = ""
    ) throws -> StopEntity {
        try Self.validateStop(name: name, arrivalTime: arrivalTime, departureTime: departureTime)
        return addStop(to: day, name: name, latitude: latitude, longitude: longitude, category: category, notes: notes)
    }

    @discardableResult
    func addValidatedExpense(
        to trip: TripEntity,
        title: String,
        amount: Double,
        category: ExpenseCategory = .other,
        date: Date = Date(),
        notes: String = ""
    ) throws -> ExpenseEntity {
        try Self.validateExpense(title: title, amount: amount)
        return addExpense(to: trip, title: title, amount: amount, category: category, date: date, notes: notes)
    }

    // MARK: - Trips

    func fetchTrips() -> [TripEntity] {
        let request = TripEntity.fetchRequest() as! NSFetchRequest<TripEntity>
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    @discardableResult
    func createTrip(
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        notes: String = ""
    ) -> TripEntity {
        let trip = TripEntity.create(
            in: context,
            name: name,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            notes: notes
        )
        generateDays(for: trip)
        try? context.save()
        return trip
    }

    func updateTrip(_ trip: TripEntity) {
        trip.updatedAt = Date()
        try? context.save()
    }

    func deleteTrip(_ trip: TripEntity) {
        context.delete(trip)
        try? context.save()
    }

    // MARK: - Days

    func generateDays(for trip: TripEntity) {
        // Remove existing days
        for day in trip.daysArray {
            context.delete(day)
        }

        guard let tripStart = trip.startDate, let tripEnd = trip.endDate else { return }

        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: tripStart)
        let startOfEnd = calendar.startOfDay(for: tripEnd)

        var currentDate = startOfStart
        var dayNumber = 1

        while currentDate <= startOfEnd {
            let day = DayEntity.create(
                in: context,
                date: currentDate,
                dayNumber: dayNumber,
                location: trip.destination ?? ""
            )
            day.trip = trip
            dayNumber += 1
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
    }

    /// Smart day sync: keeps days that still fall within the new date range,
    /// deletes days outside it, and creates new days for uncovered dates.
    /// Renumbers all surviving + new days sequentially by date.
    func syncDays(for trip: TripEntity) {
        guard let tripStart = trip.startDate, let tripEnd = trip.endDate else { return }

        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: tripStart)
        let startOfEnd = calendar.startOfDay(for: tripEnd)

        // Build the set of calendar dates in the new range
        var newDateSet: Set<DateComponents> = []
        var allNewDates: [Date] = []
        var current = startOfStart
        while current <= startOfEnd {
            let comps = calendar.dateComponents([.year, .month, .day], from: current)
            newDateSet.insert(comps)
            allNewDates.append(current)
            guard let next = calendar.date(byAdding: .day, value: 1, to: current) else { break }
            current = next
        }

        // Classify existing days: keep or delete
        var coveredDates: Set<DateComponents> = []
        for day in trip.daysArray {
            let comps = calendar.dateComponents([.year, .month, .day], from: day.wrappedDate)
            if newDateSet.contains(comps) {
                coveredDates.insert(comps)
            } else {
                context.delete(day)
            }
        }

        // Create new days for uncovered dates
        for date in allNewDates {
            let comps = calendar.dateComponents([.year, .month, .day], from: date)
            if !coveredDates.contains(comps) {
                let day = DayEntity.create(
                    in: context,
                    date: date,
                    dayNumber: 0, // will be renumbered below
                    location: trip.destination ?? ""
                )
                day.trip = trip
            }
        }

        // Renumber all days sequentially by date (exclude pending-delete objects)
        let sortedDays = trip.daysArray.filter { !$0.isDeleted }.sorted { $0.wrappedDate < $1.wrappedDate }
        for (index, day) in sortedDays.enumerated() {
            day.dayNumber = Int32(index + 1)
        }
    }

    /// Count how many existing days with stops will be lost if dates change.
    func daysWithStopsOutsideRange(for trip: TripEntity, newStart: Date, newEnd: Date) -> Int {
        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: newStart)
        let startOfEnd = calendar.startOfDay(for: newEnd)

        return trip.daysArray.filter { day in
            let dayDate = calendar.startOfDay(for: day.wrappedDate)
            let isOutside = dayDate < startOfStart || dayDate > startOfEnd
            return isOutside && !day.stopsArray.isEmpty
        }.count
    }

    // MARK: - Stops

    @discardableResult
    func addStop(
        to day: DayEntity,
        name: String,
        latitude: Double,
        longitude: Double,
        category: StopCategory,
        notes: String = ""
    ) -> StopEntity {
        let sortOrder = day.stopsArray.count
        let stop = StopEntity.create(
            in: context,
            name: name,
            latitude: latitude,
            longitude: longitude,
            category: category,
            sortOrder: sortOrder,
            notes: notes
        )
        stop.day = day
        // Touch the trip so @ObservedObject triggers a refresh in TripDetailView
        day.trip?.updatedAt = Date()
        try? context.save()
        return stop
    }

    func deleteStop(_ stop: StopEntity) {
        stop.day?.trip?.updatedAt = Date()
        context.delete(stop)
        try? context.save()
    }

    func toggleVisited(_ stop: StopEntity) {
        stop.isVisited.toggle()
        stop.visitedAt = stop.isVisited ? Date() : nil
        stop.day?.trip?.updatedAt = Date()
        try? context.save()
    }

    /// Batch mark multiple stops as visited or not visited.
    func batchSetVisited(_ stops: [StopEntity], visited: Bool) {
        let now = Date()
        for stop in stops {
            stop.isVisited = visited
            stop.visitedAt = visited ? now : nil
        }
        stops.first?.day?.trip?.updatedAt = now
        try? context.save()
    }

    /// Mark all stops on a given day as visited or not visited.
    func batchSetDayVisited(_ day: DayEntity, visited: Bool) {
        batchSetVisited(day.stopsArray, visited: visited)
    }

    func moveStop(_ stop: StopEntity, to targetDay: DayEntity) {
        if let currentDay = stop.day {
            currentDay.removeFromStops(stop)
        }
        stop.sortOrder = Int32(targetDay.stopsArray.count)
        stop.day = targetDay
        targetDay.trip?.updatedAt = Date()
        try? context.save()
    }

    func reorderStops(in day: DayEntity, from source: IndexSet, to destination: Int) {
        var stops = day.stopsArray
        stops.move(fromOffsets: source, toOffset: destination)
        for (index, stop) in stops.enumerated() {
            stop.sortOrder = Int32(index)
        }
        day.trip?.updatedAt = Date()
        try? context.save()
    }

    // MARK: - Expenses

    @discardableResult
    func addExpense(
        to trip: TripEntity,
        title: String,
        amount: Double,
        category: ExpenseCategory = .other,
        date: Date = Date(),
        notes: String = ""
    ) -> ExpenseEntity {
        let expense = ExpenseEntity.create(
            in: context,
            title: title,
            amount: amount,
            currencyCode: trip.budgetCurrencyCode ?? "USD",
            dateIncurred: date,
            category: category,
            notes: notes,
            sortOrder: trip.expensesArray.count
        )
        expense.trip = trip
        trip.updatedAt = Date()
        try? context.save()
        return expense
    }

    func deleteExpense(_ expense: ExpenseEntity) {
        expense.trip?.updatedAt = Date()
        context.delete(expense)
        try? context.save()
    }

    // MARK: - Cloning

    /// Deep-clone a trip as a template. Copies all days, stops (with comments/links/todos),
    /// bookings, lists (with items), and the budget. Resets status to `.planning`,
    /// clears visited state on stops, and shifts dates so the clone starts on `newStartDate`.
    @discardableResult
    func cloneTrip(_ source: TripEntity, newStartDate: Date) -> TripEntity {
        let calendar = Calendar.current
        let duration = source.durationInDays
        let newEnd = calendar.date(byAdding: .day, value: max(duration - 1, 0), to: calendar.startOfDay(for: newStartDate))!

        let clone = TripEntity.create(
            in: context,
            name: "\(source.wrappedName) (Copy)",
            destination: source.wrappedDestination,
            startDate: calendar.startOfDay(for: newStartDate),
            endDate: newEnd,
            status: .planning,
            notes: source.wrappedNotes
        )
        clone.budgetAmount = source.budgetAmount
        clone.budgetCurrencyCode = source.budgetCurrencyCode
        clone.hasCustomDates = source.hasCustomDates

        // Clone days with stops
        generateDays(for: clone)
        let sourceDays = source.daysArray.sorted { $0.dayNumber < $1.dayNumber }
        let cloneDays = clone.daysArray.sorted { $0.dayNumber < $1.dayNumber }

        for (sourceDay, cloneDay) in zip(sourceDays, cloneDays) {
            cloneDay.notes = sourceDay.wrappedNotes
            cloneDay.location = sourceDay.wrappedLocation
            cloneDay.locationLatitude = sourceDay.locationLatitude
            cloneDay.locationLongitude = sourceDay.locationLongitude

            for sourceStop in sourceDay.stopsArray {
                let newStop = StopEntity.create(
                    in: context,
                    name: sourceStop.wrappedName,
                    latitude: sourceStop.latitude,
                    longitude: sourceStop.longitude,
                    category: sourceStop.category,
                    sortOrder: Int(sourceStop.sortOrder),
                    notes: sourceStop.wrappedNotes,
                    address: sourceStop.address,
                    phone: sourceStop.phone,
                    website: sourceStop.website
                )
                newStop.day = cloneDay
                newStop.rating = sourceStop.rating

                // Clone comments
                for comment in sourceStop.commentsArray {
                    let newComment = CommentEntity.create(in: context, text: comment.wrappedText)
                    newComment.stop = newStop
                }
                // Clone links
                for link in sourceStop.linksArray {
                    let newLink = StopLinkEntity.create(in: context, title: link.wrappedTitle, url: link.wrappedURL, sortOrder: Int(link.sortOrder))
                    newLink.stop = newStop
                }
                // Clone todos
                for todo in sourceStop.todosArray {
                    let newTodo = StopTodoEntity.create(in: context, text: todo.wrappedText, sortOrder: Int(todo.sortOrder))
                    newTodo.isCompleted = false // Reset todos
                    newTodo.stop = newStop
                }
            }
        }

        // Clone bookings
        for sourceBooking in source.bookingsArray {
            let newBooking = BookingEntity.create(
                in: context,
                type: sourceBooking.bookingType,
                title: sourceBooking.wrappedTitle,
                confirmationCode: "",  // Don't copy confirmation codes
                notes: sourceBooking.wrappedNotes,
                sortOrder: Int(sourceBooking.sortOrder)
            )
            newBooking.airline = sourceBooking.airline
            newBooking.flightNumber = sourceBooking.flightNumber
            newBooking.departureAirport = sourceBooking.departureAirport
            newBooking.arrivalAirport = sourceBooking.arrivalAirport
            newBooking.hotelName = sourceBooking.hotelName
            newBooking.hotelAddress = sourceBooking.hotelAddress
            newBooking.trip = clone
        }

        // Clone lists with items
        for sourceList in source.listsArray {
            let newList = TripListEntity.create(in: context, name: sourceList.wrappedName, icon: sourceList.icon ?? "list.bullet")
            newList.sortOrder = sourceList.sortOrder
            newList.trip = clone
            for sourceItem in sourceList.itemsArray {
                let newItem = TripListItemEntity.create(in: context, text: sourceItem.wrappedText, sortOrder: Int(sourceItem.sortOrder))
                newItem.isChecked = false // Reset checklist items
                newItem.list = newList
            }
        }

        try? context.save()
        return clone
    }

    // MARK: - Completion Score

    /// Computes a trip readiness score from 0.0 to 1.0 based on planning completeness.
    /// Scoring criteria (equal weight):
    /// - Has at least one stop planned
    /// - Has at least one booking
    /// - Every day has at least one stop
    /// - Has budget set (budgetAmount > 0)
    /// - Has at least one list with items
    static func completionScore(for trip: TripEntity) -> Double {
        var earned = 0.0
        let totalCriteria = 5.0

        let days = trip.daysArray
        let stops = days.flatMap(\.stopsArray)

        // 1. Has at least one stop
        if !stops.isEmpty { earned += 1 }

        // 2. Has at least one booking
        if !trip.bookingsArray.isEmpty { earned += 1 }

        // 3. Every day has at least one stop
        if !days.isEmpty && days.allSatisfy({ !$0.stopsArray.isEmpty }) { earned += 1 }

        // 4. Has budget set
        if trip.budgetAmount > 0 { earned += 1 }

        // 5. Has at least one list with items
        if trip.listsArray.contains(where: { !$0.itemsArray.isEmpty }) { earned += 1 }

        return earned / totalCriteria
    }

    // MARK: - Conflict Detection

    /// Returns trips that overlap with the given date range, excluding `excludeTrip` if provided.
    func findConflictingTrips(startDate: Date, endDate: Date, excluding excludeTrip: TripEntity? = nil) -> [TripEntity] {
        let calendar = Calendar.current
        let newStart = calendar.startOfDay(for: startDate)
        let newEnd = calendar.startOfDay(for: endDate)

        return fetchTrips().filter { trip in
            if let excludeTrip, trip.objectID == excludeTrip.objectID { return false }
            guard let tripStart = trip.startDate, let tripEnd = trip.endDate else { return false }
            let existingStart = calendar.startOfDay(for: tripStart)
            let existingEnd = calendar.startOfDay(for: tripEnd)
            // Overlap: newStart <= existingEnd AND newEnd >= existingStart
            return newStart <= existingEnd && newEnd >= existingStart
        }
    }

    /// Checks if any existing trips conflict with the given range.
    func hasConflictingTrips(startDate: Date, endDate: Date, excluding excludeTrip: TripEntity? = nil) -> Bool {
        !findConflictingTrips(startDate: startDate, endDate: endDate, excluding: excludeTrip).isEmpty
    }

    // MARK: - CSV Export

    /// Generates CSV data for a trip's expenses.
    /// Columns: Title, Amount, Currency, Category, Date, Notes
    static func exportExpensesCSV(for trip: TripEntity) -> String {
        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .short
        dateFormatter.timeStyle = .none

        var lines: [String] = ["Title,Amount,Currency,Category,Date,Notes"]

        let expenses = trip.expensesArray
        for expense in expenses {
            let title = csvEscape(expense.wrappedTitle)
            let amount = String(format: "%.2f", expense.amount)
            let currency = csvEscape(expense.wrappedCurrencyCode)
            let category = csvEscape(expense.category.label)
            let dateStr = csvEscape(dateFormatter.string(from: expense.wrappedDateIncurred))
            let notes = csvEscape(expense.wrappedNotes)
            lines.append("\(title),\(amount),\(currency),\(category),\(dateStr),\(notes)")
        }

        // Summary row
        let total = expenses.reduce(0.0) { $0 + $1.amount }
        let currencyCode = trip.budgetCurrencyCode ?? "USD"
        lines.append("")
        lines.append("Total,\(String(format: "%.2f", total)),\(csvEscape(currencyCode)),,,")

        return lines.joined(separator: "\n")
    }

    private static func csvEscape(_ value: String) -> String {
        let needsQuoting = value.contains(",") || value.contains("\"") || value.contains("\n")
        if needsQuoting {
            return "\"\(value.replacingOccurrences(of: "\"", with: "\"\""))\""
        }
        return value
    }

    // MARK: - Trip Sorting

    enum TripSortOption: String, CaseIterable {
        case startDateDescending
        case startDateAscending
        case nameAscending
        case nameDescending
        case destinationAscending
        case destinationDescending
        case durationDescending
        case durationAscending
    }

    static func sortTrips(_ trips: [TripEntity], by option: TripSortOption) -> [TripEntity] {
        switch option {
        case .startDateDescending:
            return trips.sorted { ($0.startDate ?? .distantPast) > ($1.startDate ?? .distantPast) }
        case .startDateAscending:
            return trips.sorted { ($0.startDate ?? .distantPast) < ($1.startDate ?? .distantPast) }
        case .nameAscending:
            return trips.sorted { $0.wrappedName.localizedCaseInsensitiveCompare($1.wrappedName) == .orderedAscending }
        case .nameDescending:
            return trips.sorted { $0.wrappedName.localizedCaseInsensitiveCompare($1.wrappedName) == .orderedDescending }
        case .destinationAscending:
            return trips.sorted { $0.wrappedDestination.localizedCaseInsensitiveCompare($1.wrappedDestination) == .orderedAscending }
        case .destinationDescending:
            return trips.sorted { $0.wrappedDestination.localizedCaseInsensitiveCompare($1.wrappedDestination) == .orderedDescending }
        case .durationDescending:
            return trips.sorted { $0.durationInDays > $1.durationInDays }
        case .durationAscending:
            return trips.sorted { $0.durationInDays < $1.durationInDays }
        }
    }

    // MARK: - Trip Statistics

    struct TripStatistics: Equatable {
        var totalStops: Int
        var visitedStops: Int
        var totalDays: Int
        var daysWithStops: Int
        var emptyDays: Int
        var totalBookings: Int
        var totalExpenses: Double
        var budgetRemaining: Double?
        var categoryBreakdown: [StopCategory: Int]
        var averageStopsPerDay: Double
        var completionPercentage: Double  // stops visited / total stops
    }

    static func tripStatistics(for trip: TripEntity) -> TripStatistics {
        let days = trip.daysArray
        let allStops = days.flatMap(\.stopsArray)
        let visitedCount = allStops.filter(\.isVisited).count
        let daysWithStops = days.filter { !$0.stopsArray.isEmpty }.count
        let totalExpenseAmount = trip.expensesArray.reduce(0.0) { $0 + $1.amount }

        var categoryBreakdown: [StopCategory: Int] = [:]
        for stop in allStops {
            categoryBreakdown[stop.category, default: 0] += 1
        }

        let budgetRemaining: Double? = trip.budgetAmount > 0
            ? trip.budgetAmount - totalExpenseAmount
            : nil

        let avgStops = days.isEmpty ? 0 : Double(allStops.count) / Double(days.count)
        let completionPct = allStops.isEmpty ? 0 : Double(visitedCount) / Double(allStops.count)

        return TripStatistics(
            totalStops: allStops.count,
            visitedStops: visitedCount,
            totalDays: days.count,
            daysWithStops: daysWithStops,
            emptyDays: days.count - daysWithStops,
            totalBookings: trip.bookingsArray.count,
            totalExpenses: totalExpenseAmount,
            budgetRemaining: budgetRemaining,
            categoryBreakdown: categoryBreakdown,
            averageStopsPerDay: avgStops,
            completionPercentage: completionPct
        )
    }

    // MARK: - Search & Filter

    /// Filter stops within a trip by search query and/or category.
    /// Empty query matches all stops. nil category matches all categories.
    static func filterStops(
        in trip: TripEntity,
        query: String = "",
        category: StopCategory? = nil
    ) -> [StopEntity] {
        let allStops = trip.daysArray
            .sorted { $0.dayNumber < $1.dayNumber }
            .flatMap(\.stopsArray)

        let trimmedQuery = query.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()

        return allStops.filter { stop in
            // Category filter
            if let category, stop.category != category { return false }

            // Text search (name, notes, address)
            if !trimmedQuery.isEmpty {
                let nameMatch = stop.wrappedName.lowercased().contains(trimmedQuery)
                let notesMatch = stop.wrappedNotes.lowercased().contains(trimmedQuery)
                let addressMatch = (stop.address ?? "").lowercased().contains(trimmedQuery)
                if !nameMatch && !notesMatch && !addressMatch { return false }
            }

            return true
        }
    }

    // MARK: - Reminder Computation

    struct TripReminder: Equatable {
        enum ReminderType: String, Equatable {
            case tripStarting
            case flightDeparture
            case hotelCheckIn
            case hotelCheckOut
        }

        var type: ReminderType
        var title: String
        var body: String
        var fireDate: Date
    }

    /// Computes reminders for a trip based on its bookings and dates.
    /// Returns reminders sorted by fireDate. Only returns future reminders
    /// relative to the given `now` parameter.
    static func computeReminders(for trip: TripEntity, now: Date = Date()) -> [TripReminder] {
        var reminders: [TripReminder] = []
        let calendar = Calendar.current

        // Trip starting reminder (day before at 9 AM)
        if let startDate = trip.startDate {
            let dayBefore = calendar.date(byAdding: .day, value: -1, to: calendar.startOfDay(for: startDate))!
            var comps = calendar.dateComponents([.year, .month, .day], from: dayBefore)
            comps.hour = 9
            if let fireDate = calendar.date(from: comps), fireDate > now {
                reminders.append(TripReminder(
                    type: .tripStarting,
                    title: "Trip tomorrow!",
                    body: "\(trip.wrappedName) to \(trip.wrappedDestination) starts tomorrow",
                    fireDate: fireDate
                ))
            }
        }

        // Booking-based reminders
        for booking in trip.bookingsArray {
            switch booking.bookingType {
            case .flight:
                if let depTime = booking.departureTime, depTime > now {
                    // 3 hours before flight
                    let fireDate = calendar.date(byAdding: .hour, value: -3, to: depTime)!
                    reminders.append(TripReminder(
                        type: .flightDeparture,
                        title: "Flight reminder",
                        body: "\(booking.wrappedTitle) departs in 3 hours",
                        fireDate: fireDate
                    ))
                }

            case .hotel:
                if let checkIn = booking.checkInDate {
                    // Check-in reminder at 2 PM on check-in day
                    var comps = calendar.dateComponents([.year, .month, .day], from: checkIn)
                    comps.hour = 14
                    if let fireDate = calendar.date(from: comps), fireDate > now {
                        reminders.append(TripReminder(
                            type: .hotelCheckIn,
                            title: "Hotel check-in",
                            body: "Check in to \(booking.hotelName ?? booking.wrappedTitle)",
                            fireDate: fireDate
                        ))
                    }
                }
                if let checkOut = booking.checkOutDate {
                    // Check-out reminder at 9 AM on check-out day
                    var comps = calendar.dateComponents([.year, .month, .day], from: checkOut)
                    comps.hour = 9
                    if let fireDate = calendar.date(from: comps), fireDate > now {
                        reminders.append(TripReminder(
                            type: .hotelCheckOut,
                            title: "Hotel check-out",
                            body: "Check out of \(booking.hotelName ?? booking.wrappedTitle)",
                            fireDate: fireDate
                        ))
                    }
                }

            default:
                break
            }
        }

        return reminders.sorted { $0.fireDate < $1.fireDate }
    }

    // MARK: - Sample Data

    func loadSampleDataIfEmpty() {
        let request = TripEntity.fetchRequest() as! NSFetchRequest<TripEntity>
        let count = (try? context.count(for: request)) ?? 0
        guard count == 0 else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        func daysFromNow(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }

        // Paris Getaway — active trip
        let paris = TripEntity.create(
            in: context,
            name: "Paris Getaway",
            destination: "Paris, France",
            startDate: daysFromNow(-1),
            endDate: daysFromNow(3),
            status: .active,
            notes: "A romantic few days exploring the City of Light"
        )
        generateDays(for: paris)

        if let parisDay1 = paris.daysArray.first(where: { $0.dayNumber == 1 }) {
            parisDay1.notes = "Explore the city center"
            addStop(to: parisDay1, name: "Eiffel Tower", latitude: 48.8584, longitude: 2.2945, category: .attraction)
            addStop(to: parisDay1, name: "Le Jules Verne", latitude: 48.8583, longitude: 2.2944, category: .restaurant)
        }

        if let parisDay2 = paris.daysArray.first(where: { $0.dayNumber == 2 }) {
            parisDay2.notes = "Art and culture"
            addStop(to: parisDay2, name: "Louvre Museum", latitude: 48.8606, longitude: 2.3376, category: .attraction)
            addStop(to: parisDay2, name: "Café de Flore", latitude: 48.8540, longitude: 2.3325, category: .restaurant)
        }

        let parisHotel = BookingEntity.create(in: context, type: .hotel, title: "Hôtel Le Marais", confirmationCode: "HLM-28491")
        parisHotel.hotelName = "Hôtel Le Marais"
        parisHotel.hotelAddress = "12 Rue des Archives, 75004 Paris"
        parisHotel.checkInDate = daysFromNow(-1)
        parisHotel.checkOutDate = daysFromNow(3)
        parisHotel.trip = paris

        // Japan Adventure — upcoming trip
        let japan = TripEntity.create(
            in: context,
            name: "Japan Adventure",
            destination: "Japan",
            startDate: daysFromNow(30),
            endDate: daysFromNow(37),
            status: .planning,
            notes: "Cherry blossom season trip — Tokyo & Kyoto"
        )
        generateDays(for: japan)

        for day in japan.daysArray {
            if day.dayNumber <= 4 {
                day.location = "Tokyo, Japan"
            } else {
                day.location = "Kyoto, Japan"
            }
        }

        if let day1 = japan.daysArray.first(where: { $0.dayNumber == 1 }) {
            day1.notes = "Arrival day"
            addStop(to: day1, name: "Narita Airport", latitude: 35.7720, longitude: 140.3929, category: .transport)
            addStop(to: day1, name: "Shinjuku Hotel", latitude: 35.6938, longitude: 139.7034, category: .accommodation)
        }

        if let day2 = japan.daysArray.first(where: { $0.dayNumber == 2 }) {
            day2.notes = "Temple and garden visits"
            addStop(to: day2, name: "Senso-ji Temple", latitude: 35.7148, longitude: 139.7967, category: .attraction)
            addStop(to: day2, name: "Tsukiji Outer Market", latitude: 35.6654, longitude: 139.7707, category: .restaurant)
        }

        if let day5 = japan.daysArray.first(where: { $0.dayNumber == 5 }) {
            day5.notes = "Train to Kyoto, explore temples"
            addStop(to: day5, name: "Shinkansen to Kyoto", latitude: 35.6812, longitude: 139.7671, category: .transport)
            addStop(to: day5, name: "Fushimi Inari Shrine", latitude: 34.9671, longitude: 135.7727, category: .attraction)
        }

        // NYC Weekend — completed trip
        let nyc = TripEntity.create(
            in: context,
            name: "New York City Weekend",
            destination: "New York, USA",
            startDate: daysFromNow(-18),
            endDate: daysFromNow(-14),
            status: .completed,
            notes: "Holiday shopping and sightseeing"
        )
        generateDays(for: nyc)

        try? context.save()
    }
}
