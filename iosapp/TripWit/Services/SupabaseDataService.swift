import Foundation
import CoreData
import Supabase
import TripCore

// MARK: - Protocol for test injection

protocol SupabaseDataServiceProtocol: Sendable {
    func fetchAllTrips(userId: String) async throws -> [SupabaseTripRow]
    func upsertTrip(_ row: SupabaseTripRow) async throws
    func deleteTrip(id: String) async throws
    func deleteAllTrips(userId: String) async throws
}

// MARK: - Supabase Data Service

actor SupabaseDataService: SupabaseDataServiceProtocol {

    private let client: SupabaseClient

    init(client: SupabaseClient) {
        self.client = client
    }

    func fetchAllTrips(userId: String) async throws -> [SupabaseTripRow] {
        try await client.from("trips")
            .select()
            .eq("user_id", value: userId)
            .order("updated_at", ascending: false)
            .execute()
            .value
    }

    func upsertTrip(_ row: SupabaseTripRow) async throws {
        try await client.from("trips")
            .upsert(row)
            .execute()
    }

    func deleteTrip(id: String) async throws {
        try await client.from("trips")
            .delete()
            .eq("id", value: id)
            .execute()
    }

    func deleteAllTrips(userId: String) async throws {
        try await client.from("trips")
            .delete()
            .eq("user_id", value: userId)
            .execute()
    }
}

// MARK: - Supabase Row Types (match web/lib/types.ts exactly)

struct SupabaseTripRow: Codable, Sendable {
    let id: String
    let userId: String
    var isPublic: Bool
    var name: String
    var destination: String
    var statusRaw: String
    var notes: String
    var hasCustomDates: Bool
    var budgetAmount: Double
    var budgetCurrencyCode: String
    var startDate: String
    var endDate: String
    var days: [SupabaseDayJSON]
    var bookings: [SupabaseBookingJSON]
    var lists: [SupabaseListJSON]
    var expenses: [SupabaseExpenseJSON]
    var createdAt: String
    var updatedAt: String

    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case isPublic = "is_public"
        case name, destination
        case statusRaw = "status_raw"
        case notes
        case hasCustomDates = "has_custom_dates"
        case budgetAmount = "budget_amount"
        case budgetCurrencyCode = "budget_currency_code"
        case startDate = "start_date"
        case endDate = "end_date"
        case days, bookings, lists, expenses
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
}

struct SupabaseDayJSON: Codable, Sendable {
    var id: String
    var dayNumber: Int
    var date: String
    var notes: String
    var location: String
    var locationLatitude: Double
    var locationLongitude: Double
    var stops: [SupabaseStopJSON]
}

struct SupabaseStopJSON: Codable, Sendable {
    var id: String
    var name: String
    var categoryRaw: String
    var sortOrder: Int
    var notes: String
    var latitude: Double
    var longitude: Double
    var address: String?
    var phone: String?
    var website: String?
    var arrivalTime: String?
    var departureTime: String?
    var isVisited: Bool
    var visitedAt: String?
    var rating: Int
    var confirmationCode: String?
    var checkOutDate: String?
    var airline: String?
    var flightNumber: String?
    var departureAirport: String?
    var arrivalAirport: String?
    var todos: [SupabaseTodoJSON]
    var links: [SupabaseLinkJSON]
    var comments: [SupabaseCommentJSON]
}

struct SupabaseTodoJSON: Codable, Sendable {
    var id: String
    var text: String
    var isCompleted: Bool
    var sortOrder: Int
}

struct SupabaseLinkJSON: Codable, Sendable {
    var id: String
    var title: String
    var url: String
    var sortOrder: Int
}

struct SupabaseCommentJSON: Codable, Sendable {
    var id: String
    var text: String
    var createdAt: String
}

