import Testing
import CoreData
import Foundation
import TripCore

@testable import TripWit

// MARK: - Helpers

/// Keeps containers alive for the duration of the test process.
/// In-memory stores don't checkpoint on dealloc (unlike /dev/null SQLite),
/// so accumulating them here is safe — no crash on process exit.
private var _liveContainers: [NSPersistentContainer] = []

/// Creates an in-memory Core Data context for testing.
/// Uses NSInMemoryStoreType to avoid SQLite checkpoint crashes.
private func makeTestContext() -> NSManagedObjectContext {
    let container = NSPersistentContainer(name: "TripWit")
    let desc = NSPersistentStoreDescription()
    desc.type = NSInMemoryStoreType
    container.persistentStoreDescriptions = [desc]
    container.loadPersistentStores { _, error in
        if let error { fatalError("Test store failed: \(error)") }
    }
    container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    _liveContainers.append(container)
    return container.viewContext
}

private let calendar = Calendar.current

private func date(_ year: Int, _ month: Int, _ day: Int) -> Date {
    calendar.date(from: DateComponents(year: year, month: month, day: day))!
}

/// Creates a trip with generated days and returns (trip, sortedDays).
private func makeTripWithDays(
    in context: NSManagedObjectContext,
    name: String = "Test Trip",
    start: Date,
    end: Date
) -> (TripEntity, [DayEntity]) {
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: name, destination: "Test", startDate: start, endDate: end)
    let days = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }
    return (trip, days)
}

// MARK: - Test Suite (serialized to avoid Core Data container conflicts)

@Suite(.serialized) struct TripWitTests {

@Test func tripEntityCanBeCreated() {
    let context = makeTestContext()
    let trip = TripEntity.create(
        in: context,
        name: "Test Trip",
        destination: "Test City",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 3),
        status: .planning,
        notes: "Test notes"
    )
    #expect(trip.wrappedName == "Test Trip")
    #expect(trip.destination == "Test City")
    #expect(trip.status == .planning)
    #expect(trip.notes == "Test notes")
}

@Test func tripEntityComputedProperties() {
    let context = makeTestContext()
    let start = date(2026, 6, 1)
    let end = date(2026, 6, 5)

    let trip = TripEntity.create(
        in: context,
        name: "Duration Test",
        destination: "Somewhere",
        startDate: start,
        endDate: end
    )
    #expect(trip.durationInDays == 5)
}

@Test func stopEntityCategoryRoundTrips() {
    let context = makeTestContext()
    let stop = StopEntity.create(
        in: context,
        name: "Test Stop",
        latitude: 35.6762,
        longitude: 139.6503,
        category: .restaurant,
        sortOrder: 0
    )
    #expect(stop.category == .restaurant)
    #expect(stop.categoryRaw == "restaurant")

    stop.category = .attraction
    #expect(stop.categoryRaw == "attraction")
}

@Test func dayEntityFormattedDate() {
    let context = makeTestContext()
    let d = date(2026, 3, 15)
    let day = DayEntity.create(in: context, date: d, dayNumber: 1)
    #expect(!day.formattedDate.isEmpty)
    #expect(day.dayNumber == 1)
}

@Test func stopEntityVisitedDefaults() {
    let context = makeTestContext()
    let stop = StopEntity.create(
        in: context,
        name: "Visit Test",
        latitude: 40.7128,
        longitude: -74.0060,
        category: .attraction,
        sortOrder: 0
    )
    #expect(stop.isVisited == false)
    #expect(stop.visitedAt == nil)
}

@Test func stopEntityVisitedToggle() {
    let context = makeTestContext()
    let stop = StopEntity.create(
        in: context,
        name: "Toggle Test",
        latitude: 48.8566,
        longitude: 2.3522,
        category: .restaurant,
        sortOrder: 0
    )
    stop.isVisited = true
    stop.visitedAt = Date()
    #expect(stop.isVisited == true)
    #expect(stop.visitedAt != nil)

    stop.isVisited = false
    stop.visitedAt = nil
    #expect(stop.isVisited == false)
    #expect(stop.visitedAt == nil)
}

@Test func stopEntityVisitedInit() {
    let context = makeTestContext()
    let now = Date()
    let stop = StopEntity.create(
        in: context,
        name: "Pre-visited",
        latitude: 51.5074,
        longitude: -0.1278,
        category: .accommodation,
        sortOrder: 0,
        isVisited: true,
        visitedAt: now
    )
    #expect(stop.isVisited == true)
    #expect(stop.visitedAt == now)
}

@Test func tripStatusConversion() {
    let context = makeTestContext()
    let trip = TripEntity.create(
        in: context,
        name: "Status Test",
        destination: "Nowhere",
        startDate: Date(),
        endDate: Date()
    )
    #expect(trip.status == .planning)
    #expect(trip.statusRaw == "planning")

    trip.status = .active
    #expect(trip.statusRaw == "active")

    trip.status = .completed
    #expect(trip.statusRaw == "completed")
}

// MARK: - 1. TripTransfer Encode/Decode