struct SupabaseBookingJSON: Codable, Sendable {
    var id: String
    var typeRaw: String
    var title: String
    var confirmationCode: String
    var notes: String
    var sortOrder: Int
    var airline: String?
    var flightNumber: String?
    var departureAirport: String?
    var arrivalAirport: String?
    var departureTime: String?
    var arrivalTime: String?
    var hotelName: String?
    var hotelAddress: String?
    var checkInDate: String?
    var checkOutDate: String?
}

struct SupabaseListJSON: Codable, Sendable {
    var id: String
    var name: String
    var icon: String
    var sortOrder: Int
    var items: [SupabaseListItemJSON]
}

struct SupabaseListItemJSON: Codable, Sendable {
    var id: String
    var text: String
    var isChecked: Bool
    var sortOrder: Int
}

struct SupabaseExpenseJSON: Codable, Sendable {
    var id: String
    var title: String
    var amount: Double
    var currencyCode: String
    var categoryRaw: String
    var notes: String
    var sortOrder: Int
    var createdAt: String
    var dateIncurred: String
}

// MARK: - Core Data Entity → Supabase Row

extension SupabaseDataService {

    private static let iso = ISO8601DateFormatter()
    /// Parses full ISO 8601 strings AND date-only strings (YYYY-MM-DD) written
    /// by the web app's <input type="date"> which omits the time component.
    private static func parseDate(_ str: String) -> Date? {
        if let d = iso.date(from: str) { return d }
        // Fallback: date-only (YYYY-MM-DD) — treat as midnight UTC
        let dateOnly = ISO8601DateFormatter()
        dateOnly.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return dateOnly.date(from: str)
    }