@Test func transferEncodeDecodeRoundTrip() throws {
    let now = Date()
    let transfer = TripTransfer(
        schemaVersion: 1,
        name: "Paris Trip",
        destination: "Paris, France",
        startDate: now,
        endDate: now.addingTimeInterval(86400 * 5),
        statusRaw: "active",
        notes: "A lovely trip",
        hasCustomDates: true,
        budgetAmount: 2500.50,
        budgetCurrencyCode: "EUR",
        days: [
            DayTransfer(
                date: now,
                dayNumber: 1,
                notes: "Arrival day",
                location: "Paris",
                locationLatitude: 48.8566,
                locationLongitude: 2.3522,
                stops: [
                    StopTransfer(
                        name: "Eiffel Tower",
                        latitude: 48.8584,
                        longitude: 2.2945,
                        arrivalTime: now,
                        departureTime: now.addingTimeInterval(3600),
                        categoryRaw: "attraction",
                        notes: "Book tickets",
                        sortOrder: 0,
                        isVisited: true,
                        visitedAt: now,
                        rating: 5,
                        address: "Champ de Mars",
                        phone: "+33123456789",
                        website: "https://example.com",
                        comments: [CommentTransfer(text: "Amazing view!", createdAt: now)],
                        links: [StopLinkTransfer(title: "Tickets", url: "https://tickets.example.com", sortOrder: 0)],
                        todos: [StopTodoTransfer(text: "Buy tickets", isCompleted: true, sortOrder: 0)]
                    )
                ]
            )
        ],
        bookings: [
            BookingTransfer(
                typeRaw: "flight",
                title: "Air France 123",
                confirmationCode: "AF-789",
                notes: "Window seat",
                sortOrder: 0,
                airline: "Air France",
                flightNumber: "AF123",
                departureAirport: "JFK",
                arrivalAirport: "CDG",
                departureTime: now,
                arrivalTime: now.addingTimeInterval(28800)
            )
        ],
        lists: [
            ListTransfer(
                name: "Packing",
                icon: "suitcase.fill",
                sortOrder: 0,
                items: [ListItemTransfer(text: "Passport", isChecked: true, sortOrder: 0)]
            )
        ],
        expenses: [
            ExpenseTransfer(
                title: "Dinner",
                amount: 85.50,
                currencyCode: "EUR",
                dateIncurred: now,
                categoryRaw: "food",
                notes: "Le Jules Verne",
                sortOrder: 0,
                createdAt: now
            )
        ]
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(transfer)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(TripTransfer.self, from: data)

    #expect(decoded.name == "Paris Trip")
    #expect(decoded.destination == "Paris, France")
    #expect(decoded.statusRaw == "active")
    #expect(decoded.notes == "A lovely trip")
    #expect(decoded.hasCustomDates == true)
    #expect(decoded.budgetAmount == 2500.50)
    #expect(decoded.budgetCurrencyCode == "EUR")
    #expect(decoded.days.count == 1)
    #expect(decoded.days[0].stops.count == 1)
    #expect(decoded.days[0].stops[0].name == "Eiffel Tower")
    #expect(decoded.days[0].stops[0].isVisited == true)
    #expect(decoded.days[0].stops[0].rating == 5)
    #expect(decoded.days[0].stops[0].comments.count == 1)
    #expect(decoded.days[0].stops[0].links.count == 1)
    #expect(decoded.days[0].stops[0].todos.count == 1)
    #expect(decoded.bookings.count == 1)
    #expect(decoded.bookings[0].airline == "Air France")
    #expect(decoded.bookings[0].confirmationCode == "AF-789")
    #expect(decoded.lists.count == 1)
    #expect(decoded.lists[0].items[0].text == "Passport")
    #expect(decoded.lists[0].items[0].isChecked == true)
    #expect(decoded.expenses.count == 1)
    #expect(decoded.expenses[0].amount == 85.50)
}

@Test func transferForwardCompatibility() throws {
    // JSON from a hypothetical older version that doesn't have links/todos on stops
    // Note: StopTransfer has default values for links/todos but standard Codable
    // requires the keys to be present. So we include them as empty arrays here,
    // which is what the encoder always produces.
    let json = """
    {
        "schemaVersion": 1,
        "name": "Old Trip",
        "destination": "Rome",
        "startDate": "2026-06-01T00:00:00Z",
        "endDate": "2026-06-03T00:00:00Z",
        "statusRaw": "planning",
        "notes": "",
        "hasCustomDates": false,
        "budgetAmount": 0,
        "budgetCurrencyCode": "USD",
        "days": [{
            "date": "2026-06-01T00:00:00Z",
            "dayNumber": 1,
            "notes": "",
            "location": "Rome",
            "locationLatitude": 41.9028,
            "locationLongitude": 12.4964,
            "stops": [{
                "name": "Colosseum",
                "latitude": 41.8902,
                "longitude": 12.4922,
                "categoryRaw": "attraction",
                "notes": "",
                "sortOrder": 0,
                "isVisited": false,
                "rating": 0,
                "comments": [],
                "links": [],
                "todos": []
            }]
        }],
        "bookings": [],
        "lists": [],
        "expenses": []
    }
    """
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let transfer = try decoder.decode(TripTransfer.self, from: Data(json.utf8))

    #expect(transfer.name == "Old Trip")
    #expect(transfer.days[0].stops[0].links.isEmpty)
    #expect(transfer.days[0].stops[0].todos.isEmpty)
}

@Test func transferSchemaVersionPreserved() throws {
    let transfer = TripTransfer(
        schemaVersion: TripTransfer.currentSchemaVersion,
        name: "V1", destination: "Test",
        startDate: Date(), endDate: Date(),
        statusRaw: "planning", notes: "",
        hasCustomDates: false, budgetAmount: 0, budgetCurrencyCode: "USD",
        days: [], bookings: [], lists: [], expenses: []
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(transfer)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(TripTransfer.self, from: data)
    #expect(decoded.schemaVersion == 2)
}

@Test func transferEmptyCollections() throws {
    let transfer = TripTransfer(
        schemaVersion: 2,
        name: "Empty", destination: "Nowhere",
        startDate: Date(), endDate: Date(),
        statusRaw: "planning", notes: "",
        hasCustomDates: false, budgetAmount: 0, budgetCurrencyCode: "USD",
        days: [], bookings: [], lists: [], expenses: []
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(transfer)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(TripTransfer.self, from: data)
    #expect(decoded.days.isEmpty)
    #expect(decoded.bookings.isEmpty)
    #expect(decoded.lists.isEmpty)
    #expect(decoded.expenses.isEmpty)
}

@Test func transferSpecialCharactersInText() throws {
    let transfer = TripTransfer(
        schemaVersion: 1,
        name: "Tokyo 🗼 \"Adventure\"",
        destination: "東京, 日本\nNew line",
        startDate: Date(), endDate: Date(),
        statusRaw: "planning",
        notes: "Quotes: \"hello\" 'world'\nEmoji: 🎌🍣\tTab",
        hasCustomDates: false, budgetAmount: 0, budgetCurrencyCode: "JPY",
        days: [], bookings: [], lists: [], expenses: []
    )
    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(transfer)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(TripTransfer.self, from: data)
    #expect(decoded.name == "Tokyo 🗼 \"Adventure\"")
    #expect(decoded.destination.contains("東京"))
    #expect(decoded.notes.contains("🎌🍣"))
}

// MARK: - 2. TripShareService Full Round-Trip

@Test func shareServiceExportImportRoundTrip() throws {
    let context = makeTestContext()
    let manager = DataManager(context: context)

    // Create a rich trip
    let trip = manager.createTrip(
        name: "Share Test Trip",
        destination: "London, UK",
        startDate: date(2026, 7, 1),
        endDate: date(2026, 7, 3)
    )
    trip.budgetAmount = 1500
    trip.budgetCurrencyCode = "GBP"
    trip.hasCustomDates = true
    trip.statusRaw = "active"

    // Add a stop with comments, links, todos
    let day1 = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }.first!
    let stop = manager.addStop(to: day1, name: "Big Ben", latitude: 51.5007, longitude: -0.1246, category: .attraction, notes: "Iconic clock")
    stop.rating = 4
    stop.address = "Westminster"
    stop.phone = "+44123"
    stop.website = "https://bigben.example.com"
    stop.isVisited = true
    stop.visitedAt = date(2026, 7, 1)

    let comment = CommentEntity.create(in: context, text: "Beautiful!")
    comment.stop = stop
    let link = StopLinkEntity.create(in: context, title: "Info", url: "https://info.example.com")
    link.stop = stop
    let todo = StopTodoEntity.create(in: context, text: "Take photo", sortOrder: 0)
    todo.isCompleted = true
    todo.stop = stop

    // Add booking
    let booking = BookingEntity.create(in: context, type: .flight, title: "BA 456", confirmationCode: "BA-CONF")
    booking.airline = "British Airways"
    booking.flightNumber = "BA456"
    booking.trip = trip

    // Add list with items
    let list = TripListEntity.create(in: context, name: "Packing", icon: "suitcase.fill")
    list.trip = trip
    let item = TripListItemEntity.create(in: context, text: "Umbrella")
    item.isChecked = true
    item.list = list

    // Add expense
    let expense = manager.addExpense(to: trip, title: "Taxi", amount: 35.0, category: .transport)
    _ = expense // silence warning

    try? context.save()

    // Export
    let fileURL = try TripShareService.exportTrip(trip)

    // Decode
    let transfer = try TripShareService.decodeTrip(from: fileURL)

    // Import into fresh context
    let context2 = makeTestContext()
    let imported = TripShareService.importTrip(transfer, into: context2)

    // Verify trip fields
    #expect(imported.wrappedName == "Share Test Trip")
    #expect(imported.wrappedDestination == "London, UK")
    #expect(imported.budgetAmount == 1500)
    #expect(imported.wrappedBudgetCurrencyCode == "GBP")
    #expect(imported.hasCustomDates == true)
    #expect(imported.wrappedStatusRaw == "active")

    // Verify days
    #expect(imported.daysArray.count == 3)

    // Verify stop
    let importedDay1 = imported.daysArray.sorted { $0.dayNumber < $1.dayNumber }.first!
    #expect(importedDay1.stopsArray.count == 1)
    let importedStop = importedDay1.stopsArray.first!
    #expect(importedStop.wrappedName == "Big Ben")
    #expect(importedStop.latitude == 51.5007)
    #expect(importedStop.rating == 4)
    #expect(importedStop.isVisited == true)
    #expect(importedStop.address == "Westminster")

    // Verify stop children
    #expect(importedStop.commentsArray.count == 1)
    #expect(importedStop.commentsArray.first?.wrappedText == "Beautiful!")
    #expect(importedStop.linksArray.count == 1)
    #expect(importedStop.linksArray.first?.wrappedURL == "https://info.example.com")
    #expect(importedStop.todosArray.count == 1)
    #expect(importedStop.todosArray.first?.isCompleted == true)

    // Verify booking
    #expect(imported.bookingsArray.count == 1)
    #expect(imported.bookingsArray.first?.wrappedTitle == "BA 456")
    #expect(imported.bookingsArray.first?.airline == "British Airways")

    // Verify list
    #expect(imported.listsArray.count == 1)
    #expect(imported.listsArray.first?.wrappedName == "Packing")
    #expect(imported.listsArray.first?.itemsArray.count == 1)
    #expect(imported.listsArray.first?.itemsArray.first?.isChecked == true)

    // Verify expense
    #expect(imported.expensesArray.count == 1)
    #expect(imported.expensesArray.first?.amount == 35.0)

    // Clean up temp file
    try? FileManager.default.removeItem(at: fileURL)
}

@Test func shareServiceExportFileFormat() throws {
    let context = makeTestContext()
    let trip = TripEntity.create(
        in: context,
        name: "Format Test",
        destination: "Test",
        startDate: date(2026, 1, 1),
        endDate: date(2026, 1, 2)
    )
    try? context.save()

    let fileURL = try TripShareService.exportTrip(trip)
    #expect(fileURL.pathExtension == "tripwit")

    let data = try Data(contentsOf: fileURL)
    let json = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    #expect(json["schemaVersion"] as? Int == 2)
    #expect(json["name"] as? String == "Format Test")

    try? FileManager.default.removeItem(at: fileURL)
}

@Test func shareServiceImportSetsRelationships() {
    let transfer = TripTransfer(
        schemaVersion: 1,
        name: "Rel Test", destination: "Test",
        startDate: Date(), endDate: Date(),
        statusRaw: "planning", notes: "",
        hasCustomDates: false, budgetAmount: 0, budgetCurrencyCode: "USD",
        days: [DayTransfer(
            date: Date(), dayNumber: 1, notes: "", location: "",
            locationLatitude: 0, locationLongitude: 0,
            stops: [StopTransfer(
                name: "Stop", latitude: 0, longitude: 0,
                categoryRaw: "other", notes: "", sortOrder: 0,
                isVisited: false, rating: 0,
                comments: [CommentTransfer(text: "c", createdAt: Date())],
                links: [StopLinkTransfer(title: "l", url: "u", sortOrder: 0)],
                todos: [StopTodoTransfer(text: "t", isCompleted: false, sortOrder: 0)]
            )]
        )],
        bookings: [BookingTransfer(
            typeRaw: "hotel", title: "Hotel", confirmationCode: "",
            notes: "", sortOrder: 0
        )],
        lists: [ListTransfer(
            name: "List", icon: "list.bullet", sortOrder: 0,
            items: [ListItemTransfer(text: "Item", isChecked: false, sortOrder: 0)]
        )],
        expenses: [ExpenseTransfer(
            title: "Exp", amount: 10, currencyCode: "USD",
            dateIncurred: Date(), categoryRaw: "other", notes: "",
            sortOrder: 0, createdAt: Date()
        )]
    )

    let context = makeTestContext()
    let trip = TripShareService.importTrip(transfer, into: context)

    // Verify relationship chain
    let day = trip.daysArray.first!
    #expect(day.trip === trip)
    let stop = day.stopsArray.first!
    #expect(stop.day === day)
    #expect(stop.commentsArray.first?.stop === stop)
    #expect(stop.linksArray.first?.stop === stop)
    #expect(stop.todosArray.first?.stop === stop)
    #expect(trip.bookingsArray.first?.trip === trip)
    let list = trip.listsArray.first!
    #expect(list.trip === trip)
    #expect(list.itemsArray.first?.list === list)
    #expect(trip.expensesArray.first?.trip === trip)
}

@Test func shareServiceImportPreservesVisitedState() throws {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(
        name: "Visited Test",
        destination: "Test",
        startDate: date(2026, 8, 1),
        endDate: date(2026, 8, 2)
    )
    let day = trip.daysArray.first!
    let stop = manager.addStop(to: day, name: "Visited Stop", latitude: 0, longitude: 0, category: .other)
    stop.isVisited = true
    stop.visitedAt = date(2026, 8, 1)
    try? context.save()

    let fileURL = try TripShareService.exportTrip(trip)
    let transfer = try TripShareService.decodeTrip(from: fileURL)

    let context2 = makeTestContext()
    let imported = TripShareService.importTrip(transfer, into: context2)
    let importedStop = imported.daysArray.first!.stopsArray.first!

    #expect(importedStop.isVisited == true)
    #expect(importedStop.visitedAt != nil)

    try? FileManager.default.removeItem(at: fileURL)
}

// MARK: - 3. DataManager.syncDays

@Test func syncDaysExtendEnd() {
    let context = makeTestContext()
    let (trip, days) = makeTripWithDays(in: context, start: date(2026, 6, 1), end: date(2026, 6, 5))
    #expect(days.count == 5)

    // Add a stop to day 3 to verify it survives
    let manager = DataManager(context: context)
    manager.addStop(to: days[2], name: "Keeper", latitude: 0, longitude: 0, category: .other)

    // Extend end by 2 days
    trip.endDate = date(2026, 6, 7)
    manager.syncDays(for: trip)

    let newDays = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }
    #expect(newDays.count == 7)
    #expect(newDays.first?.dayNumber == 1)
    #expect(newDays.last?.dayNumber == 7)

    // Day 3 stop survived
    let day3 = newDays.first { $0.dayNumber == 3 }!
    #expect(day3.stopsArray.count == 1)
    #expect(day3.stopsArray.first?.wrappedName == "Keeper")
}

@Test func syncDaysShrinkEnd() {
    let context = makeTestContext()
    let (trip, days) = makeTripWithDays(in: context, start: date(2026, 6, 1), end: date(2026, 6, 5))

    let manager = DataManager(context: context)
    manager.addStop(to: days[4], name: "Will be deleted", latitude: 0, longitude: 0, category: .other)
    manager.addStop(to: days[1], name: "Will survive", latitude: 0, longitude: 0, category: .other)

    trip.endDate = date(2026, 6, 3)
    manager.syncDays(for: trip)
    try? context.save()

    // Re-fetch to get clean state
    let dayReq = DayEntity.fetchRequest() as! NSFetchRequest<DayEntity>
    dayReq.predicate = NSPredicate(format: "trip == %@", trip)
    dayReq.sortDescriptors = [NSSortDescriptor(keyPath: \DayEntity.dayNumber, ascending: true)]
    let newDays = (try? context.fetch(dayReq)) ?? []
    #expect(newDays.count == 3)
    #expect(newDays.last?.dayNumber == 3)

    // Day 2 stop survived
    let day2 = newDays.first { $0.dayNumber == 2 }!
    #expect(day2.stopsArray.count == 1)
}

@Test func syncDaysMoveStartForward() {
    let context = makeTestContext()
    let (trip, _) = makeTripWithDays(in: context, start: date(2026, 6, 1), end: date(2026, 6, 5))

    trip.startDate = date(2026, 6, 3)
    DataManager(context: context).syncDays(for: trip)
    try? context.save()

    let dayReq = DayEntity.fetchRequest() as! NSFetchRequest<DayEntity>
    dayReq.predicate = NSPredicate(format: "trip == %@", trip)
    dayReq.sortDescriptors = [NSSortDescriptor(keyPath: \DayEntity.dayNumber, ascending: true)]
    let newDays = (try? context.fetch(dayReq)) ?? []
    #expect(newDays.count == 3)
    #expect(newDays.first?.dayNumber == 1)
    #expect(newDays.last?.dayNumber == 3)
}

@Test func syncDaysMoveStartEarlier() {
    let context = makeTestContext()
    let (trip, _) = makeTripWithDays(in: context, start: date(2026, 6, 3), end: date(2026, 6, 7))

    trip.startDate = date(2026, 6, 1)
    DataManager(context: context).syncDays(for: trip)

    let newDays = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }
    #expect(newDays.count == 7)
    #expect(newDays.first?.dayNumber == 1)
    #expect(newDays.last?.dayNumber == 7)
}

@Test func syncDaysKeepsStopsOnSurvivingDays() {
    let context = makeTestContext()
    let (trip, days) = makeTripWithDays(in: context, start: date(2026, 6, 1), end: date(2026, 6, 5))
    let manager = DataManager(context: context)

    // Add stops to days 2 and 4
    manager.addStop(to: days[1], name: "Day2 Stop", latitude: 0, longitude: 0, category: .attraction)
    manager.addStop(to: days[3], name: "Day4 Stop", latitude: 0, longitude: 0, category: .restaurant)

    // Shrink to days 2-4 only
    trip.startDate = date(2026, 6, 2)
    trip.endDate = date(2026, 6, 4)
    manager.syncDays(for: trip)
    try? context.save()

    let dayReq = DayEntity.fetchRequest() as! NSFetchRequest<DayEntity>
    dayReq.predicate = NSPredicate(format: "trip == %@", trip)
    dayReq.sortDescriptors = [NSSortDescriptor(keyPath: \DayEntity.dayNumber, ascending: true)]
    let newDays = (try? context.fetch(dayReq)) ?? []
    #expect(newDays.count == 3)

    // Day 1 (was originally June 2) should have the Day2 Stop
    let stopsOnDay1 = newDays[0].stopsArray
    #expect(stopsOnDay1.count == 1)
    #expect(stopsOnDay1.first?.wrappedName == "Day2 Stop")

    // Day 3 (was originally June 4) should have the Day4 Stop
    let stopsOnDay3 = newDays[2].stopsArray
    #expect(stopsOnDay3.count == 1)
    #expect(stopsOnDay3.first?.wrappedName == "Day4 Stop")
}

// MARK: - 4. DataManager CRUD

@Test func createTripGeneratesDays() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(
        name: "Day Gen Test",
        destination: "Test",
        startDate: date(2026, 3, 1),
        endDate: date(2026, 3, 5)
    )
    let days = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }
    #expect(days.count == 5)
    #expect(days.first?.dayNumber == 1)
    #expect(days.last?.dayNumber == 5)

    // Dates should be sequential
    for (i, day) in days.enumerated() {
        let expected = calendar.date(byAdding: .day, value: i, to: calendar.startOfDay(for: date(2026, 3, 1)))!
        let dayDate = calendar.startOfDay(for: day.wrappedDate)
        #expect(dayDate == expected)
    }
}

@Test func deleteTripCascades() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(
        name: "Cascade Test",
        destination: "Test",
        startDate: date(2026, 4, 1),
        endDate: date(2026, 4, 3)
    )
    let day = trip.daysArray.first!
    manager.addStop(to: day, name: "Stop", latitude: 0, longitude: 0, category: .other)

    let booking = BookingEntity.create(in: context, type: .hotel, title: "Hotel")
    booking.trip = trip
    let list = TripListEntity.create(in: context, name: "List")
    list.trip = trip
    manager.addExpense(to: trip, title: "Taxi", amount: 20)
    try? context.save()

    manager.deleteTrip(trip)

    let trips = manager.fetchTrips()
    #expect(trips.isEmpty)

    // Verify cascade: no orphaned entities
    let dayReq = DayEntity.fetchRequest() as! NSFetchRequest<DayEntity>
    let dayCount = (try? context.count(for: dayReq)) ?? -1
    #expect(dayCount == 0)

    let stopReq = StopEntity.fetchRequest() as! NSFetchRequest<StopEntity>
    let stopCount = (try? context.count(for: stopReq)) ?? -1
    #expect(stopCount == 0)
}

@Test func addStopToDay() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(
        name: "Add Stop Test",
        destination: "Test",
        startDate: date(2026, 5, 1),
        endDate: date(2026, 5, 2)
    )
    let day = trip.daysArray.first!
    let beforeUpdate = trip.updatedAt

    let stop = manager.addStop(
        to: day,
        name: "Museum",
        latitude: 48.8606,
        longitude: 2.3376,
        category: .attraction,
        notes: "Buy tickets"
    )

    #expect(stop.wrappedName == "Museum")
    #expect(stop.day === day)
    #expect(day.stopsArray.count == 1)
    #expect(stop.sortOrder == 0)
    #expect(trip.updatedAt != beforeUpdate)
}

@Test func deleteStop() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(
        name: "Del Stop Test",
        destination: "Test",
        startDate: date(2026, 5, 1),
        endDate: date(2026, 5, 2)
    )
    let day = trip.daysArray.first!
    manager.addStop(to: day, name: "A", latitude: 0, longitude: 0, category: .other)
    let middle = manager.addStop(to: day, name: "B", latitude: 0, longitude: 0, category: .other)
    manager.addStop(to: day, name: "C", latitude: 0, longitude: 0, category: .other)

    #expect(day.stopsArray.count == 3)

    manager.deleteStop(middle)

    // Verify via fetch request (relationship caches can be stale after delete+save)
    let req = StopEntity.fetchRequest() as! NSFetchRequest<StopEntity>
    req.predicate = NSPredicate(format: "day == %@", day)
    let remaining = (try? context.fetch(req)) ?? []
    #expect(remaining.count == 2)
    let names = remaining.map(\.wrappedName).sorted()
    #expect(names == ["A", "C"])
}

@Test func toggleVisited() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(
        name: "Toggle Test",
        destination: "Test",
        startDate: date(2026, 5, 1),
        endDate: date(2026, 5, 2)
    )
    let day = trip.daysArray.first!
    let stop = manager.addStop(to: day, name: "Stop", latitude: 0, longitude: 0, category: .other)

    #expect(stop.isVisited == false)
    #expect(stop.visitedAt == nil)

    manager.toggleVisited(stop)
    #expect(stop.isVisited == true)
    #expect(stop.visitedAt != nil)

    manager.toggleVisited(stop)
    #expect(stop.isVisited == false)
    #expect(stop.visitedAt == nil)
}

@Test func moveStopBetweenDays() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(
        name: "Move Test",
        destination: "Test",
        startDate: date(2026, 5, 1),
        endDate: date(2026, 5, 3)
    )
    let days = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }
    let stop = manager.addStop(to: days[0], name: "Movable", latitude: 0, longitude: 0, category: .other)

    #expect(days[0].stopsArray.count == 1)
    #expect(days[1].stopsArray.count == 0)

    manager.moveStop(stop, to: days[1])

    #expect(days[0].stopsArray.count == 0)
    #expect(days[1].stopsArray.count == 1)
    #expect(stop.day === days[1])
}

@Test func reorderStops() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(
        name: "Reorder Test",
        destination: "Test",
        startDate: date(2026, 5, 1),
        endDate: date(2026, 5, 2)
    )
    let day = trip.daysArray.first!
    manager.addStop(to: day, name: "A", latitude: 0, longitude: 0, category: .other)
    manager.addStop(to: day, name: "B", latitude: 0, longitude: 0, category: .other)
    manager.addStop(to: day, name: "C", latitude: 0, longitude: 0, category: .other)

    // Move index 1 (B) to front (index 0)
    manager.reorderStops(in: day, from: IndexSet(integer: 1), to: 0)

    let stops = day.stopsArray
    #expect(stops.count == 3)
    #expect(stops[0].wrappedName == "B")
    #expect(stops[1].wrappedName == "A")
    #expect(stops[2].wrappedName == "C")
    #expect(stops[0].sortOrder == 0)
    #expect(stops[1].sortOrder == 1)
    #expect(stops[2].sortOrder == 2)
}

@Test func addAndDeleteExpense() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(
        name: "Expense Test",
        destination: "Test",
        startDate: date(2026, 5, 1),
        endDate: date(2026, 5, 2)
    )
    trip.budgetCurrencyCode = "EUR"
    try? context.save()

    let expense = manager.addExpense(to: trip, title: "Dinner", amount: 45.50, category: .food)
    #expect(trip.expensesArray.count == 1)
    #expect(expense.wrappedTitle == "Dinner")
    #expect(expense.amount == 45.50)
    #expect(expense.wrappedCurrencyCode == "EUR")
    #expect(expense.category == .food)

    manager.deleteExpense(expense)
    #expect(trip.expensesArray.count == 0)
}

// MARK: - 5. daysWithStopsOutsideRange

@Test func daysWithStopsOutsideRangeCountsCorrectly() {
    let context = makeTestContext()
    let (trip, days) = makeTripWithDays(in: context, start: date(2026, 6, 1), end: date(2026, 6, 5))
    let manager = DataManager(context: context)

    // Add stops to days 1, 3, 5
    manager.addStop(to: days[0], name: "S1", latitude: 0, longitude: 0, category: .other)
    manager.addStop(to: days[2], name: "S3", latitude: 0, longitude: 0, category: .other)
    manager.addStop(to: days[4], name: "S5", latitude: 0, longitude: 0, category: .other)

    // Shrink to days 2-4: days 1 and 5 have stops outside range
    let count = manager.daysWithStopsOutsideRange(
        for: trip,
        newStart: date(2026, 6, 2),
        newEnd: date(2026, 6, 4)
    )
    #expect(count == 2)
}

@Test func daysWithStopsOutsideRangeZeroWhenAllInRange() {
    let context = makeTestContext()
    let (trip, days) = makeTripWithDays(in: context, start: date(2026, 6, 1), end: date(2026, 6, 5))
    let manager = DataManager(context: context)

    manager.addStop(to: days[1], name: "S2", latitude: 0, longitude: 0, category: .other)
    manager.addStop(to: days[3], name: "S4", latitude: 0, longitude: 0, category: .other)

    let count = manager.daysWithStopsOutsideRange(
        for: trip,
        newStart: date(2026, 6, 1),
        newEnd: date(2026, 6, 5)
    )
    #expect(count == 0)
}

// MARK: - 6. WeatherService Static Helpers

@Test func weatherIconMappings() {
    #expect(WeatherService.weatherIcon(for: 0) == "sun.max.fill")
    #expect(WeatherService.weatherIcon(for: 1) == "cloud.sun.fill")
    #expect(WeatherService.weatherIcon(for: 2) == "cloud.sun.fill")
    #expect(WeatherService.weatherIcon(for: 3) == "cloud.fill")
    #expect(WeatherService.weatherIcon(for: 45) == "cloud.fog.fill")
    #expect(WeatherService.weatherIcon(for: 48) == "cloud.fog.fill")
    #expect(WeatherService.weatherIcon(for: 51) == "cloud.drizzle.fill")
    #expect(WeatherService.weatherIcon(for: 61) == "cloud.rain.fill")
    #expect(WeatherService.weatherIcon(for: 71) == "cloud.snow.fill")
    #expect(WeatherService.weatherIcon(for: 77) == "snowflake")
    #expect(WeatherService.weatherIcon(for: 80) == "cloud.heavyrain.fill")
    #expect(WeatherService.weatherIcon(for: 95) == "cloud.bolt.fill")
    #expect(WeatherService.weatherIcon(for: 96) == "cloud.bolt.rain.fill")
    #expect(WeatherService.weatherIcon(for: 999) == "cloud.fill")
}

@Test func weatherDescriptionMappings() {
    #expect(WeatherService.weatherDescription(for: 0) == "Clear")
    #expect(WeatherService.weatherDescription(for: 1) == "Mostly Clear")
    #expect(WeatherService.weatherDescription(for: 3) == "Overcast")
    #expect(WeatherService.weatherDescription(for: 65) == "Heavy Rain")
    #expect(WeatherService.weatherDescription(for: 75) == "Heavy Snow")
    #expect(WeatherService.weatherDescription(for: 95) == "Thunderstorm")
    #expect(WeatherService.weatherDescription(for: 96) == "Hail Storm")
    #expect(WeatherService.weatherDescription(for: 999) == "Unknown")
}

@Test func weatherColorMappings() {
    #expect(WeatherService.weatherColor(for: 0) == "yellow")
    #expect(WeatherService.weatherColor(for: 1) == "orange")
    #expect(WeatherService.weatherColor(for: 3) == "gray")
    #expect(WeatherService.weatherColor(for: 61) == "blue")
    #expect(WeatherService.weatherColor(for: 71) == "cyan")
    #expect(WeatherService.weatherColor(for: 95) == "purple")
    #expect(WeatherService.weatherColor(for: 999) == "gray")
}

// MARK: - 7. TripTextExporter

@Test func textExporterBasicStructure() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(
        name: "Text Export Trip",
        destination: "Barcelona",
        startDate: date(2026, 9, 1),
        endDate: date(2026, 9, 2)
    )
    let days = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }
    manager.addStop(to: days[0], name: "Sagrada Familia", latitude: 41.4036, longitude: 2.1744, category: .attraction)
    manager.addStop(to: days[0], name: "La Rambla", latitude: 41.3809, longitude: 2.1734, category: .activity)
    manager.addStop(to: days[1], name: "Park Güell", latitude: 41.4145, longitude: 2.1527, category: .attraction)

    let text = TripTextExporter.generateText(for: trip)

    #expect(text.contains("TEXT EXPORT TRIP"))
    #expect(text.contains("Barcelona"))
    #expect(text.contains("DAY 1"))
    #expect(text.contains("DAY 2"))
    #expect(text.contains("Sagrada Familia"))
    #expect(text.contains("La Rambla"))
    #expect(text.contains("Park Güell"))
    #expect(text.contains("Shared from TripWit"))
}

@Test func textExporterIncludesBookings() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(
        name: "Booking Export",
        destination: "Rome",
        startDate: date(2026, 10, 1),
        endDate: date(2026, 10, 3)
    )
    let booking = BookingEntity.create(in: context, type: .flight, title: "ITA 567", confirmationCode: "ITA-CONF-123")
    booking.trip = trip
    try? context.save()

    let text = TripTextExporter.generateText(for: trip)
    #expect(text.contains("FLIGHTS & HOTELS"))
    #expect(text.contains("ITA-CONF-123"))
}

@Test func textExporterEmptyDaysSayNoStops() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(
        name: "Empty Day",
        destination: "Test",
        startDate: date(2026, 11, 1),
        endDate: date(2026, 11, 1)
    )
    _ = trip // single day, no stops

    let text = TripTextExporter.generateText(for: trip)
    #expect(text.contains("No stops planned"))
}

// MARK: - 8. Entity Computed Properties

@Test func tripIsActive() {
    let context = makeTestContext()
    let yesterday = calendar.date(byAdding: .day, value: -1, to: Date())!
    let tomorrow = calendar.date(byAdding: .day, value: 1, to: Date())!
    let trip = TripEntity.create(
        in: context,
        name: "Active Trip",
        destination: "Test",
        startDate: yesterday,
        endDate: tomorrow,
        status: .active
    )
    #expect(trip.isActive == true)
    #expect(trip.isPast == false)
    #expect(trip.isFuture == false)
}

@Test func tripIsPast() {
    let context = makeTestContext()
    let trip = TripEntity.create(
        in: context,
        name: "Past Trip",
        destination: "Test",
        startDate: date(2025, 1, 1),
        endDate: date(2025, 1, 5)
    )
    #expect(trip.isPast == true)
    #expect(trip.isActive == false)
    #expect(trip.isFuture == false)
}

@Test func tripIsFuture() {
    let context = makeTestContext()
    let trip = TripEntity.create(
        in: context,
        name: "Future Trip",
        destination: "Test",
        startDate: date(2027, 12, 1),
        endDate: date(2027, 12, 10)
    )
    #expect(trip.isFuture == true)
    #expect(trip.isActive == false)
    #expect(trip.isPast == false)
}

@Test func bookingTypeRoundTrip() {
    let context = makeTestContext()
    let booking = BookingEntity.create(in: context, type: .flight, title: "Test Flight")
    #expect(booking.bookingType == .flight)
    #expect(booking.typeRaw == "flight")

    booking.bookingType = .hotel
    #expect(booking.typeRaw == "hotel")

    booking.bookingType = .carRental
    #expect(booking.typeRaw == "car_rental")
}