    static func tripEntityToRow(_ trip: TripEntity, userId: String) -> SupabaseTripRow {
        let now = iso.string(from: Date())
        // Always use lowercase IDs so iOS-created trips are compatible with
        // web-created trips (crypto.randomUUID() is lowercase). This ensures
        // the Supabase TEXT primary key matches regardless of which platform
        // created the trip, preventing duplicate rows on upsert.
        return SupabaseTripRow(
            id: trip.id?.uuidString.lowercased() ?? UUID().uuidString.lowercased(),
            userId: userId,
            isPublic: trip.isPublic,
            name: trip.wrappedName,
            destination: trip.wrappedDestination,
            statusRaw: trip.wrappedStatusRaw,
            notes: trip.wrappedNotes,
            hasCustomDates: trip.hasCustomDates,
            budgetAmount: trip.budgetAmount,
            budgetCurrencyCode: trip.wrappedBudgetCurrencyCode,
            startDate: iso.string(from: trip.wrappedStartDate),
            endDate: iso.string(from: trip.wrappedEndDate),
            days: trip.daysArray.map { day in
                SupabaseDayJSON(
                    id: day.id?.uuidString ?? UUID().uuidString,
                    dayNumber: Int(day.dayNumber),
                    date: iso.string(from: day.wrappedDate),
                    notes: day.wrappedNotes,
                    location: day.wrappedLocation,
                    locationLatitude: day.locationLatitude,
                    locationLongitude: day.locationLongitude,
                    stops: day.stopsArray.map { stop in
                        SupabaseStopJSON(
                            id: stop.id?.uuidString ?? UUID().uuidString,
                            name: stop.wrappedName,
                            categoryRaw: stop.wrappedCategoryRaw,
                            sortOrder: Int(stop.sortOrder),
                            notes: stop.wrappedNotes,
                            latitude: stop.latitude,
                            longitude: stop.longitude,
                            address: stop.address,
                            phone: stop.phone,
                            website: stop.website,
                            arrivalTime: stop.arrivalTime.map { iso.string(from: $0) },
                            departureTime: stop.departureTime.map { iso.string(from: $0) },
                            isVisited: stop.isVisited,
                            visitedAt: stop.visitedAt.map { iso.string(from: $0) },
                            rating: Int(stop.rating),
                            confirmationCode: stop.confirmationCode,
                            checkOutDate: stop.checkOutDate.map { iso.string(from: $0) },
                            airline: stop.airline,
                            flightNumber: stop.flightNumber,
                            departureAirport: stop.departureAirport,
                            arrivalAirport: stop.arrivalAirport,
                            todos: stop.todosArray.map { t in
                                SupabaseTodoJSON(
                                    id: t.id?.uuidString ?? UUID().uuidString,
                                    text: t.wrappedText,
                                    isCompleted: t.isCompleted,
                                    sortOrder: Int(t.sortOrder)
                                )
                            },
                            links: stop.linksArray.map { l in
                                SupabaseLinkJSON(
                                    id: l.id?.uuidString ?? UUID().uuidString,
                                    title: l.wrappedTitle,
                                    url: l.wrappedURL,
                                    sortOrder: Int(l.sortOrder)
                                )
                            },
                            comments: stop.commentsArray.map { c in
                                SupabaseCommentJSON(
                                    id: c.id?.uuidString ?? UUID().uuidString,
                                    text: c.wrappedText,
                                    createdAt: iso.string(from: c.wrappedCreatedAt)
                                )
                            }
                        )
                    }
                )
            },
            bookings: trip.bookingsArray.map { b in
                SupabaseBookingJSON(
                    id: b.id?.uuidString ?? UUID().uuidString,
                    typeRaw: b.wrappedTypeRaw,
                    title: b.wrappedTitle,
                    confirmationCode: b.wrappedConfirmationCode,
                    notes: b.wrappedNotes,
                    sortOrder: Int(b.sortOrder),
                    airline: b.airline,
                    flightNumber: b.flightNumber,
                    departureAirport: b.departureAirport,
                    arrivalAirport: b.arrivalAirport,
                    departureTime: b.departureTime.map { iso.string(from: $0) },
                    arrivalTime: b.arrivalTime.map { iso.string(from: $0) },
                    hotelName: b.hotelName,
                    hotelAddress: b.hotelAddress,
                    checkInDate: b.checkInDate.map { iso.string(from: $0) },
                    checkOutDate: b.checkOutDate.map { iso.string(from: $0) }
                )
            },
            lists: trip.listsArray.map { list in
                SupabaseListJSON(
                    id: list.id?.uuidString ?? UUID().uuidString,
                    name: list.wrappedName,
                    icon: list.wrappedIcon,
                    sortOrder: Int(list.sortOrder),
                    items: list.itemsArray.map { item in
                        SupabaseListItemJSON(
                            id: item.id?.uuidString ?? UUID().uuidString,
                            text: item.wrappedText,
                            isChecked: item.isChecked,
                            sortOrder: Int(item.sortOrder)
                        )
                    }
                )
            },
            expenses: trip.expensesArray.map { e in
                SupabaseExpenseJSON(
                    id: e.id?.uuidString ?? UUID().uuidString,
                    title: e.wrappedTitle,
                    amount: e.amount,
                    currencyCode: e.wrappedCurrencyCode,
                    categoryRaw: e.wrappedCategoryRaw,
                    notes: e.wrappedNotes,
                    sortOrder: Int(e.sortOrder),
                    createdAt: iso.string(from: e.wrappedCreatedAt),
                    dateIncurred: iso.string(from: e.wrappedDateIncurred)
                )
            },
            createdAt: iso.string(from: trip.wrappedCreatedAt),
            updatedAt: trip.updatedAt.map { iso.string(from: $0) } ?? now
        )
    }

    // MARK: - Supabase Row → Core Data Entity (new import)