@Test func expenseCategoryRoundTrip() {
    let context = makeTestContext()
    let expense = ExpenseEntity.create(in: context, title: "Lunch", amount: 20, category: .food)
    #expect(expense.category == .food)
    #expect(expense.categoryRaw == "food")

    expense.category = .transport
    #expect(expense.categoryRaw == "transport")
}

@Test func tripListItemsArraySorted() {
    let context = makeTestContext()
    let list = TripListEntity.create(in: context, name: "Test List")

    let item3 = TripListItemEntity.create(in: context, text: "Third", sortOrder: 2)
    item3.list = list
    let item1 = TripListItemEntity.create(in: context, text: "First", sortOrder: 0)
    item1.list = list
    let item2 = TripListItemEntity.create(in: context, text: "Second", sortOrder: 1)
    item2.list = list

    let items = list.itemsArray
    #expect(items.count == 3)
    #expect(items[0].wrappedText == "First")
    #expect(items[1].wrappedText == "Second")
    #expect(items[2].wrappedText == "Third")
}

// MARK: - 9. Input Validation

@Test func validateTripRejectsEmptyName() {
    #expect(throws: ValidationError.emptyTripName) {
        try DataManager.validateTrip(name: "", destination: "Paris", startDate: date(2026, 6, 1), endDate: date(2026, 6, 5))
    }
    #expect(throws: ValidationError.emptyTripName) {
        try DataManager.validateTrip(name: "   ", destination: "Paris", startDate: date(2026, 6, 1), endDate: date(2026, 6, 5))
    }
}

@Test func validateTripRejectsEmptyDestination() {
    #expect(throws: ValidationError.emptyDestination) {
        try DataManager.validateTrip(name: "Trip", destination: "", startDate: date(2026, 6, 1), endDate: date(2026, 6, 5))
    }
}

@Test func validateTripRejectsEndBeforeStart() {
    #expect(throws: ValidationError.endDateBeforeStartDate) {
        try DataManager.validateTrip(name: "Trip", destination: "Paris", startDate: date(2026, 6, 5), endDate: date(2026, 6, 1))
    }
}

@Test func validateTripAcceptsSameDay() throws {
    try DataManager.validateTrip(name: "Day Trip", destination: "Nearby", startDate: date(2026, 6, 1), endDate: date(2026, 6, 1))
}

@Test func validateTripAcceptsValidInput() throws {
    try DataManager.validateTrip(name: "Paris", destination: "France", startDate: date(2026, 6, 1), endDate: date(2026, 6, 10))
}

@Test func validateStopRejectsEmptyName() {
    #expect(throws: ValidationError.emptyStopName) {
        try DataManager.validateStop(name: "")
    }
    #expect(throws: ValidationError.emptyStopName) {
        try DataManager.validateStop(name: "  \n  ")
    }
}

@Test func validateStopRejectsDepartureBeforeArrival() {
    let arrival = date(2026, 6, 1)
    let departure = date(2026, 5, 31)
    #expect(throws: ValidationError.departureBeforeArrival) {
        try DataManager.validateStop(name: "Stop", arrivalTime: arrival, departureTime: departure)
    }
}

@Test func validateStopAcceptsNilTimes() throws {
    try DataManager.validateStop(name: "Stop", arrivalTime: nil, departureTime: nil)
    try DataManager.validateStop(name: "Stop", arrivalTime: date(2026, 6, 1), departureTime: nil)
}

@Test func validateExpenseRejectsEmptyTitle() {
    #expect(throws: ValidationError.emptyExpenseTitle) {
        try DataManager.validateExpense(title: "", amount: 10)
    }
}

@Test func validateExpenseRejectsNegativeAmount() {
    #expect(throws: ValidationError.negativeExpenseAmount) {
        try DataManager.validateExpense(title: "Taxi", amount: -5.0)
    }
}

@Test func validateExpenseAcceptsZeroAmount() throws {
    try DataManager.validateExpense(title: "Free entry", amount: 0)
}

@Test func validateBookingRejectsEmptyTitle() {
    #expect(throws: ValidationError.emptyBookingTitle) {
        try DataManager.validateBooking(title: "")
    }
}

@Test func validateBookingRejectsArrivalBeforeDeparture() {
    let dep = date(2026, 6, 5)
    let arr = date(2026, 6, 1)
    #expect(throws: ValidationError.bookingArrivalBeforeDeparture) {
        try DataManager.validateBooking(title: "Flight", departureTime: dep, arrivalTime: arr)
    }
}

@Test func createValidatedTripWorks() throws {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = try manager.createValidatedTrip(
        name: "Valid Trip",
        destination: "Tokyo",
        startDate: date(2026, 7, 1),
        endDate: date(2026, 7, 5)
    )
    #expect(trip.wrappedName == "Valid Trip")
    #expect(trip.daysArray.count == 5)
}

@Test func createValidatedTripRejectsInvalid() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    #expect(throws: ValidationError.emptyTripName) {
        try manager.createValidatedTrip(name: "", destination: "Tokyo", startDate: date(2026, 7, 1), endDate: date(2026, 7, 5))
    }
    // Verify no trip was created
    #expect(manager.fetchTrips().isEmpty)
}

@Test func addValidatedStopRejectsEmptyName() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Test", destination: "Test", startDate: date(2026, 7, 1), endDate: date(2026, 7, 2))
    let day = trip.daysArray.first!
    #expect(throws: ValidationError.emptyStopName) {
        try manager.addValidatedStop(to: day, name: "", latitude: 0, longitude: 0, category: .other)
    }
    #expect(day.stopsArray.isEmpty)
}

@Test func addValidatedExpenseRejectsNegative() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Test", destination: "Test", startDate: date(2026, 7, 1), endDate: date(2026, 7, 2))
    #expect(throws: ValidationError.negativeExpenseAmount) {
        try manager.addValidatedExpense(to: trip, title: "Bad", amount: -10)
    }
    #expect(trip.expensesArray.isEmpty)
}

// MARK: - 10. Trip Cloning

@Test func cloneTripCopiesBasicFields() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let source = manager.createTrip(
        name: "Original Trip",
        destination: "Tokyo, Japan",
        startDate: date(2026, 3, 1),
        endDate: date(2026, 3, 5),
        notes: "Cherry blossom trip"
    )
    source.budgetAmount = 3000
    source.budgetCurrencyCode = "JPY"
    source.hasCustomDates = true
    try? context.save()

    let clone = manager.cloneTrip(source, newStartDate: date(2026, 9, 1))

    #expect(clone.wrappedName == "Original Trip (Copy)")
    #expect(clone.wrappedDestination == "Tokyo, Japan")
    #expect(clone.wrappedNotes == "Cherry blossom trip")
    #expect(clone.budgetAmount == 3000)
    #expect(clone.wrappedBudgetCurrencyCode == "JPY")
    #expect(clone.hasCustomDates == true)
    #expect(clone.status == .planning)
}

@Test func cloneTripShiftsDates() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let source = manager.createTrip(
        name: "5-Day Trip",
        destination: "Test",
        startDate: date(2026, 3, 1),
        endDate: date(2026, 3, 5)
    )

    let clone = manager.cloneTrip(source, newStartDate: date(2026, 9, 15))

    let cloneStart = calendar.startOfDay(for: clone.wrappedStartDate)
    let cloneEnd = calendar.startOfDay(for: clone.wrappedEndDate)
    #expect(cloneStart == date(2026, 9, 15))
    #expect(cloneEnd == date(2026, 9, 19))
    #expect(clone.durationInDays == 5)
}

@Test func cloneTripCopiesDaysAndStops() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let source = manager.createTrip(
        name: "Rich Trip",
        destination: "Paris",
        startDate: date(2026, 4, 1),
        endDate: date(2026, 4, 3)
    )
    let days = source.daysArray.sorted { $0.dayNumber < $1.dayNumber }
    days[0].notes = "Day 1 notes"
    days[0].location = "Central Paris"
    manager.addStop(to: days[0], name: "Eiffel Tower", latitude: 48.8584, longitude: 2.2945, category: .attraction, notes: "Book ahead")
    manager.addStop(to: days[1], name: "Louvre", latitude: 48.8606, longitude: 2.3376, category: .attraction)

    let clone = manager.cloneTrip(source, newStartDate: date(2026, 10, 1))

    let cloneDays = clone.daysArray.sorted { $0.dayNumber < $1.dayNumber }
    #expect(cloneDays.count == 3)
    #expect(cloneDays[0].wrappedNotes == "Day 1 notes")
    #expect(cloneDays[0].wrappedLocation == "Central Paris")
    #expect(cloneDays[0].stopsArray.count == 1)
    #expect(cloneDays[0].stopsArray.first?.wrappedName == "Eiffel Tower")
    #expect(cloneDays[0].stopsArray.first?.wrappedNotes == "Book ahead")
    #expect(cloneDays[1].stopsArray.count == 1)
    #expect(cloneDays[1].stopsArray.first?.wrappedName == "Louvre")
}

@Test func cloneTripResetsVisitedAndTodos() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let source = manager.createTrip(
        name: "Completed Trip",
        destination: "London",
        startDate: date(2026, 5, 1),
        endDate: date(2026, 5, 2)
    )
    let day = source.daysArray.first!
    let stop = manager.addStop(to: day, name: "Big Ben", latitude: 51.5, longitude: -0.1, category: .attraction)
    stop.isVisited = true
    stop.visitedAt = date(2026, 5, 1)
    let todo = StopTodoEntity.create(in: context, text: "Take photo", sortOrder: 0)
    todo.isCompleted = true
    todo.stop = stop
    try? context.save()

    let clone = manager.cloneTrip(source, newStartDate: date(2026, 11, 1))

    let cloneStop = clone.daysArray.first!.stopsArray.first!
    #expect(cloneStop.isVisited == false)
    #expect(cloneStop.visitedAt == nil)
    #expect(cloneStop.todosArray.first?.isCompleted == false)
}

@Test func cloneTripCopiesBookingsWithoutConfirmationCode() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let source = manager.createTrip(
        name: "Booking Trip",
        destination: "Rome",
        startDate: date(2026, 6, 1),
        endDate: date(2026, 6, 3)
    )
    let booking = BookingEntity.create(in: context, type: .flight, title: "ITA 100", confirmationCode: "CONF-123")
    booking.airline = "ITA Airways"
    booking.departureAirport = "JFK"
    booking.arrivalAirport = "FCO"
    booking.trip = source
    try? context.save()

    let clone = manager.cloneTrip(source, newStartDate: date(2026, 12, 1))

    #expect(clone.bookingsArray.count == 1)
    let cloneBooking = clone.bookingsArray.first!
    #expect(cloneBooking.wrappedTitle == "ITA 100")
    #expect(cloneBooking.airline == "ITA Airways")
    #expect(cloneBooking.departureAirport == "JFK")
    #expect(cloneBooking.wrappedConfirmationCode == "")
}

@Test func cloneTripCopiesListsWithResetChecks() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let source = manager.createTrip(
        name: "List Trip",
        destination: "Test",
        startDate: date(2026, 7, 1),
        endDate: date(2026, 7, 2)
    )
    let list = TripListEntity.create(in: context, name: "Packing", icon: "suitcase.fill")
    list.trip = source
    let item = TripListItemEntity.create(in: context, text: "Passport")
    item.isChecked = true
    item.list = list
    try? context.save()

    let clone = manager.cloneTrip(source, newStartDate: date(2027, 1, 1))

    #expect(clone.listsArray.count == 1)
    let cloneList = clone.listsArray.first!
    #expect(cloneList.wrappedName == "Packing")
    #expect(cloneList.icon == "suitcase.fill")
    #expect(cloneList.itemsArray.count == 1)
    #expect(cloneList.itemsArray.first?.wrappedText == "Passport")
    #expect(cloneList.itemsArray.first?.isChecked == false)
}

@Test func cloneTripIsIndependent() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let source = manager.createTrip(
        name: "Independent Test",
        destination: "Test",
        startDate: date(2026, 8, 1),
        endDate: date(2026, 8, 3)
    )
    let day = source.daysArray.first!
    manager.addStop(to: day, name: "Original Stop", latitude: 0, longitude: 0, category: .other)

    let clone = manager.cloneTrip(source, newStartDate: date(2027, 2, 1))

    // Delete original — clone should be unaffected
    manager.deleteTrip(source)

    #expect(clone.daysArray.count == 3)
    #expect(clone.daysArray.first!.stopsArray.count == 1)
    #expect(clone.daysArray.first!.stopsArray.first?.wrappedName == "Original Stop")
}

// MARK: - 11. CSV Expense Export

@Test func csvExportHeader() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "CSV Test", destination: "Test", startDate: date(2026, 6, 1), endDate: date(2026, 6, 2))

    let csv = DataManager.exportExpensesCSV(for: trip)
    let lines = csv.components(separatedBy: "\n")
    #expect(lines.first == "Title,Amount,Currency,Category,Date,Notes")
}

@Test func csvExportWithExpenses() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Expense CSV", destination: "Paris", startDate: date(2026, 6, 1), endDate: date(2026, 6, 3))
    trip.budgetCurrencyCode = "EUR"
    try? context.save()

    manager.addExpense(to: trip, title: "Dinner", amount: 45.50, category: .food, date: date(2026, 6, 1), notes: "Le Marais")
    manager.addExpense(to: trip, title: "Metro Pass", amount: 16.90, category: .transport, date: date(2026, 6, 1))

    let csv = DataManager.exportExpensesCSV(for: trip)
    let lines = csv.components(separatedBy: "\n")

    // Header + 2 expenses + blank line + total = 5 lines
    #expect(lines.count == 5)
    #expect(lines[1].contains("Dinner"))
    #expect(lines[1].contains("45.50"))
    #expect(lines[1].contains("EUR"))
    #expect(lines[1].contains("Le Marais"))
    #expect(lines[2].contains("Metro Pass"))
    #expect(lines[2].contains("16.90"))

    // Total row
    #expect(lines[4].contains("Total"))
    #expect(lines[4].contains("62.40"))
}

@Test func csvExportEscapesSpecialCharacters() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Escape CSV", destination: "Test", startDate: date(2026, 7, 1), endDate: date(2026, 7, 2))
    trip.budgetCurrencyCode = "USD"
    try? context.save()

    manager.addExpense(to: trip, title: "Hotel, Room 101", amount: 200, notes: "Check-in \"early\"")

    let csv = DataManager.exportExpensesCSV(for: trip)
    // Title with comma should be quoted
    #expect(csv.contains("\"Hotel, Room 101\""))
    // Notes with quotes should be escaped
    #expect(csv.contains("\"Check-in \"\"early\"\"\""))
}

@Test func csvExportEmptyTrip() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Empty", destination: "Test", startDate: date(2026, 8, 1), endDate: date(2026, 8, 2))

    let csv = DataManager.exportExpensesCSV(for: trip)
    let lines = csv.components(separatedBy: "\n")
    // Header + blank + total = 3 lines
    #expect(lines.count == 3)
    #expect(lines[2].contains("Total"))
    #expect(lines[2].contains("0.00"))
}

// MARK: - 12. Trip Conflict Detection

@Test func conflictDetectsOverlap() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    manager.createTrip(name: "Trip A", destination: "Paris", startDate: date(2026, 6, 5), endDate: date(2026, 6, 10))

    // Overlapping range: June 8-12
    let conflicts = manager.findConflictingTrips(startDate: date(2026, 6, 8), endDate: date(2026, 6, 12))
    #expect(conflicts.count == 1)
    #expect(conflicts.first?.wrappedName == "Trip A")
}

@Test func conflictDetectsNoOverlap() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    manager.createTrip(name: "Trip A", destination: "Paris", startDate: date(2026, 6, 1), endDate: date(2026, 6, 5))

    // Non-overlapping: June 10-15
    let conflicts = manager.findConflictingTrips(startDate: date(2026, 6, 10), endDate: date(2026, 6, 15))
    #expect(conflicts.isEmpty)
}

@Test func conflictDetectsAdjacentDays() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    manager.createTrip(name: "Trip A", destination: "Paris", startDate: date(2026, 6, 1), endDate: date(2026, 6, 5))

    // Adjacent: starts day after Trip A ends — no overlap
    let conflicts = manager.findConflictingTrips(startDate: date(2026, 6, 6), endDate: date(2026, 6, 10))
    #expect(conflicts.isEmpty)

    // Touching: starts on same day Trip A ends — overlap
    let touching = manager.findConflictingTrips(startDate: date(2026, 6, 5), endDate: date(2026, 6, 10))
    #expect(touching.count == 1)
}

@Test func conflictExcludesSpecifiedTrip() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let tripA = manager.createTrip(name: "Trip A", destination: "Paris", startDate: date(2026, 6, 1), endDate: date(2026, 6, 10))
    manager.createTrip(name: "Trip B", destination: "London", startDate: date(2026, 6, 5), endDate: date(2026, 6, 15))

    // Both overlap with June 5-10, but exclude Trip A
    let conflicts = manager.findConflictingTrips(startDate: date(2026, 6, 5), endDate: date(2026, 6, 10), excluding: tripA)
    #expect(conflicts.count == 1)
    #expect(conflicts.first?.wrappedName == "Trip B")
}

@Test func conflictMultipleOverlaps() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    manager.createTrip(name: "Trip A", destination: "Paris", startDate: date(2026, 6, 1), endDate: date(2026, 6, 10))
    manager.createTrip(name: "Trip B", destination: "London", startDate: date(2026, 6, 8), endDate: date(2026, 6, 15))
    manager.createTrip(name: "Trip C", destination: "Tokyo", startDate: date(2026, 7, 1), endDate: date(2026, 7, 5))

    // June 5-12 overlaps A and B but not C
    let conflicts = manager.findConflictingTrips(startDate: date(2026, 6, 5), endDate: date(2026, 6, 12))
    #expect(conflicts.count == 2)
    let names = conflicts.map(\.wrappedName).sorted()
    #expect(names == ["Trip A", "Trip B"])
}

@Test func hasConflictingTripsBoolean() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    manager.createTrip(name: "Existing", destination: "Paris", startDate: date(2026, 6, 1), endDate: date(2026, 6, 5))

    #expect(manager.hasConflictingTrips(startDate: date(2026, 6, 3), endDate: date(2026, 6, 8)) == true)
    #expect(manager.hasConflictingTrips(startDate: date(2026, 7, 1), endDate: date(2026, 7, 5)) == false)
}

// MARK: - 13. Trip Completion Score

@Test func completionScoreEmptyTrip() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Empty", destination: "Test", startDate: date(2026, 9, 1), endDate: date(2026, 9, 3))

    let score = DataManager.completionScore(for: trip)
    #expect(score == 0.0)
}

@Test func completionScoreFullyPlanned() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Full", destination: "Paris", startDate: date(2026, 9, 1), endDate: date(2026, 9, 3))
    trip.budgetAmount = 2000
    try? context.save()

    // Add stop to every day
    for day in trip.daysArray {
        manager.addStop(to: day, name: "Stop \(day.dayNumber)", latitude: 0, longitude: 0, category: .attraction)
    }

    // Add booking
    let booking = BookingEntity.create(in: context, type: .flight, title: "Flight")
    booking.trip = trip

    // Add list with item
    let list = TripListEntity.create(in: context, name: "Packing")
    list.trip = trip
    let item = TripListItemEntity.create(in: context, text: "Passport")
    item.list = list
    try? context.save()

    let score = DataManager.completionScore(for: trip)
    #expect(score == 1.0)
}

@Test func completionScorePartiallyPlanned() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Partial", destination: "Rome", startDate: date(2026, 10, 1), endDate: date(2026, 10, 3))

    // Add stop to only first day (2 of 5 criteria: hasStops but not allDaysHaveStops)
    let day1 = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }.first!
    manager.addStop(to: day1, name: "Colosseum", latitude: 41.89, longitude: 12.49, category: .attraction)

    // Set budget (1 more criterion)
    trip.budgetAmount = 1000
    try? context.save()

    let score = DataManager.completionScore(for: trip)
    // hasStops (1) + budget (1) = 2/5 = 0.4
    #expect(score == 0.4)
}

@Test func completionScoreIncrements() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Incremental", destination: "Test", startDate: date(2026, 11, 1), endDate: date(2026, 11, 1))

    // Start: 0/5 = 0.0
    #expect(DataManager.completionScore(for: trip) == 0.0)

    // Add stop to the only day → hasStops (1) + allDaysHaveStops (1) = 2/5
    let day = trip.daysArray.first!
    manager.addStop(to: day, name: "S", latitude: 0, longitude: 0, category: .other)
    #expect(DataManager.completionScore(for: trip) == 0.4)

    // Add budget → 3/5
    trip.budgetAmount = 500
    #expect(DataManager.completionScore(for: trip) == 0.6)

    // Add booking → 4/5
    let booking = BookingEntity.create(in: context, type: .hotel, title: "Hotel")
    booking.trip = trip
    #expect(DataManager.completionScore(for: trip) == 0.8)

    // Add list with item → 5/5
    let list = TripListEntity.create(in: context, name: "List")
    list.trip = trip
    let item = TripListItemEntity.create(in: context, text: "Item")
    item.list = list
    #expect(DataManager.completionScore(for: trip) == 1.0)
}

// MARK: - 14. Trip Sorting

@Test func sortTripsByStartDateDescending() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let t1 = manager.createTrip(name: "Early", destination: "A", startDate: date(2026, 1, 1), endDate: date(2026, 1, 3))
    let t2 = manager.createTrip(name: "Late", destination: "B", startDate: date(2026, 6, 1), endDate: date(2026, 6, 3))
    let t3 = manager.createTrip(name: "Mid", destination: "C", startDate: date(2026, 3, 1), endDate: date(2026, 3, 3))

    let sorted = DataManager.sortTrips([t1, t2, t3], by: .startDateDescending)
    #expect(sorted.map(\.wrappedName) == ["Late", "Mid", "Early"])
}

@Test func sortTripsByStartDateAscending() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let t1 = manager.createTrip(name: "Late", destination: "A", startDate: date(2026, 6, 1), endDate: date(2026, 6, 3))
    let t2 = manager.createTrip(name: "Early", destination: "B", startDate: date(2026, 1, 1), endDate: date(2026, 1, 3))

    let sorted = DataManager.sortTrips([t1, t2], by: .startDateAscending)
    #expect(sorted.map(\.wrappedName) == ["Early", "Late"])
}

@Test func sortTripsByNameAscending() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let t1 = manager.createTrip(name: "Zulu Trip", destination: "A", startDate: date(2026, 1, 1), endDate: date(2026, 1, 1))
    let t2 = manager.createTrip(name: "Alpha Trip", destination: "B", startDate: date(2026, 2, 1), endDate: date(2026, 2, 1))
    let t3 = manager.createTrip(name: "Mike Trip", destination: "C", startDate: date(2026, 3, 1), endDate: date(2026, 3, 1))

    let sorted = DataManager.sortTrips([t1, t2, t3], by: .nameAscending)
    #expect(sorted.map(\.wrappedName) == ["Alpha Trip", "Mike Trip", "Zulu Trip"])
}

@Test func sortTripsByDestination() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let t1 = manager.createTrip(name: "Trip 1", destination: "Tokyo", startDate: date(2026, 1, 1), endDate: date(2026, 1, 1))
    let t2 = manager.createTrip(name: "Trip 2", destination: "Berlin", startDate: date(2026, 2, 1), endDate: date(2026, 2, 1))
    let t3 = manager.createTrip(name: "Trip 3", destination: "Paris", startDate: date(2026, 3, 1), endDate: date(2026, 3, 1))

    let sorted = DataManager.sortTrips([t1, t2, t3], by: .destinationAscending)
    #expect(sorted.map(\.wrappedDestination) == ["Berlin", "Paris", "Tokyo"])
}

@Test func sortTripsByDuration() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let t1 = manager.createTrip(name: "Short", destination: "A", startDate: date(2026, 1, 1), endDate: date(2026, 1, 2))   // 2 days
    let t2 = manager.createTrip(name: "Long", destination: "B", startDate: date(2026, 2, 1), endDate: date(2026, 2, 10))   // 10 days
    let t3 = manager.createTrip(name: "Medium", destination: "C", startDate: date(2026, 3, 1), endDate: date(2026, 3, 5))  // 5 days

    let sorted = DataManager.sortTrips([t1, t2, t3], by: .durationDescending)
    #expect(sorted.map(\.wrappedName) == ["Long", "Medium", "Short"])
}

// MARK: - 15. Batch Mark Stops as Visited

@Test func batchSetVisitedMarksAll() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Batch", destination: "Test", startDate: date(2026, 3, 1), endDate: date(2026, 3, 1))
    let day = trip.daysArray.first!

    let s1 = manager.addStop(to: day, name: "A", latitude: 0, longitude: 0, category: .other)
    let s2 = manager.addStop(to: day, name: "B", latitude: 0, longitude: 0, category: .other)
    let s3 = manager.addStop(to: day, name: "C", latitude: 0, longitude: 0, category: .other)

    manager.batchSetVisited([s1, s2, s3], visited: true)

    #expect(s1.isVisited == true)
    #expect(s2.isVisited == true)
    #expect(s3.isVisited == true)
    #expect(s1.visitedAt != nil)
    #expect(s2.visitedAt != nil)
    #expect(s3.visitedAt != nil)
}

@Test func batchSetVisitedUnmarksAll() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Batch", destination: "Test", startDate: date(2026, 3, 2), endDate: date(2026, 3, 2))
    let day = trip.daysArray.first!

    let s1 = manager.addStop(to: day, name: "A", latitude: 0, longitude: 0, category: .other)
    let s2 = manager.addStop(to: day, name: "B", latitude: 0, longitude: 0, category: .other)

    // First mark visited
    manager.batchSetVisited([s1, s2], visited: true)
    #expect(s1.isVisited == true)

    // Then unmark
    manager.batchSetVisited([s1, s2], visited: false)
    #expect(s1.isVisited == false)
    #expect(s2.isVisited == false)
    #expect(s1.visitedAt == nil)
    #expect(s2.visitedAt == nil)
}