    @MainActor
    static func importRow(_ row: SupabaseTripRow, into context: NSManagedObjectContext) -> TripEntity {
        let trip = TripEntity.create(
            in: context,
            name: row.name,
            destination: row.destination,
            startDate: parseDate(row.startDate) ?? Date(),
            endDate: parseDate(row.endDate) ?? Date(),
            notes: row.notes
        )
        // Set the UUID to match the Supabase row ID
        trip.id = UUID(uuidString: row.id) ?? UUID()
        trip.statusRaw = row.statusRaw
        trip.hasCustomDates = row.hasCustomDates
        trip.budgetAmount = row.budgetAmount
        trip.budgetCurrencyCode = row.budgetCurrencyCode
        trip.isPublic = row.isPublic
        trip.createdAt = iso.date(from: row.createdAt)
        trip.updatedAt = iso.date(from: row.updatedAt)
        trip.supabaseSyncedAt = Date()

        for dayJ in row.days {
            let day = DayEntity.create(
                in: context,
                date: parseDate(dayJ.date) ?? Date(),
                dayNumber: dayJ.dayNumber,
                notes: dayJ.notes,
                location: dayJ.location,
                locationLatitude: dayJ.locationLatitude,
                locationLongitude: dayJ.locationLongitude
            )
            day.id = UUID(uuidString: dayJ.id) ?? UUID()
            day.trip = trip

            for stopJ in dayJ.stops {
                let stop = StopEntity.create(
                    in: context,
                    name: stopJ.name,
                    latitude: stopJ.latitude,
                    longitude: stopJ.longitude,
                    category: StopCategory(rawValue: stopJ.categoryRaw) ?? .other,
                    arrivalTime: stopJ.arrivalTime.flatMap { iso.date(from: $0) },
                    departureTime: stopJ.departureTime.flatMap { iso.date(from: $0) },
                    sortOrder: stopJ.sortOrder,
                    notes: stopJ.notes,
                    isVisited: stopJ.isVisited,
                    visitedAt: stopJ.visitedAt.flatMap { iso.date(from: $0) },
                    address: stopJ.address,
                    phone: stopJ.phone,
                    website: stopJ.website
                )
                stop.id = UUID(uuidString: stopJ.id) ?? UUID()
                stop.rating = Int32(stopJ.rating)
                stop.confirmationCode = stopJ.confirmationCode
                stop.checkOutDate = stopJ.checkOutDate.flatMap { iso.date(from: $0) }
                stop.airline = stopJ.airline
                stop.flightNumber = stopJ.flightNumber
                stop.departureAirport = stopJ.departureAirport
                stop.arrivalAirport = stopJ.arrivalAirport
                stop.day = day

                for todoJ in stopJ.todos {
                    let todo = StopTodoEntity.create(in: context, text: todoJ.text, sortOrder: todoJ.sortOrder)
                    todo.id = UUID(uuidString: todoJ.id) ?? UUID()
                    todo.isCompleted = todoJ.isCompleted
                    todo.stop = stop
                }

                for linkJ in stopJ.links {
                    let link = StopLinkEntity.create(in: context, title: linkJ.title, url: linkJ.url, sortOrder: linkJ.sortOrder)
                    link.id = UUID(uuidString: linkJ.id) ?? UUID()
                    link.stop = stop
                }

                for commentJ in stopJ.comments {
                    let comment = CommentEntity.create(in: context, text: commentJ.text)
                    comment.id = UUID(uuidString: commentJ.id) ?? UUID()
                    comment.createdAt = iso.date(from: commentJ.createdAt)
                    comment.stop = stop
                }
            }
        }

        for bkJ in row.bookings {
            let booking = BookingEntity.create(
                in: context,
                type: BookingType(rawValue: bkJ.typeRaw) ?? .other,
                title: bkJ.title,
                confirmationCode: bkJ.confirmationCode,
                notes: bkJ.notes,
                sortOrder: bkJ.sortOrder
            )
            booking.id = UUID(uuidString: bkJ.id) ?? UUID()
            booking.airline = bkJ.airline
            booking.flightNumber = bkJ.flightNumber
            booking.departureAirport = bkJ.departureAirport
            booking.arrivalAirport = bkJ.arrivalAirport
            booking.departureTime = bkJ.departureTime.flatMap { iso.date(from: $0) }
            booking.arrivalTime = bkJ.arrivalTime.flatMap { iso.date(from: $0) }
            booking.hotelName = bkJ.hotelName
            booking.hotelAddress = bkJ.hotelAddress
            booking.checkInDate = bkJ.checkInDate.flatMap { iso.date(from: $0) }
            booking.checkOutDate = bkJ.checkOutDate.flatMap { iso.date(from: $0) }
            booking.trip = trip
        }

        for listJ in row.lists {
            let list = TripListEntity.create(in: context, name: listJ.name, icon: listJ.icon, sortOrder: listJ.sortOrder)
            list.id = UUID(uuidString: listJ.id) ?? UUID()
            list.trip = trip

            for itemJ in listJ.items {
                let item = TripListItemEntity.create(in: context, text: itemJ.text, sortOrder: itemJ.sortOrder)
                item.id = UUID(uuidString: itemJ.id) ?? UUID()
                item.isChecked = itemJ.isChecked
                item.list = list
            }
        }

        for expJ in row.expenses {
            let expense = ExpenseEntity.create(
                in: context,
                title: expJ.title,
                amount: expJ.amount,
                currencyCode: expJ.currencyCode,
                dateIncurred: iso.date(from: expJ.dateIncurred) ?? Date(),
                category: ExpenseCategory(rawValue: expJ.categoryRaw) ?? .other,
                notes: expJ.notes,
                sortOrder: expJ.sortOrder
            )
            expense.id = UUID(uuidString: expJ.id) ?? UUID()
            expense.createdAt = iso.date(from: expJ.createdAt)
            expense.trip = trip
        }

        return trip
    }