@Test func batchSetDayVisited() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Day Batch", destination: "Test", startDate: date(2026, 3, 3), endDate: date(2026, 3, 4))
    let days = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }

    let s1 = manager.addStop(to: days[0], name: "A", latitude: 0, longitude: 0, category: .other)
    let s2 = manager.addStop(to: days[0], name: "B", latitude: 0, longitude: 0, category: .other)
    let s3 = manager.addStop(to: days[1], name: "C", latitude: 0, longitude: 0, category: .other)

    // Mark day 1 as visited — only day 1 stops affected
    manager.batchSetDayVisited(days[0], visited: true)

    #expect(s1.isVisited == true)
    #expect(s2.isVisited == true)
    #expect(s3.isVisited == false) // day 2 stop unaffected
}

@Test func batchSetVisitedPartialSelection() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Partial", destination: "Test", startDate: date(2026, 3, 5), endDate: date(2026, 3, 5))
    let day = trip.daysArray.first!

    let s1 = manager.addStop(to: day, name: "A", latitude: 0, longitude: 0, category: .other)
    let s2 = manager.addStop(to: day, name: "B", latitude: 0, longitude: 0, category: .other)
    let s3 = manager.addStop(to: day, name: "C", latitude: 0, longitude: 0, category: .other)

    // Only mark first two
    manager.batchSetVisited([s1, s2], visited: true)

    #expect(s1.isVisited == true)
    #expect(s2.isVisited == true)
    #expect(s3.isVisited == false)
}

// MARK: - 15. Move Stop Between Days (sort order)

@Test func moveStopToPopulatedDayGetsCorrectSortOrder() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Move Test", destination: "Test", startDate: date(2026, 4, 1), endDate: date(2026, 4, 2))
    let days = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }

    // Day 1: one stop
    let stopA = manager.addStop(to: days[0], name: "A", latitude: 0, longitude: 0, category: .other)

    // Day 2: two stops
    manager.addStop(to: days[1], name: "B", latitude: 0, longitude: 0, category: .other)
    manager.addStop(to: days[1], name: "C", latitude: 0, longitude: 0, category: .other)

    // Move A to day 2 — should get sortOrder 2 (appended)
    manager.moveStop(stopA, to: days[1])

    #expect(stopA.day == days[1])
    #expect(stopA.sortOrder == 2)
    #expect(days[0].stopsArray.isEmpty)
    #expect(days[1].stopsArray.count == 3)
}

// MARK: - 15. Trip Statistics

@Test func tripStatisticsBasic() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Stats Trip", destination: "Rome", startDate: date(2026, 5, 1), endDate: date(2026, 5, 3))
    let days = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }

    manager.addStop(to: days[0], name: "Colosseum", latitude: 41.89, longitude: 12.49, category: .attraction)
    manager.addStop(to: days[0], name: "Pasta Place", latitude: 41.90, longitude: 12.49, category: .restaurant)
    manager.addStop(to: days[1], name: "Vatican", latitude: 41.90, longitude: 12.45, category: .attraction)
    // day 3 is empty

    let stats = DataManager.tripStatistics(for: trip)
    #expect(stats.totalStops == 3)
    #expect(stats.visitedStops == 0)
    #expect(stats.totalDays == 3)
    #expect(stats.daysWithStops == 2)
    #expect(stats.emptyDays == 1)
    #expect(stats.averageStopsPerDay == 1.0)
    #expect(stats.completionPercentage == 0.0)
}

@Test func tripStatisticsCategoryBreakdown() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Categories", destination: "Test", startDate: date(2026, 5, 10), endDate: date(2026, 5, 11))
    let day = trip.daysArray.first!

    manager.addStop(to: day, name: "Museum", latitude: 0, longitude: 0, category: .attraction)
    manager.addStop(to: day, name: "Cafe", latitude: 0, longitude: 0, category: .restaurant)
    manager.addStop(to: day, name: "Gallery", latitude: 0, longitude: 0, category: .attraction)
    manager.addStop(to: day, name: "Hotel", latitude: 0, longitude: 0, category: .accommodation)

    let stats = DataManager.tripStatistics(for: trip)
    #expect(stats.categoryBreakdown[.attraction] == 2)
    #expect(stats.categoryBreakdown[.restaurant] == 1)
    #expect(stats.categoryBreakdown[.accommodation] == 1)
    #expect(stats.categoryBreakdown[.transport] == nil)
}

@Test func tripStatisticsWithVisitedAndBudget() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Budget Trip", destination: "Berlin", startDate: date(2026, 6, 1), endDate: date(2026, 6, 2))
    let days = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }

    let stop1 = manager.addStop(to: days[0], name: "Gate", latitude: 52.51, longitude: 13.37, category: .attraction)
    manager.addStop(to: days[1], name: "Museum", latitude: 52.52, longitude: 13.39, category: .attraction)

    // Mark one visited
    manager.toggleVisited(stop1)

    // Set budget and add expenses
    trip.budgetAmount = 500.0
    try? context.save()
    manager.addExpense(to: trip, title: "Dinner", amount: 45.50, category: .food)
    manager.addExpense(to: trip, title: "Taxi", amount: 22.00, category: .transport)

    let stats = DataManager.tripStatistics(for: trip)
    #expect(stats.visitedStops == 1)
    #expect(stats.completionPercentage == 0.5)
    #expect(stats.totalExpenses == 67.50)
    #expect(stats.budgetRemaining == 432.50)
    #expect(stats.totalBookings == 0)
}

@Test func tripStatisticsEmptyTrip() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Empty", destination: "Nowhere", startDate: date(2026, 7, 1), endDate: date(2026, 7, 1))

    let stats = DataManager.tripStatistics(for: trip)
    #expect(stats.totalStops == 0)
    #expect(stats.visitedStops == 0)
    #expect(stats.totalDays == 1)
    #expect(stats.daysWithStops == 0)
    #expect(stats.emptyDays == 1)
    #expect(stats.averageStopsPerDay == 0)
    #expect(stats.completionPercentage == 0)
    #expect(stats.budgetRemaining == nil)
    #expect(stats.categoryBreakdown.isEmpty)
}

// MARK: - 15. Stop Search & Filter

@Test func filterStopsByQuery() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Trip", destination: "Paris", startDate: date(2026, 6, 1), endDate: date(2026, 6, 3))
    let days = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }

    manager.addStop(to: days[0], name: "Eiffel Tower", latitude: 48.85, longitude: 2.29, category: .attraction)
    manager.addStop(to: days[0], name: "Louvre Museum", latitude: 48.86, longitude: 2.33, category: .attraction)
    manager.addStop(to: days[1], name: "Café de Flore", latitude: 48.85, longitude: 2.33, category: .restaurant)
    manager.addStop(to: days[2], name: "Notre Dame", latitude: 48.85, longitude: 2.35, category: .attraction, notes: "Beautiful tower view")

    let results = DataManager.filterStops(in: trip, query: "tower")
    #expect(results.count == 2) // "Eiffel Tower" + "Notre Dame" (has "tower" in notes)
    #expect(results.contains(where: { $0.wrappedName == "Eiffel Tower" }))
    #expect(results.contains(where: { $0.wrappedName == "Notre Dame" }))
}

@Test func filterStopsByCategory() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Trip", destination: "Rome", startDate: date(2026, 7, 1), endDate: date(2026, 7, 2))
    let days = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }

    manager.addStop(to: days[0], name: "Colosseum", latitude: 41.89, longitude: 12.49, category: .attraction)
    manager.addStop(to: days[0], name: "Trattoria", latitude: 41.90, longitude: 12.49, category: .restaurant)
    manager.addStop(to: days[1], name: "Vatican", latitude: 41.90, longitude: 12.45, category: .attraction)

    let attractions = DataManager.filterStops(in: trip, category: .attraction)
    #expect(attractions.count == 2)
    #expect(attractions.allSatisfy { $0.category == .attraction })

    let restaurants = DataManager.filterStops(in: trip, category: .restaurant)
    #expect(restaurants.count == 1)
    #expect(restaurants[0].wrappedName == "Trattoria")
}

@Test func filterStopsByCategoryAndQuery() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Trip", destination: "London", startDate: date(2026, 8, 1), endDate: date(2026, 8, 2))
    let days = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }

    manager.addStop(to: days[0], name: "Tower Bridge", latitude: 51.50, longitude: -0.07, category: .attraction)
    manager.addStop(to: days[0], name: "Tower Restaurant", latitude: 51.51, longitude: -0.07, category: .restaurant)
    manager.addStop(to: days[1], name: "Big Ben", latitude: 51.50, longitude: -0.12, category: .attraction)

    // "Tower" + attraction → only Tower Bridge
    let results = DataManager.filterStops(in: trip, query: "Tower", category: .attraction)
    #expect(results.count == 1)
    #expect(results[0].wrappedName == "Tower Bridge")
}

@Test func filterStopsEmptyQueryReturnsAll() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Trip", destination: "Test", startDate: date(2026, 9, 1), endDate: date(2026, 9, 1))
    let day = trip.daysArray.first!

    manager.addStop(to: day, name: "A", latitude: 0, longitude: 0, category: .other)
    manager.addStop(to: day, name: "B", latitude: 0, longitude: 0, category: .attraction)

    let results = DataManager.filterStops(in: trip)
    #expect(results.count == 2)
}

@Test func filterStopsByAddress() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Trip", destination: "NYC", startDate: date(2026, 10, 1), endDate: date(2026, 10, 1))
    let day = trip.daysArray.first!

    let stop = manager.addStop(to: day, name: "Restaurant", latitude: 40.71, longitude: -74.00, category: .restaurant)
    stop.address = "123 Broadway, New York"
    try? context.save()

    let results = DataManager.filterStops(in: trip, query: "broadway")
    #expect(results.count == 1)
    #expect(results[0].wrappedName == "Restaurant")
}

@Test func filterStopsCaseInsensitive() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Trip", destination: "Test", startDate: date(2026, 11, 1), endDate: date(2026, 11, 1))
    let day = trip.daysArray.first!

    manager.addStop(to: day, name: "EIFFEL TOWER", latitude: 0, longitude: 0, category: .attraction)

    let results = DataManager.filterStops(in: trip, query: "eiffel tower")
    #expect(results.count == 1)
}

// MARK: - 21. Collaborative Checklist Sync

@Test func checklistSyncRoundTripViaTransfer() throws {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Checklist Trip", destination: "Test", startDate: date(2026, 4, 1), endDate: date(2026, 4, 1))

    // Create a list with mixed checked/unchecked items
    let list = TripListEntity.create(in: context, name: "Packing List", icon: "bag")
    list.trip = trip
    let item1 = TripListItemEntity.create(in: context, text: "Passport", sortOrder: 0)
    item1.isChecked = true
    item1.list = list
    let item2 = TripListItemEntity.create(in: context, text: "Sunscreen", sortOrder: 1)
    item2.isChecked = false
    item2.list = list
    let item3 = TripListItemEntity.create(in: context, text: "Camera", sortOrder: 2)
    item3.isChecked = true
    item3.list = list
    try? context.save()

    // Export → decode round-trip
    let fileURL = try TripShareService.exportTrip(trip)
    let transfer = try TripShareService.decodeTrip(from: fileURL)

    // Verify checklist state preserved in transfer
    let listT = transfer.lists.first!
    #expect(listT.items.count == 3)
    let sorted = listT.items.sorted { $0.sortOrder < $1.sortOrder }
    #expect(sorted[0].text == "Passport")
    #expect(sorted[0].isChecked == true)
    #expect(sorted[1].text == "Sunscreen")
    #expect(sorted[1].isChecked == false)
    #expect(sorted[2].text == "Camera")
    #expect(sorted[2].isChecked == true)

    // Import into fresh context and verify
    let context2 = makeTestContext()
    let imported = TripShareService.importTrip(transfer, into: context2)
    let importedList = imported.listsArray.first!
    let importedItems = importedList.itemsArray
    #expect(importedItems.count == 3)
    let checkedItems = importedItems.filter(\.isChecked)
    #expect(checkedItems.count == 2)
    let uncheckedItems = importedItems.filter { !$0.isChecked }
    #expect(uncheckedItems.count == 1)
    #expect(uncheckedItems.first?.wrappedText == "Sunscreen")
}

@Test func stopTodoCompletionSyncRoundTrip() throws {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Todo Trip", destination: "Test", startDate: date(2026, 4, 2), endDate: date(2026, 4, 2))
    let day = trip.daysArray.first!
    let stop = manager.addStop(to: day, name: "Museum", latitude: 0, longitude: 0, category: .attraction)

    // Create todos with mixed completion
    let todo1 = StopTodoEntity.create(in: context, text: "Buy tickets", sortOrder: 0)
    todo1.isCompleted = true
    todo1.stop = stop
    let todo2 = StopTodoEntity.create(in: context, text: "Check hours", sortOrder: 1)
    todo2.isCompleted = false
    todo2.stop = stop
    try? context.save()

    // Export → decode → import round-trip
    let fileURL = try TripShareService.exportTrip(trip)
    let transfer = try TripShareService.decodeTrip(from: fileURL)

    let context2 = makeTestContext()
    let imported = TripShareService.importTrip(transfer, into: context2)
    let importedStop = imported.daysArray.first!.stopsArray.first!
    let importedTodos = importedStop.todosArray
    #expect(importedTodos.count == 2)

    let completed = importedTodos.filter(\.isCompleted)
    #expect(completed.count == 1)
    #expect(completed.first?.wrappedText == "Buy tickets")

    let incomplete = importedTodos.filter { !$0.isCompleted }
    #expect(incomplete.count == 1)
    #expect(incomplete.first?.wrappedText == "Check hours")
}

@Test func multipleListsSyncRoundTrip() throws {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Multi List", destination: "Test", startDate: date(2026, 4, 3), endDate: date(2026, 4, 3))

    // Create two lists
    let packingList = TripListEntity.create(in: context, name: "Packing", icon: "bag", sortOrder: 0)
    packingList.trip = trip
    let packItem = TripListItemEntity.create(in: context, text: "Jacket", sortOrder: 0)
    packItem.isChecked = true
    packItem.list = packingList

    let todoList = TripListEntity.create(in: context, name: "To Do", icon: "checklist", sortOrder: 1)
    todoList.trip = trip
    let todoItem1 = TripListItemEntity.create(in: context, text: "Book restaurant", sortOrder: 0)
    todoItem1.isChecked = false
    todoItem1.list = todoList
    let todoItem2 = TripListItemEntity.create(in: context, text: "Print map", sortOrder: 1)
    todoItem2.isChecked = true
    todoItem2.list = todoList
    try? context.save()

    let fileURL = try TripShareService.exportTrip(trip)
    let transfer = try TripShareService.decodeTrip(from: fileURL)
    let context2 = makeTestContext()
    let imported = TripShareService.importTrip(transfer, into: context2)

    #expect(imported.listsArray.count == 2)

    let importedPacking = imported.listsArray.first(where: { $0.wrappedName == "Packing" })!
    #expect(importedPacking.itemsArray.count == 1)
    #expect(importedPacking.itemsArray.first?.isChecked == true)

    let importedTodo = imported.listsArray.first(where: { $0.wrappedName == "To Do" })!
    #expect(importedTodo.itemsArray.count == 2)
    let checkedTodos = importedTodo.itemsArray.filter(\.isChecked)
    #expect(checkedTodos.count == 1)
    #expect(checkedTodos.first?.wrappedText == "Print map")
}

// MARK: - 22. Notification Reminders Computation

@Test func reminderTripStarting() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Paris", destination: "Paris, France", startDate: date(2026, 8, 15), endDate: date(2026, 8, 20))

    // "now" is well before the trip
    let now = date(2026, 8, 1)
    let reminders = DataManager.computeReminders(for: trip, now: now)

    let tripReminder = reminders.first(where: { $0.type == .tripStarting })
    #expect(tripReminder != nil)
    #expect(tripReminder!.title == "Trip tomorrow!")
    #expect(tripReminder!.body.contains("Paris"))
    // Should fire on Aug 14 at 9 AM
    let fireComps = calendar.dateComponents([.year, .month, .day, .hour], from: tripReminder!.fireDate)
    #expect(fireComps.month == 8)
    #expect(fireComps.day == 14)
    #expect(fireComps.hour == 9)
}

@Test func reminderFlightDeparture() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Trip", destination: "Tokyo", startDate: date(2026, 9, 1), endDate: date(2026, 9, 7))

    let depTime = calendar.date(from: DateComponents(year: 2026, month: 9, day: 1, hour: 14, minute: 30))!
    let booking = BookingEntity.create(in: context, type: .flight, title: "JL Flight 12", confirmationCode: "ABC")
    booking.departureTime = depTime
    booking.trip = trip
    try? context.save()

    let now = date(2026, 8, 1)
    let reminders = DataManager.computeReminders(for: trip, now: now)

    let flightReminder = reminders.first(where: { $0.type == .flightDeparture })
    #expect(flightReminder != nil)
    #expect(flightReminder!.body.contains("JL Flight 12"))
    // Should fire 3 hours before: Sep 1 at 11:30
    let fireComps = calendar.dateComponents([.hour, .minute], from: flightReminder!.fireDate)
    #expect(fireComps.hour == 11)
    #expect(fireComps.minute == 30)
}

@Test func reminderHotelCheckInAndOut() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Trip", destination: "Berlin", startDate: date(2026, 10, 1), endDate: date(2026, 10, 5))

    let booking = BookingEntity.create(in: context, type: .hotel, title: "Grand Hotel")
    booking.hotelName = "Grand Hotel Berlin"
    booking.checkInDate = date(2026, 10, 1)
    booking.checkOutDate = date(2026, 10, 5)
    booking.trip = trip
    try? context.save()

    let now = date(2026, 9, 1)
    let reminders = DataManager.computeReminders(for: trip, now: now)

    let checkIn = reminders.first(where: { $0.type == .hotelCheckIn })
    #expect(checkIn != nil)
    #expect(checkIn!.body.contains("Grand Hotel Berlin"))
    let checkInComps = calendar.dateComponents([.month, .day, .hour], from: checkIn!.fireDate)
    #expect(checkInComps.month == 10)
    #expect(checkInComps.day == 1)
    #expect(checkInComps.hour == 14)

    let checkOut = reminders.first(where: { $0.type == .hotelCheckOut })
    #expect(checkOut != nil)
    let checkOutComps = calendar.dateComponents([.month, .day, .hour], from: checkOut!.fireDate)
    #expect(checkOutComps.month == 10)
    #expect(checkOutComps.day == 5)
    #expect(checkOutComps.hour == 9)
}

@Test func remindersPastEventsFiltered() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Old Trip", destination: "London", startDate: date(2025, 1, 1), endDate: date(2025, 1, 5))

    let booking = BookingEntity.create(in: context, type: .flight, title: "BA 100")
    booking.departureTime = calendar.date(from: DateComponents(year: 2025, month: 1, day: 1, hour: 10))
    booking.trip = trip
    try? context.save()

    // "now" is after everything
    let now = date(2026, 1, 1)
    let reminders = DataManager.computeReminders(for: trip, now: now)

    #expect(reminders.isEmpty)
}

@Test func remindersSortedByFireDate() {
    let context = makeTestContext()
    let manager = DataManager(context: context)
    let trip = manager.createTrip(name: "Sorted", destination: "Rome", startDate: date(2026, 11, 10), endDate: date(2026, 11, 15))

    // Hotel check-in on Nov 10, flight on Nov 10 at 8 AM
    let flight = BookingEntity.create(in: context, type: .flight, title: "Flight")
    flight.departureTime = calendar.date(from: DateComponents(year: 2026, month: 11, day: 10, hour: 8))
    flight.trip = trip

    let hotel = BookingEntity.create(in: context, type: .hotel, title: "Hotel")
    hotel.hotelName = "Rome Hotel"
    hotel.checkInDate = date(2026, 11, 10)
    hotel.checkOutDate = date(2026, 11, 15)
    hotel.trip = trip
    try? context.save()

    let now = date(2026, 10, 1)
    let reminders = DataManager.computeReminders(for: trip, now: now)

    #expect(reminders.count >= 3)
    // Verify sorted by fireDate
    for i in 0..<(reminders.count - 1) {
        #expect(reminders[i].fireDate <= reminders[i + 1].fireDate)
    }
}

// MARK: - Display Status (Date-Derived)

@Test("displayStatus returns .active for trip whose date range includes today")
func displayStatusActive() {
    let context = makeTestContext()
    let today = Date()
    let start = calendar.date(byAdding: .day, value: -1, to: today)!
    let end = calendar.date(byAdding: .day, value: 2, to: today)!
    let (trip, _) = makeTripWithDays(in: context, start: start, end: end)

    #expect(trip.displayStatus == .active)
}

@Test("displayStatus returns .planning for future trip")
func displayStatusFuture() {
    let context = makeTestContext()
    let start = calendar.date(byAdding: .day, value: 30, to: Date())!
    let end = calendar.date(byAdding: .day, value: 35, to: Date())!
    let (trip, _) = makeTripWithDays(in: context, start: start, end: end)

    #expect(trip.displayStatus == .planning)
}

@Test("displayStatus returns .completed for past trip")
func displayStatusPast() {
    let context = makeTestContext()
    let start = date(2024, 1, 1)
    let end = date(2024, 1, 5)
    let (trip, _) = makeTripWithDays(in: context, start: start, end: end)

    #expect(trip.displayStatus == .completed)
}

@Test("displayStatus ignores stored statusRaw and uses dates")
func displayStatusIgnoresStoredStatus() {
    let context = makeTestContext()
    let today = Date()
    let start = calendar.date(byAdding: .day, value: -1, to: today)!
    let end = calendar.date(byAdding: .day, value: 2, to: today)!
    let (trip, _) = makeTripWithDays(in: context, start: start, end: end)

    // Force stored status to planning — displayStatus should still say active
    trip.statusRaw = "planning"
    #expect(trip.displayStatus == .active)
}

@Test("displayStatus returns .planning for trip without custom dates")
func displayStatusWithoutDates() {
    let context = makeTestContext()
    let trip = TripEntity(context: context)
    trip.id = UUID()
    trip.name = "No Dates Trip"
    trip.destination = "Somewhere"
    trip.hasCustomDates = false
    trip.startDate = Date()
    trip.endDate = Date()
    trip.createdAt = Date()
    trip.updatedAt = Date()
    trip.budgetAmount = 0
    trip.budgetCurrencyCode = "USD"
    try? context.save()

    #expect(trip.displayStatus == .planning)
}

// MARK: - Booking Fields (Unified Stops)

@Test("Booking fields default to nil on plain stops")
func bookingFieldsDefaultNil() {
    let context = makeTestContext()
    let stop = StopEntity.create(in: context, name: "Museum", latitude: 0, longitude: 0, category: .attraction)
    try? context.save()

    #expect(stop.confirmationCode == nil)
    #expect(stop.checkOutDate == nil)
    #expect(stop.airline == nil)
    #expect(stop.flightNumber == nil)
    #expect(stop.departureAirport == nil)
    #expect(stop.arrivalAirport == nil)
    #expect(stop.hasBookingDetails == false)
}

@Test("Accommodation stop with checkOutDate has correct nightCount")
func accommodationNightCount() {
    let context = makeTestContext()
    let (trip, days) = makeTripWithDays(in: context, start: date(2025, 6, 1), end: date(2025, 6, 5))
    let day1 = days[0]

    let stop = StopEntity.create(in: context, name: "Hotel A", latitude: 35.6, longitude: 139.7, category: .accommodation)
    stop.confirmationCode = "ABC123"
    stop.checkOutDate = date(2025, 6, 4)
    stop.day = day1
    try? context.save()

    #expect(stop.hasBookingDetails == true)
    #expect(stop.isMultiDayAccommodation == true)
    #expect(stop.nightCount == 3)
    #expect(stop.wrappedConfirmationCode == "ABC123")
}

@Test("Transport stop with flight details has hasBookingDetails == true")
func transportBookingDetails() {
    let context = makeTestContext()
    let stop = StopEntity.create(in: context, name: "Flight to Tokyo", latitude: 0, longitude: 0, category: .transport)
    stop.confirmationCode = "XYZ789"
    stop.airline = "ANA"
    stop.flightNumber = "NH105"
    stop.departureAirport = "LAX"
    stop.arrivalAirport = "NRT"
    try? context.save()

    #expect(stop.hasBookingDetails == true)
    #expect(stop.airline == "ANA")
    #expect(stop.flightNumber == "NH105")
    #expect(stop.departureAirport == "LAX")
    #expect(stop.arrivalAirport == "NRT")
}

@Test("Accommodation without checkOutDate is single-day (nightCount == nil)")
func accommodationSingleDay() {
    let context = makeTestContext()
    let (_, days) = makeTripWithDays(in: context, start: date(2025, 6, 1), end: date(2025, 6, 3))

    let stop = StopEntity.create(in: context, name: "Hostel B", latitude: 48.8, longitude: 2.3, category: .accommodation)
    stop.day = days[0]
    try? context.save()

    #expect(stop.isMultiDayAccommodation == false)
    #expect(stop.nightCount == nil)
}

@Test("StopTransfer round-trip preserves booking fields")
func stopTransferRoundTrip() throws {
    let transfer = StopTransfer(
        name: "Hotel Test",
        latitude: 35.6,
        longitude: 139.7,
        arrivalTime: nil,
        departureTime: nil,
        categoryRaw: "accommodation",
        notes: "",
        sortOrder: 0,
        isVisited: false,
        visitedAt: nil,
        rating: 0,
        address: nil,
        phone: nil,
        website: nil,
        comments: [],
        links: [],
        todos: [],
        confirmationCode: "CONF123",
        checkOutDate: date(2025, 7, 5),
        airline: nil,
        flightNumber: nil,
        departureAirport: nil,
        arrivalAirport: nil
    )

    let encoder = JSONEncoder()
    encoder.dateEncodingStrategy = .iso8601
    let data = try encoder.encode(transfer)

    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(StopTransfer.self, from: data)

    #expect(decoded.confirmationCode == "CONF123")
    #expect(decoded.checkOutDate != nil)
    #expect(decoded.airline == nil)
}