    // MARK: - Update existing entity from newer remote row

    @MainActor
    static func updateEntity(_ trip: TripEntity, from row: SupabaseTripRow, in context: NSManagedObjectContext) {
        // Delete all existing children (whole-trip replacement)
        for day in trip.daysArray {
            context.delete(day)
        }
        for booking in trip.bookingsArray {
            context.delete(booking)
        }
        for list in trip.listsArray {
            context.delete(list)
        }
        for expense in trip.expensesArray {
            context.delete(expense)
        }

        // Update scalar fields
        trip.name = row.name
        trip.destination = row.destination
        trip.statusRaw = row.statusRaw
        trip.notes = row.notes
        trip.hasCustomDates = row.hasCustomDates
        trip.budgetAmount = row.budgetAmount
        trip.budgetCurrencyCode = row.budgetCurrencyCode
        trip.startDate = parseDate(row.startDate)
        trip.endDate = parseDate(row.endDate)
        trip.isPublic = row.isPublic
        trip.updatedAt = iso.date(from: row.updatedAt)
        trip.supabaseSyncedAt = Date()

        // Recreate children from row data
        for dayJ in row.days {
            let day = DayEntity.create(
                in: context,
                date: parseDate(dayJ.date) ?? Date(),
                dayNumber: dayJ.dayNumber,
                notes: dayJ.notes,
                location: dayJ.location,
                locationLatitude: dayJ.locationLatitude,
                locationLongitude: dayJ.locationLongitude
            )
            day.id = UUID(uuidString: dayJ.id) ?? UUID()
            day.trip = trip

            for stopJ in dayJ.stops {
                let stop = StopEntity.create(
                    in: context,
                    name: stopJ.name,
                    latitude: stopJ.latitude,
                    longitude: stopJ.longitude,
                    category: StopCategory(rawValue: stopJ.categoryRaw) ?? .other,
                    arrivalTime: stopJ.arrivalTime.flatMap { iso.date(from: $0) },
                    departureTime: stopJ.departureTime.flatMap { iso.date(from: $0) },
                    sortOrder: stopJ.sortOrder,
                    notes: stopJ.notes,
                    isVisited: stopJ.isVisited,
                    visitedAt: stopJ.visitedAt.flatMap { iso.date(from: $0) },
                    address: stopJ.address,
                    phone: stopJ.phone,
                    website: stopJ.website
                )
                stop.id = UUID(uuidString: stopJ.id) ?? UUID()
                stop.rating = Int32(stopJ.rating)
                stop.confirmationCode = stopJ.confirmationCode
                stop.checkOutDate = stopJ.checkOutDate.flatMap { iso.date(from: $0) }
                stop.airline = stopJ.airline
                stop.flightNumber = stopJ.flightNumber
                stop.departureAirport = stopJ.departureAirport
                stop.arrivalAirport = stopJ.arrivalAirport
                stop.day = day

                for todoJ in stopJ.todos {
                    let todo = StopTodoEntity.create(in: context, text: todoJ.text, sortOrder: todoJ.sortOrder)
                    todo.id = UUID(uuidString: todoJ.id) ?? UUID()
                    todo.isCompleted = todoJ.isCompleted
                    todo.stop = stop
                }

                for linkJ in stopJ.links {
                    let link = StopLinkEntity.create(in: context, title: linkJ.title, url: linkJ.url, sortOrder: linkJ.sortOrder)
                    link.id = UUID(uuidString: linkJ.id) ?? UUID()
                    link.stop = stop
                }

                for commentJ in stopJ.comments {
                    let comment = CommentEntity.create(in: context, text: commentJ.text)
                    comment.id = UUID(uuidString: commentJ.id) ?? UUID()
                    comment.createdAt = iso.date(from: commentJ.createdAt)
                    comment.stop = stop
                }
            }
        }

        for bkJ in row.bookings {
            let booking = BookingEntity.create(
                in: context,
                type: BookingType(rawValue: bkJ.typeRaw) ?? .other,
                title: bkJ.title,
                confirmationCode: bkJ.confirmationCode,
                notes: bkJ.notes,
                sortOrder: bkJ.sortOrder
            )
            booking.id = UUID(uuidString: bkJ.id) ?? UUID()
            booking.airline = bkJ.airline
            booking.flightNumber = bkJ.flightNumber
            booking.departureAirport = bkJ.departureAirport
            booking.arrivalAirport = bkJ.arrivalAirport
            booking.departureTime = bkJ.departureTime.flatMap { iso.date(from: $0) }
            booking.arrivalTime = bkJ.arrivalTime.flatMap { iso.date(from: $0) }
            booking.hotelName = bkJ.hotelName
            booking.hotelAddress = bkJ.hotelAddress
            booking.checkInDate = bkJ.checkInDate.flatMap { iso.date(from: $0) }
            booking.checkOutDate = bkJ.checkOutDate.flatMap { iso.date(from: $0) }
            booking.trip = trip
        }

        for listJ in row.lists {
            let list = TripListEntity.create(in: context, name: listJ.name, icon: listJ.icon, sortOrder: listJ.sortOrder)
            list.id = UUID(uuidString: listJ.id) ?? UUID()
            list.trip = trip

            for itemJ in listJ.items {
                let item = TripListItemEntity.create(in: context, text: itemJ.text, sortOrder: itemJ.sortOrder)
                item.id = UUID(uuidString: itemJ.id) ?? UUID()
                item.isChecked = itemJ.isChecked
                item.list = list
            }
        }

        for expJ in row.expenses {
            let expense = ExpenseEntity.create(
                in: context,
                title: expJ.title,
                amount: expJ.amount,
                currencyCode: expJ.currencyCode,
                dateIncurred: iso.date(from: expJ.dateIncurred) ?? Date(),
                category: ExpenseCategory(rawValue: expJ.categoryRaw) ?? .other,
                notes: expJ.notes,
                sortOrder: expJ.sortOrder
            )
            expense.id = UUID(uuidString: expJ.id) ?? UUID()
            expense.createdAt = iso.date(from: expJ.createdAt)
            expense.trip = trip
        }
    }
}