@Test("Old StopTransfer JSON (pre-v2) decodes with nil booking defaults")
func oldStopTransferDecodes() throws {
    // JSON with v1 fields but no booking fields — simulates a pre-v2 file
    let json = """
    {
        "name": "Old Stop",
        "latitude": 0,
        "longitude": 0,
        "categoryRaw": "attraction",
        "notes": "",
        "sortOrder": 0,
        "isVisited": false,
        "rating": 0,
        "comments": [],
        "links": [],
        "todos": []
    }
    """
    let data = Data(json.utf8)
    let decoder = JSONDecoder()
    decoder.dateDecodingStrategy = .iso8601
    let decoded = try decoder.decode(StopTransfer.self, from: data)

    #expect(decoded.name == "Old Stop")
    #expect(decoded.confirmationCode == nil)
    #expect(decoded.checkOutDate == nil)
    #expect(decoded.airline == nil)
    #expect(decoded.flightNumber == nil)
    #expect(decoded.departureAirport == nil)
    #expect(decoded.arrivalAirport == nil)
}

// MARK: - Exhaustive Round-Trip Coverage

/// Verifies that EVERY field stored in the .tripwit format survives a full
/// export → decode → import cycle without loss or mutation.
/// If you add a new field to the schema, add a corresponding assertion here.
@Test func fullTripExportImportPreservesEverything() throws {
    let context = makeTestContext()
    let manager = DataManager(context: context)

    // ── Trip ──────────────────────────────────────────────────────────────
    let start  = date(2026, 9, 10)
    let end    = date(2026, 9, 14)
    let trip   = manager.createTrip(
        name:        "Everything Trip",
        destination: "Kyoto, Japan",
        startDate:   start,
        endDate:     end,
        notes:       "Full round-trip test"
    )
    trip.statusRaw       = "active"
    trip.hasCustomDates  = true
    trip.budgetAmount    = 2500.0
    trip.budgetCurrencyCode = "JPY"

    // ── Day with coordinates & notes ─────────────────────────────────────
    let days = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }
    let day1 = days[0]
    day1.notes             = "Day one notes"
    day1.location          = "Fushimi, Kyoto"
    day1.locationLatitude  = 34.9671
    day1.locationLongitude = 135.7727

    // ── Stop with every possible field ───────────────────────────────────
    let arrTime = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 9,  minute: 0))!
    let depTime = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 11, minute: 30))!
    let stop = manager.addStop(
        to:       day1,
        name:     "Fushimi Inari Taisha",
        latitude: 34.9671,
        longitude: 135.7727,
        category: .attraction,
        notes:    "Thousands of torii gates"
    )
    stop.arrivalTime   = arrTime
    stop.departureTime = depTime
    stop.sortOrder     = 3
    stop.isVisited     = true
    stop.visitedAt     = date(2026, 9, 10)
    stop.rating        = 5
    stop.address       = "68 Fukakusa Yabunouchicho, Fushimi"
    stop.phone         = "+81 75-641-7331"
    stop.website       = "https://inari.jp"
    // Booking fields on stop
    stop.confirmationCode = "INARI-99"
    stop.checkOutDate     = date(2026, 9, 12)
    stop.airline          = "Japan Airlines"
    stop.flightNumber     = "JL007"
    stop.departureAirport = "LAX"
    stop.arrivalAirport   = "KIX"

    // Stop todo (completed)
    let todo1 = StopTodoEntity.create(in: context, text: "Get the stamp", sortOrder: 0)
    todo1.isCompleted = true
    todo1.stop = stop
    // Stop todo (not completed)
    let todo2 = StopTodoEntity.create(in: context, text: "Buy omamori", sortOrder: 1)
    todo2.isCompleted = false
    todo2.stop = stop

    // Stop link
    let link = StopLinkEntity.create(in: context, title: "Official site", url: "https://inari.jp/en/", sortOrder: 7)
    link.stop = stop

    // Stop comment with a specific createdAt
    let commentDate = calendar.date(from: DateComponents(year: 2026, month: 8, day: 1, hour: 14, minute: 0))!
    let comment = CommentEntity.create(in: context, text: "One of the best places in Kyoto")
    comment.createdAt = commentDate
    comment.stop = stop

    // ── Legacy Booking ────────────────────────────────────────────────────
    let depT = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 10))!
    let arrT = calendar.date(from: DateComponents(year: 2026, month: 9, day: 10, hour: 15))!
    let booking = BookingEntity.create(
        in: context,
        type: .flight,
        title: "JL 7 to KIX",
        confirmationCode: "JLCONF",
        notes: "Window seat",
        sortOrder: 0
    )
    booking.airline          = "Japan Airlines"
    booking.flightNumber     = "JL007"
    booking.departureAirport = "LAX"
    booking.arrivalAirport   = "KIX"
    booking.departureTime    = depT
    booking.arrivalTime      = arrT
    booking.trip             = trip

    let hotel = BookingEntity.create(
        in: context,
        type: .hotel,
        title: "Kyoto Inn",
        confirmationCode: "HTLCONF",
        notes: "Late check-in requested"
    )
    hotel.hotelName    = "Kyoto Grand Inn"
    hotel.hotelAddress = "1 Kawaramachi, Kyoto"
    hotel.checkInDate  = date(2026, 9, 10)
    hotel.checkOutDate = date(2026, 9, 14)
    hotel.trip         = trip

    // ── Packing List ──────────────────────────────────────────────────────
    let list = TripListEntity.create(in: context, name: "Packing", icon: "bag.fill", sortOrder: 2)
    list.trip = trip
    let item1 = TripListItemEntity.create(in: context, text: "Passport",  sortOrder: 0)
    item1.isChecked = true
    item1.list = list
    let item2 = TripListItemEntity.create(in: context, text: "Rail Pass", sortOrder: 1)
    item2.isChecked = false
    item2.list = list

    // ── Expense ───────────────────────────────────────────────────────────
    let expenseCreatedAt = calendar.date(from: DateComponents(year: 2026, month: 7, day: 15, hour: 9))!
    let expense = manager.addExpense(
        to: trip,
        title: "Train ticket",
        amount: 1200.0,
        category: .transport
    )
    expense.currencyCode  = "JPY"
    expense.notes         = "Shinkansen"
    expense.sortOrder     = 4
    expense.createdAt     = expenseCreatedAt   // will be lost without the fix

    try? context.save()

    // ── Export → Import ───────────────────────────────────────────────────
    let fileURL = try TripShareService.exportTrip(trip)
    defer { try? FileManager.default.removeItem(at: fileURL) }
    let transfer = try TripShareService.decodeTrip(from: fileURL)
    let ctx2 = makeTestContext()
    let imp = TripShareService.importTrip(transfer, into: ctx2)

    // ── Trip fields ───────────────────────────────────────────────────────
    #expect(imp.wrappedName           == "Everything Trip")
    #expect(imp.wrappedDestination    == "Kyoto, Japan")
    #expect(imp.wrappedNotes          == "Full round-trip test")
    #expect(imp.wrappedStatusRaw      == "active")
    #expect(imp.hasCustomDates        == true)
    #expect(imp.budgetAmount          == 2500.0)
    #expect(imp.wrappedBudgetCurrencyCode == "JPY")
    #expect(imp.wrappedStartDate.timeIntervalSince1970 == start.timeIntervalSince1970)
    #expect(imp.wrappedEndDate.timeIntervalSince1970   == end.timeIntervalSince1970)

    // ── Day fields ────────────────────────────────────────────────────────
    let impDays = imp.daysArray.sorted { $0.dayNumber < $1.dayNumber }
    #expect(impDays.count == 5)
    let impDay1 = impDays[0]
    #expect(impDay1.wrappedNotes          == "Day one notes")
    #expect(impDay1.wrappedLocation       == "Fushimi, Kyoto")
    #expect(impDay1.locationLatitude      == 34.9671)
    #expect(impDay1.locationLongitude     == 135.7727)
    #expect(impDay1.dayNumber             == 1)

    // ── Stop fields ───────────────────────────────────────────────────────
    #expect(impDay1.stopsArray.count == 1)
    let s = impDay1.stopsArray.first!
    #expect(s.wrappedName      == "Fushimi Inari Taisha")
    #expect(s.latitude         == 34.9671)
    #expect(s.longitude        == 135.7727)
    #expect(s.category         == .attraction)
    #expect(s.wrappedNotes     == "Thousands of torii gates")
    #expect(s.sortOrder        == 3)
    #expect(s.isVisited        == true)
    #expect(s.visitedAt?.timeIntervalSince1970 == date(2026, 9, 10).timeIntervalSince1970)
    #expect(s.rating           == 5)
    #expect(s.address          == "68 Fukakusa Yabunouchicho, Fushimi")
    #expect(s.phone            == "+81 75-641-7331")
    #expect(s.website          == "https://inari.jp")
    #expect(s.arrivalTime?.timeIntervalSince1970   == arrTime.timeIntervalSince1970)
    #expect(s.departureTime?.timeIntervalSince1970 == depTime.timeIntervalSince1970)

    // Stop booking fields
    #expect(s.confirmationCode == "INARI-99")
    #expect(s.checkOutDate?.timeIntervalSince1970 == date(2026, 9, 12).timeIntervalSince1970)
    #expect(s.airline          == "Japan Airlines")
    #expect(s.flightNumber     == "JL007")
    #expect(s.departureAirport == "LAX")
    #expect(s.arrivalAirport   == "KIX")

    // ── Stop todos ────────────────────────────────────────────────────────
    let todos = s.todosArray.sorted { $0.sortOrder < $1.sortOrder }
    #expect(todos.count == 2)
    #expect(todos[0].wrappedText   == "Get the stamp")
    #expect(todos[0].isCompleted   == true)
    #expect(todos[0].sortOrder     == 0)
    #expect(todos[1].wrappedText   == "Buy omamori")
    #expect(todos[1].isCompleted   == false)
    #expect(todos[1].sortOrder     == 1)

    // ── Stop links ────────────────────────────────────────────────────────
    let links = s.linksArray
    #expect(links.count == 1)
    #expect(links[0].wrappedTitle  == "Official site")
    #expect(links[0].wrappedURL    == "https://inari.jp/en/")
    #expect(links[0].sortOrder     == 7)

    // ── Stop comments ─────────────────────────────────────────────────────
    let comments = s.commentsArray
    #expect(comments.count == 1)
    #expect(comments[0].wrappedText == "One of the best places in Kyoto")
    #expect(comments[0].createdAt?.timeIntervalSince1970 == commentDate.timeIntervalSince1970)

    // ── Legacy bookings ───────────────────────────────────────────────────
    let bks = imp.bookingsArray.sorted { $0.sortOrder < $1.sortOrder }
    #expect(bks.count == 2)
    let flight = bks.first(where: { $0.wrappedTypeRaw == "flight" })!
    #expect(flight.wrappedTitle          == "JL 7 to KIX")
    #expect(flight.wrappedConfirmationCode == "JLCONF")
    #expect(flight.wrappedNotes          == "Window seat")
    #expect(flight.airline               == "Japan Airlines")
    #expect(flight.flightNumber          == "JL007")
    #expect(flight.departureAirport      == "LAX")
    #expect(flight.arrivalAirport        == "KIX")
    #expect(flight.departureTime?.timeIntervalSince1970 == depT.timeIntervalSince1970)
    #expect(flight.arrivalTime?.timeIntervalSince1970   == arrT.timeIntervalSince1970)
    let htl = bks.first(where: { $0.wrappedTypeRaw == "hotel" })!
    #expect(htl.wrappedTitle      == "Kyoto Inn")
    #expect(htl.wrappedConfirmationCode == "HTLCONF")
    #expect(htl.wrappedNotes      == "Late check-in requested")
    #expect(htl.hotelName         == "Kyoto Grand Inn")
    #expect(htl.hotelAddress      == "1 Kawaramachi, Kyoto")
    #expect(htl.checkInDate?.timeIntervalSince1970  == date(2026, 9, 10).timeIntervalSince1970)
    #expect(htl.checkOutDate?.timeIntervalSince1970 == date(2026, 9, 14).timeIntervalSince1970)

    // ── Packing list ──────────────────────────────────────────────────────
    #expect(imp.listsArray.count == 1)
    let impList = imp.listsArray.first!
    #expect(impList.wrappedName == "Packing")
    #expect(impList.wrappedIcon == "bag.fill")
    #expect(impList.sortOrder   == 2)
    let impItems = impList.itemsArray.sorted { $0.sortOrder < $1.sortOrder }
    #expect(impItems.count == 2)
    #expect(impItems[0].wrappedText == "Passport")
    #expect(impItems[0].isChecked   == true)
    #expect(impItems[0].sortOrder   == 0)
    #expect(impItems[1].wrappedText == "Rail Pass")
    #expect(impItems[1].isChecked   == false)
    #expect(impItems[1].sortOrder   == 1)

    // ── Expense (including createdAt fix) ─────────────────────────────────
    #expect(imp.expensesArray.count == 1)
    let e = imp.expensesArray.first!
    #expect(e.wrappedTitle     == "Train ticket")
    #expect(e.amount           == 1200.0)
    #expect(e.wrappedCurrencyCode == "JPY")
    #expect(e.wrappedNotes     == "Shinkansen")
    #expect(e.sortOrder        == 4)
    #expect(e.createdAt?.timeIntervalSince1970 == expenseCreatedAt.timeIntervalSince1970)
}

} // end TripWitTests suite
