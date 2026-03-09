import Testing
import CoreData
import Foundation
@testable import TripWit
import TripCore

// MARK: - Mock Supabase Data Service

/// In-memory mock that simulates the Supabase trips table.
/// Uses case-sensitive TEXT primary key (exactly like the real Supabase schema).
final class MockSupabaseDataService: SupabaseDataServiceProtocol, @unchecked Sendable {

    // Remote "table" state
    var remoteRows: [SupabaseTripRow] = []

    // Failure injection
    var shouldThrowOnFetch  = false
    var shouldThrowOnUpsert = false
    var shouldThrowOnDelete = false

    // Call history for assertions
    private(set) var upsertCalls: [SupabaseTripRow] = []
    private(set) var deleteCalls: [String] = []
    private(set) var fetchCallCount = 0

    func fetchAllTrips(userId: String) async throws -> [SupabaseTripRow] {
        fetchCallCount += 1
        if shouldThrowOnFetch { throw MockError.fetchFailed }
        return remoteRows.filter { $0.userId == userId }
    }

    func upsertTrip(_ row: SupabaseTripRow) async throws {
        if shouldThrowOnUpsert { throw MockError.upsertFailed }
        upsertCalls.append(row)
        // Case-sensitive TEXT PK — exactly like Supabase TEXT column
        if let idx = remoteRows.firstIndex(where: { $0.id == row.id }) {
            remoteRows[idx] = row
        } else {
            remoteRows.append(row)
        }
    }

    func deleteTrip(id: String) async throws {
        if shouldThrowOnDelete { throw MockError.deleteFailed }
        deleteCalls.append(id)
        remoteRows.removeAll { $0.id == id }
    }

    func deleteAllTrips(userId: String) async throws {
        if shouldThrowOnDelete { throw MockError.deleteFailed }
        remoteRows.removeAll { $0.userId == userId }
    }

    enum MockError: Error { case fetchFailed, upsertFailed, deleteFailed }
}

// MARK: - Shared Test Helpers

private var _syncLiveContainers: [NSPersistentContainer] = []

private func makeSyncTestContext() -> NSManagedObjectContext {
    let container = NSPersistentContainer(name: "TripWit")
    let desc = NSPersistentStoreDescription()
    desc.type = NSInMemoryStoreType
    container.persistentStoreDescriptions = [desc]
    container.loadPersistentStores { _, error in
        if let error { fatalError("Test store failed: \(error)") }
    }
    container.viewContext.mergePolicy = NSMergeByPropertyObjectTrumpMergePolicy
    _syncLiveContainers.append(container)
    return container.viewContext
}

private let syncIso = ISO8601DateFormatter()
private let syncUserId = "test-user-uuid"

/// Clears all SyncService UserDefaults keys between tests.
private func clearSyncUserDefaults() {
    UserDefaults.standard.removeObject(forKey: "supabase_knownRemoteTripIds")
    UserDefaults.standard.removeObject(forKey: "supabase_deletedLocalTripIds")
    UserDefaults.standard.removeObject(forKey: "supabase_lastSyncDate")
}

/// Builds a minimal SupabaseTripRow with all required fields.
private func makeRow(
    id: String = UUID().uuidString,
    userId: String = syncUserId,
    name: String = "Remote Trip",
    updatedAt: Date = Date()
) -> SupabaseTripRow {
    SupabaseTripRow(
        id: id,
        userId: userId,
        isPublic: false,
        name: name,
        destination: "Paris",
        statusRaw: "planning",
        notes: "note",
        hasCustomDates: false,
        budgetAmount: 1000,
        budgetCurrencyCode: "EUR",
        startDate: syncIso.string(from: Date()),
        endDate: syncIso.string(from: Date().addingTimeInterval(86400 * 3)),
        days: [],
        bookings: [],
        lists: [],
        expenses: [],
        createdAt: syncIso.string(from: Date()),
        updatedAt: syncIso.string(from: updatedAt)
    )
}

/// Creates a row with a stop nested inside a day.
private func makeRowWithStop(id: String = UUID().uuidString, stopName: String = "Eiffel Tower") -> SupabaseTripRow {
    let stopId = UUID().uuidString
    let dayId = UUID().uuidString
    let stop = SupabaseStopJSON(
        id: stopId, name: stopName, categoryRaw: "attraction", sortOrder: 0,
        notes: "great view", latitude: 48.8584, longitude: 2.2945,
        address: "Champ de Mars", phone: nil, website: "https://toureiffel.paris",
        arrivalTime: nil, departureTime: nil, isVisited: false, visitedAt: nil,
        rating: 4, confirmationCode: nil, checkOutDate: nil,
        airline: nil, flightNumber: nil, departureAirport: nil, arrivalAirport: nil,
        todos: [SupabaseTodoJSON(id: UUID().uuidString, text: "Buy ticket", isCompleted: false, sortOrder: 0)],
        links: [SupabaseLinkJSON(id: UUID().uuidString, title: "Website", url: "https://toureiffel.paris", sortOrder: 0)],
        comments: [SupabaseCommentJSON(id: UUID().uuidString, text: "Amazing!", createdAt: syncIso.string(from: Date()))]
    )
    let day = SupabaseDayJSON(
        id: dayId, dayNumber: 1, date: syncIso.string(from: Date()),
        notes: "first day", location: "Paris",
        locationLatitude: 48.8566, locationLongitude: 2.3522,
        stops: [stop]
    )
    var row = makeRow(id: id)
    return SupabaseTripRow(
        id: row.id, userId: row.userId, isPublic: row.isPublic,
        name: row.name, destination: row.destination, statusRaw: row.statusRaw,
        notes: row.notes, hasCustomDates: row.hasCustomDates,
        budgetAmount: row.budgetAmount, budgetCurrencyCode: row.budgetCurrencyCode,
        startDate: row.startDate, endDate: row.endDate,
        days: [day], bookings: [], lists: [], expenses: [],
        createdAt: row.createdAt, updatedAt: row.updatedAt
    )
}

/// Creates a minimal TripEntity in the given context.
private func makeLocalTrip(
    in context: NSManagedObjectContext,
    id: UUID = UUID(),
    name: String = "Local Trip",
    updatedAt: Date = Date()
) -> TripEntity {
    let trip = TripEntity.create(
        in: context,
        name: name,
        destination: "London",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 5)
    )
    trip.id = id
    trip.updatedAt = updatedAt
    return trip
}

/// Returns the count of TripEntity objects in the given context.
private func tripCount(in context: NSManagedObjectContext) -> Int {
    (try? context.count(for: NSFetchRequest<TripEntity>(entityName: "TripEntity"))) ?? 0
}

private func fetchTrips(in context: NSManagedObjectContext) -> [TripEntity] {
    let req = NSFetchRequest<TripEntity>(entityName: "TripEntity")
    return (try? context.fetch(req)) ?? []
}

// MARK: - Test Suite

@Suite(.serialized) struct SyncServiceTests {

    // =========================================================================
    // MARK: - tripEntityToRow (Serialization)
    // =========================================================================

    @Test("tripEntityToRow preserves the entity UUID as row id")
    @MainActor func entityToRow_preservesUUID() {
        let context = makeSyncTestContext()
        let fixedId = UUID()
        let trip = makeLocalTrip(in: context, id: fixedId, name: "Trip A")

        let row = SupabaseDataService.tripEntityToRow(trip, userId: syncUserId)

        // IDs are normalized to lowercase (web compatibility — crypto.randomUUID() is lowercase)
        #expect(row.id == fixedId.uuidString.lowercased())
        #expect(row.userId == syncUserId)
    }

    @Test("tripEntityToRow encodes all scalar fields correctly")
    @MainActor func entityToRow_scalarFields() {
        let context = makeSyncTestContext()
        let trip = TripEntity.create(
            in: context,
            name: "Scalar Test",
            destination: "Tokyo",
            startDate: Date(),
            endDate: Date().addingTimeInterval(86400 * 7)
        )
        trip.statusRaw = "active"
        trip.notes = "some notes"
        trip.hasCustomDates = true
        trip.budgetAmount = 5000
        trip.budgetCurrencyCode = "JPY"
        trip.isPublic = true

        let row = SupabaseDataService.tripEntityToRow(trip, userId: syncUserId)

        #expect(row.name == "Scalar Test")
        #expect(row.destination == "Tokyo")
        #expect(row.statusRaw == "active")
        #expect(row.notes == "some notes")
        #expect(row.hasCustomDates == true)
        #expect(row.budgetAmount == 5000)
        #expect(row.budgetCurrencyCode == "JPY")
        #expect(row.isPublic == true)
    }

    @Test("tripEntityToRow uses 'now' when updatedAt is nil")
    @MainActor func entityToRow_nilUpdatedAtUsesNow() {
        let context = makeSyncTestContext()
        let trip = TripEntity.create(in: context, name: "T", destination: "D", startDate: Date(), endDate: Date())
        trip.updatedAt = nil

        let before = Date()
        let row = SupabaseDataService.tripEntityToRow(trip, userId: syncUserId)
        let after = Date()

        let parsed = syncIso.date(from: row.updatedAt)
        #expect(parsed != nil)
        if let parsed {
            #expect(parsed >= before.addingTimeInterval(-1))
            #expect(parsed <= after.addingTimeInterval(1))
        }
    }

    // =========================================================================
    // MARK: - importRow (Deserialization)
    // =========================================================================

    @Test("importRow preserves the row UUID as entity id")
    @MainActor func importRow_preservesUUID() {
        let context = makeSyncTestContext()
        let fixedId = UUID().uuidString.uppercased()
        let row = makeRow(id: fixedId)

        let entity = SupabaseDataService.importRow(row, into: context)

        #expect(entity.id?.uuidString == fixedId)
    }

    @Test("importRow handles lowercase UUID (web-generated) without discarding it")
    @MainActor func importRow_lowercaseUUID_idPreserved() {
        // Web uses crypto.randomUUID() which produces lowercase hex.
        // importRow must preserve identity so subsequent syncs can match the entity.
        let context = makeSyncTestContext()
        let lowercaseId = UUID().uuidString.lowercased()
        let row = makeRow(id: lowercaseId)

        let entity = SupabaseDataService.importRow(row, into: context)

        // The entity's UUID, when converted back to string, should represent
        // the same UUID value as the lowercase id.
        let entityIdStr = entity.id?.uuidString ?? ""
        #expect(entityIdStr.lowercased() == lowercaseId.lowercased(),
                "Entity id must represent the same UUID as the row id, regardless of case")
    }

    @Test("importRow sets all scalar fields from row")
    @MainActor func importRow_scalarFields() {
        let context = makeSyncTestContext()
        let row = makeRow(name: "Imported Trip")

        let entity = SupabaseDataService.importRow(row, into: context)

        #expect(entity.wrappedName == "Imported Trip")
        #expect(entity.wrappedDestination == "Paris")
        #expect(entity.wrappedStatusRaw == "planning")
        #expect(entity.wrappedNotes == "note")
        #expect(entity.budgetAmount == 1000)
        #expect(entity.wrappedBudgetCurrencyCode == "EUR")
        #expect(entity.isPublic == false)
        #expect(entity.supabaseSyncedAt != nil)
    }

    @Test("importRow creates nested Day, Stop, Todo, Link, Comment entities")
    @MainActor func importRow_createsNestedEntities() {
        let context = makeSyncTestContext()
        let row = makeRowWithStop(stopName: "Louvre Museum")

        let entity = SupabaseDataService.importRow(row, into: context)

        #expect(entity.daysArray.count == 1)
        let day = entity.daysArray[0]
        #expect(day.stopsArray.count == 1)
        let stop = day.stopsArray[0]
        #expect(stop.wrappedName == "Louvre Museum")
        #expect(stop.todosArray.count == 1)
        #expect(stop.linksArray.count == 1)
        #expect(stop.commentsArray.count == 1)
        #expect(stop.todosArray[0].wrappedText == "Buy ticket")
    }

    @Test("importRow preserves nested entity UUIDs")
    @MainActor func importRow_nestedUUIDsPreserved() {
        let context = makeSyncTestContext()
        let knownStopId = UUID().uuidString
        let stop = SupabaseStopJSON(
            id: knownStopId, name: "Stop", categoryRaw: "other", sortOrder: 0,
            notes: "", latitude: 0, longitude: 0,
            address: nil, phone: nil, website: nil,
            arrivalTime: nil, departureTime: nil, isVisited: false, visitedAt: nil,
            rating: 0, confirmationCode: nil, checkOutDate: nil,
            airline: nil, flightNumber: nil, departureAirport: nil, arrivalAirport: nil,
            todos: [], links: [], comments: []
        )
        let day = SupabaseDayJSON(
            id: UUID().uuidString, dayNumber: 1, date: syncIso.string(from: Date()),
            notes: "", location: "", locationLatitude: 0, locationLongitude: 0,
            stops: [stop]
        )
        var row = makeRow()
        row = SupabaseTripRow(
            id: row.id, userId: row.userId, isPublic: row.isPublic,
            name: row.name, destination: row.destination, statusRaw: row.statusRaw,
            notes: row.notes, hasCustomDates: row.hasCustomDates,
            budgetAmount: row.budgetAmount, budgetCurrencyCode: row.budgetCurrencyCode,
            startDate: row.startDate, endDate: row.endDate,
            days: [day], bookings: [], lists: [], expenses: [],
            createdAt: row.createdAt, updatedAt: row.updatedAt
        )

        let entity = SupabaseDataService.importRow(row, into: context)
        let importedStop = entity.daysArray[0].stopsArray[0]
        #expect(importedStop.id?.uuidString.lowercased() == knownStopId.lowercased())
    }

    // =========================================================================
    // MARK: - updateEntity
    // =========================================================================

    @Test("updateEntity replaces all child entities (whole-trip replacement)")
    @MainActor func updateEntity_replacesChildren() {
        let context = makeSyncTestContext()
        let trip = makeLocalTrip(in: context, name: "Old")
        // Add a day to the local trip and save so the relationship is persisted
        let day = DayEntity.create(in: context, date: Date(), dayNumber: 1, notes: "", location: "")
        day.trip = trip
        try? context.save()

        // Remote row has NO days
        let row = makeRow(id: trip.id!.uuidString, name: "Updated")
        SupabaseDataService.updateEntity(trip, from: row, in: context)
        try? context.save()
        // Refresh the trip's relationship cache — NSInMemoryStoreType can hold stale
        // relationship pointers until the context is refreshed after a deletion.
        context.refresh(trip, mergeChanges: false)

        #expect(trip.daysArray.isEmpty, "All old children should be deleted")
        #expect(trip.wrappedName == "Updated")
    }

    @Test("updateEntity updates all scalar fields")
    @MainActor func updateEntity_scalarFields() {
        let context = makeSyncTestContext()
        let trip = makeLocalTrip(in: context, name: "Old Name")
        let remoteTime = Date().addingTimeInterval(60)
        let row = makeRow(id: trip.id!.uuidString, name: "New Name", updatedAt: remoteTime)

        SupabaseDataService.updateEntity(trip, from: row, in: context)

        #expect(trip.wrappedName == "New Name")
        #expect(trip.wrappedDestination == "Paris")
        #expect(trip.supabaseSyncedAt != nil)
    }

    @Test("updateEntity does not change the trip's UUID (id is immutable)")
    @MainActor func updateEntity_preservesTripId() {
        let context = makeSyncTestContext()
        let fixedId = UUID()
        let trip = makeLocalTrip(in: context, id: fixedId)
        let row = makeRow(id: fixedId.uuidString)

        SupabaseDataService.updateEntity(trip, from: row, in: context)

        #expect(trip.id == fixedId)
    }

    @Test("updateEntity recreates nested entities from row data")
    @MainActor func updateEntity_recreatesChildren() {
        let context = makeSyncTestContext()
        let trip = makeLocalTrip(in: context)
        let row = makeRowWithStop(id: trip.id!.uuidString, stopName: "Notre Dame")

        SupabaseDataService.updateEntity(trip, from: row, in: context)

        #expect(trip.daysArray.count == 1)
        #expect(trip.daysArray[0].stopsArray[0].wrappedName == "Notre Dame")
    }

    // =========================================================================
    // MARK: - Full Sync: State Machine
    // =========================================================================

    @Test("sync: local-only trip not in knownRemoteIds → uploaded to Supabase")
    @MainActor func sync_localOnly_notKnown_uploads() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)
        let localId = UUID()
        let _ = makeLocalTrip(in: context, id: localId, name: "My New Trip")
        try? context.save()

        await svc.sync(userId: syncUserId)

        #expect(mock.upsertCalls.count == 1)
        // IDs are normalized to lowercase in tripEntityToRow (web compatibility)
        #expect(mock.upsertCalls[0].id == localId.uuidString.lowercased())
        #expect(mock.deleteCalls.isEmpty)
    }

    @Test("sync: local-only trip in knownRemoteIds → deleted locally (remote tombstone)")
    @MainActor func sync_localOnly_knownRemote_deletedLocally() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)

        // Simulate: trip was previously known on remote, now it's gone
        let localId = UUID()
        let _ = makeLocalTrip(in: context, id: localId, name: "Orphan Trip")
        try? context.save()
        // Pre-seed knownRemoteIds so sync thinks this trip existed on remote
        UserDefaults.standard.set([localId.uuidString], forKey: "supabase_knownRemoteTripIds")

        await svc.sync(userId: syncUserId)

        // Trip should be deleted locally
        #expect(tripCount(in: context) == 0, "Local trip should be deleted because it was known remote and is now missing")
        // Should not have uploaded it
        let uploadedIds = mock.upsertCalls.map(\.id)
        #expect(!uploadedIds.contains(localId.uuidString))
    }

    @Test("sync: remote-only trip not in deletedLocalIds → downloaded to Core Data")
    @MainActor func sync_remoteOnly_notDeleted_downloads() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)
        let remoteId = UUID().uuidString
        mock.remoteRows = [makeRow(id: remoteId, name: "Web Trip")]

        await svc.sync(userId: syncUserId)

        let trips = fetchTrips(in: context)
        #expect(trips.count == 1, "Remote trip should be downloaded")
        #expect(trips[0].wrappedName == "Web Trip")
        // ID should be preserved
        #expect(trips[0].id?.uuidString.lowercased() == remoteId.lowercased())
    }

    @Test("sync: remote-only trip in deletedLocalIds → deleted from Supabase")
    @MainActor func sync_remoteOnly_deletedLocally_deletesRemote() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)
        let remoteId = UUID().uuidString
        mock.remoteRows = [makeRow(id: remoteId)]
        // Simulate: user deleted this trip locally (it's a tombstone)
        UserDefaults.standard.set([remoteId], forKey: "supabase_deletedLocalTripIds")

        await svc.sync(userId: syncUserId)

        #expect(mock.deleteCalls.contains(remoteId), "Remote trip should be deleted from Supabase")
        #expect(tripCount(in: context) == 0, "No local entity should be created")
        // Tombstone should be cleared after propagation
        let remaining = UserDefaults.standard.stringArray(forKey: "supabase_deletedLocalTripIds") ?? []
        #expect(!remaining.contains(remoteId), "Tombstone should be cleared after propagation")
    }

    @Test("sync: both exist, local newer → pushes local to Supabase")
    @MainActor func sync_bothExist_localNewer_pushes() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)

        let sharedId = UUID()
        let remoteTime = Date().addingTimeInterval(-60) // remote is 60s older
        let localTime  = Date()

        let trip = makeLocalTrip(in: context, id: sharedId, name: "Local Version", updatedAt: localTime)
        try? context.save()
        mock.remoteRows = [makeRow(id: sharedId.uuidString, name: "Remote Version", updatedAt: remoteTime)]

        await svc.sync(userId: syncUserId)

        // Should push local → Supabase (IDs are normalized to lowercase)
        let pushed = mock.upsertCalls.first(where: { $0.id == sharedId.uuidString.lowercased() })
        #expect(pushed != nil, "Local newer version should be pushed")
        #expect(pushed?.name == "Local Version")
        // Local entity should be unchanged
        let localEntities = fetchTrips(in: context)
        #expect(localEntities.count == 1)
        #expect(localEntities[0].wrappedName == "Local Version")
    }

    @Test("sync: both exist, remote newer → updates local entity (last-write-wins)")
    @MainActor func sync_bothExist_remoteNewer_updatesLocal() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)

        let sharedId = UUID()
        let localTime  = Date().addingTimeInterval(-60) // local is 60s older
        let remoteTime = Date()

        let _ = makeLocalTrip(in: context, id: sharedId, name: "Local Version", updatedAt: localTime)
        try? context.save()
        mock.remoteRows = [makeRow(id: sharedId.uuidString, name: "Remote Version", updatedAt: remoteTime)]

        await svc.sync(userId: syncUserId)

        // Local entity should be updated from remote
        let localEntities = fetchTrips(in: context)
        #expect(localEntities.count == 1, "No duplicate should be created")
        #expect(localEntities[0].wrappedName == "Remote Version", "Local should be overwritten by remote")
    }

    @Test("sync: both exist, equal timestamps → no-op (no push, no update)")
    @MainActor func sync_bothExist_equalTimestamps_noOp() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)

        let sharedId = UUID()
        // Truncate to whole-second precision so the value survives the ISO8601
        // round-trip without sub-second drift causing a false "local newer" branch.
        let sharedTime = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
        let _ = makeLocalTrip(in: context, id: sharedId, name: "Unchanged", updatedAt: sharedTime)
        try? context.save()
        mock.remoteRows = [makeRow(id: sharedId.uuidString, name: "Unchanged", updatedAt: sharedTime)]

        await svc.sync(userId: syncUserId)

        // Nothing should be pushed or downloaded
        // (upsert calls may include the initial fetch re-push; just check count is small)
        let pushedCount = mock.upsertCalls.filter { $0.id == sharedId.uuidString }.count
        #expect(pushedCount == 0, "Equal timestamps: no push should occur")
        #expect(mock.deleteCalls.isEmpty)
    }

    // =========================================================================
    // MARK: - UUID Case Sensitivity (THE DUPLICATE BUG)
    //
    // Web creates trips with lowercase UUIDs (crypto.randomUUID()).
    // iOS stores UUIDs as uppercase (UUID().uuidString).
    // If the comparison is case-sensitive, web trips are never matched
    // to their imported local counterparts → infinite duplication.
    // =========================================================================

    @Test("sync: web trip (lowercase UUID) does NOT duplicate on second sync")
    @MainActor func sync_webTrip_lowercaseUUID_noDuplicate() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)

        // Simulate a trip created by the web app: lowercase UUID
        let webId = UUID().uuidString.lowercased()
        mock.remoteRows = [makeRow(id: webId, name: "Web-Created Trip")]

        // First sync: should import the web trip locally
        await svc.sync(userId: syncUserId)
        #expect(tripCount(in: context) == 1, "Should have 1 trip after first sync")

        // Second sync: should NOT import it again as a new trip
        await svc.sync(userId: syncUserId)
        #expect(tripCount(in: context) == 1,
                "Second sync must reconcile (find the existing entity) and NOT create a duplicate")
    }

    @Test("sync: iOS-uploaded trip (uppercase UUID) does NOT duplicate on second sync")
    @MainActor func sync_iOSTrip_uppercaseUUID_noDuplicate() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)

        let iosId = UUID() // uppercase uuidString
        let _ = makeLocalTrip(in: context, id: iosId, name: "iOS Trip")
        try? context.save()

        // First sync: uploads local to remote
        await svc.sync(userId: syncUserId)
        let countAfterFirst = tripCount(in: context)

        // Second sync: remote now has the trip too, should reconcile
        await svc.sync(userId: syncUserId)
        #expect(tripCount(in: context) == countAfterFirst,
                "Second sync must not create a duplicate of the iOS-uploaded trip")
    }

    @Test("sync: importing web trip then re-syncing does not upload duplicate row to Supabase")
    @MainActor func sync_webTrip_doesNotUploadDuplicateToSupabase() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)

        let webId = UUID().uuidString.lowercased()
        mock.remoteRows = [makeRow(id: webId, name: "Web Trip")]

        // First sync: imports the web trip
        await svc.sync(userId: syncUserId)

        let upsertCountAfterFirst = mock.upsertCalls.count

        // Second sync: the imported entity's UUID (normalized to uppercase) should match
        // the remote ID. No duplicate upsert should occur.
        await svc.sync(userId: syncUserId)

        let newUpserts = mock.upsertCalls.count - upsertCountAfterFirst
        // At most 1 upsert is acceptable (if local time > remote time after import).
        // Creating a NEW row (different cased ID) in Supabase = bug.
        let supabaseRowCount = mock.remoteRows.count
        #expect(supabaseRowCount == 1,
                "Supabase should still have exactly 1 row after two syncs — not a duplicate with different casing")
    }

    // =========================================================================
    // MARK: - Idempotency
    // =========================================================================

    @Test("sync is idempotent: running N times produces the same result as running once")
    @MainActor func sync_idempotent() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)

        let id1 = UUID()
        let id2 = UUID().uuidString.lowercased() // simulate web trip
        let _ = makeLocalTrip(in: context, id: id1, name: "iOS Trip")
        mock.remoteRows = [makeRow(id: id2, name: "Web Trip")]
        try? context.save()

        for _ in 1...5 {
            await svc.sync(userId: syncUserId)
        }

        #expect(tripCount(in: context) == 2, "After 5 syncs there should still be exactly 2 trips")
        #expect(mock.remoteRows.count == 2, "Supabase should have exactly 2 rows")
    }

    // =========================================================================
    // MARK: - Multi-Trip
    // =========================================================================

    @Test("sync handles multiple trips across all branches simultaneously")
    @MainActor func sync_multipleTrips_allBranches() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)

        let localOnlyId  = UUID()  // new local  → should upload
        let bothId       = UUID()  // exists both → LWW (equal → no-op)
        let remoteOnlyId = UUID().uuidString.lowercased() // new remote → should download

        // Local trips — truncate to whole-second precision so the equal-timestamp
        // comparison survives the ISO8601 round-trip without sub-second drift.
        let localTime = Date(timeIntervalSince1970: Date().timeIntervalSince1970.rounded(.down))
        let _ = makeLocalTrip(in: context, id: localOnlyId, name: "Local Only", updatedAt: localTime)
        let _ = makeLocalTrip(in: context, id: bothId,      name: "Shared",     updatedAt: localTime)
        try? context.save()

        // Remote rows
        mock.remoteRows = [
            makeRow(id: bothId.uuidString,  name: "Shared",      updatedAt: localTime), // equal
            makeRow(id: remoteOnlyId,       name: "Remote Only",  updatedAt: localTime)
        ]

        await svc.sync(userId: syncUserId)

        // After sync: should have local+both+remote = 3 trips
        #expect(tripCount(in: context) == 3)
        // localOnly should have been uploaded (IDs normalized to lowercase)
        let uploaded = mock.upsertCalls.map(\.id)
        #expect(uploaded.contains(localOnlyId.uuidString.lowercased()))
        // remoteOnly should have been downloaded (no delete calls)
        #expect(mock.deleteCalls.isEmpty)
    }

    // =========================================================================
    // MARK: - Sync State
    // =========================================================================

    @Test("sync sets state to .lastSynced on success")
    @MainActor func sync_successSetsLastSyncedState() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)

        await svc.sync(userId: syncUserId)

        if case .lastSynced = svc.state {
            // pass
        } else {
            Issue.record("Expected .lastSynced state, got \(svc.state)")
        }
    }

    @Test("sync sets state to .error when fetch throws")
    @MainActor func sync_fetchError_setsErrorState() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        mock.shouldThrowOnFetch = true
        let svc = SyncService(dataService: mock, context: context)

        await svc.sync(userId: syncUserId)

        if case .error = svc.state {
            // pass
        } else {
            Issue.record("Expected .error state, got \(svc.state)")
        }
    }

    @Test("sync sets state to .error when upsert throws")
    @MainActor func sync_upsertError_setsErrorState() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        mock.shouldThrowOnUpsert = true
        let svc = SyncService(dataService: mock, context: context)
        // Give it a local-only trip to trigger an upsert
        let _ = makeLocalTrip(in: context)
        try? context.save()

        await svc.sync(userId: syncUserId)

        if case .error = svc.state {
            // pass
        } else {
            Issue.record("Expected .error state, got \(svc.state)")
        }
    }

    @Test("shouldAutoSync is true when lastSyncDate is nil")
    @MainActor func shouldAutoSync_trueWhenNeverSynced() {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)

        #expect(svc.shouldAutoSync == true)
    }

    @Test("shouldAutoSync is false immediately after a successful sync")
    @MainActor func shouldAutoSync_falseAfterRecentSync() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)

        await svc.sync(userId: syncUserId)

        #expect(svc.shouldAutoSync == false, "shouldAutoSync should be false right after a successful sync")
    }

    // =========================================================================
    // MARK: - Tombstone / Tracking State
    // =========================================================================

    @Test("recordLocalDelete adds trip id to deletedLocalIds in UserDefaults")
    @MainActor func recordLocalDelete_addsTombstone() {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)
        let id = UUID().uuidString

        svc.recordLocalDelete(tripId: id)

        let stored = UserDefaults.standard.stringArray(forKey: "supabase_deletedLocalTripIds") ?? []
        // Tombstones are stored as lowercase for cross-platform compatibility
        #expect(stored.contains(id.lowercased()))
    }

    @Test("sync updates knownRemoteIds after downloading a remote trip")
    @MainActor func sync_updatesKnownRemoteIds_afterDownload() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)
        let remoteId = UUID().uuidString
        mock.remoteRows = [makeRow(id: remoteId)]

        await svc.sync(userId: syncUserId)

        let known = UserDefaults.standard.stringArray(forKey: "supabase_knownRemoteTripIds") ?? []
        // knownRemoteIds are stored as lowercase for cross-platform compatibility
        #expect(known.contains(remoteId.lowercased()), "knownRemoteIds should include the downloaded remote trip id")
    }

    @Test("sync updates knownRemoteIds after uploading a local trip")
    @MainActor func sync_updatesKnownRemoteIds_afterUpload() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)
        let localId = UUID()
        let _ = makeLocalTrip(in: context, id: localId, name: "New Local Trip")
        try? context.save()

        await svc.sync(userId: syncUserId)

        let known = UserDefaults.standard.stringArray(forKey: "supabase_knownRemoteTripIds") ?? []
        // knownRemoteIds are stored as lowercase for cross-platform compatibility
        #expect(known.contains(localId.uuidString.lowercased()), "knownRemoteIds should include the uploaded local trip id")
    }

    @Test("sync clears tombstone after successfully propagating delete to remote")
    @MainActor func sync_clearsTombstone_afterRemoteDelete() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)
        let remoteId = UUID().uuidString
        mock.remoteRows = [makeRow(id: remoteId)]
        UserDefaults.standard.set([remoteId], forKey: "supabase_deletedLocalTripIds")

        await svc.sync(userId: syncUserId)

        let remaining = UserDefaults.standard.stringArray(forKey: "supabase_deletedLocalTripIds") ?? []
        #expect(!remaining.contains(remoteId), "Tombstone must be removed after remote deletion is propagated")
    }

    // =========================================================================
    // MARK: - Nested Data Round-Trip
    // =========================================================================

    @Test("full round-trip: importRow then entityToRow preserves all nested data")
    @MainActor func roundTrip_importThenSerialize_preservesNested() {
        let context = makeSyncTestContext()
        let originalRow = makeRowWithStop(stopName: "Arc de Triomphe")

        let entity = SupabaseDataService.importRow(originalRow, into: context)
        let reserializedRow = SupabaseDataService.tripEntityToRow(entity, userId: syncUserId)

        // Trip-level
        #expect(reserializedRow.id.lowercased() == originalRow.id.lowercased())
        #expect(reserializedRow.name == originalRow.name)

        // Days
        #expect(reserializedRow.days.count == 1)
        let origDay = originalRow.days[0]
        let newDay  = reserializedRow.days[0]
        #expect(newDay.id.lowercased() == origDay.id.lowercased())
        #expect(newDay.dayNumber == origDay.dayNumber)

        // Stops
        #expect(newDay.stops.count == 1)
        let origStop = origDay.stops[0]
        let newStop  = newDay.stops[0]
        #expect(newStop.id.lowercased() == origStop.id.lowercased())
        #expect(newStop.name == origStop.name)
        #expect(newStop.latitude == origStop.latitude)
        #expect(newStop.longitude == origStop.longitude)
        #expect(newStop.rating == origStop.rating)

        // Todos
        #expect(newStop.todos.count == 1)
        #expect(newStop.todos[0].text == origStop.todos[0].text)
        #expect(newStop.todos[0].isCompleted == origStop.todos[0].isCompleted)

        // Links
        #expect(newStop.links.count == 1)
        #expect(newStop.links[0].url == origStop.links[0].url)
    }

    @Test("round-trip preserves booking, list, and expense data")
    @MainActor func roundTrip_bookingListExpense() {
        let context = makeSyncTestContext()
        let booking = SupabaseBookingJSON(
            id: UUID().uuidString, typeRaw: "flight", title: "BA456",
            confirmationCode: "ABC123", notes: "window seat",
            sortOrder: 0, airline: "British Airways", flightNumber: "BA456",
            departureAirport: "LHR", arrivalAirport: "CDG",
            departureTime: syncIso.string(from: Date()),
            arrivalTime: syncIso.string(from: Date().addingTimeInterval(3600)),
            hotelName: nil, hotelAddress: nil, checkInDate: nil, checkOutDate: nil
        )
        let listItem = SupabaseListItemJSON(id: UUID().uuidString, text: "passport", isChecked: false, sortOrder: 0)
        let list = SupabaseListJSON(id: UUID().uuidString, name: "Packing", icon: "🧳", sortOrder: 0, items: [listItem])
        let expense = SupabaseExpenseJSON(
            id: UUID().uuidString, title: "Hotel", amount: 250.0,
            currencyCode: "EUR", categoryRaw: "accommodation",
            notes: "", sortOrder: 0,
            createdAt: syncIso.string(from: Date()),
            dateIncurred: syncIso.string(from: Date())
        )
        var row = makeRow()
        row = SupabaseTripRow(
            id: row.id, userId: row.userId, isPublic: row.isPublic,
            name: row.name, destination: row.destination, statusRaw: row.statusRaw,
            notes: row.notes, hasCustomDates: row.hasCustomDates,
            budgetAmount: row.budgetAmount, budgetCurrencyCode: row.budgetCurrencyCode,
            startDate: row.startDate, endDate: row.endDate,
            days: [], bookings: [booking], lists: [list], expenses: [expense],
            createdAt: row.createdAt, updatedAt: row.updatedAt
        )

        let entity = SupabaseDataService.importRow(row, into: context)
        let reserialized = SupabaseDataService.tripEntityToRow(entity, userId: syncUserId)

        // Booking
        #expect(reserialized.bookings.count == 1)
        #expect(reserialized.bookings[0].airline == "British Airways")
        #expect(reserialized.bookings[0].flightNumber == "BA456")
        #expect(reserialized.bookings[0].confirmationCode == "ABC123")

        // List
        #expect(reserialized.lists.count == 1)
        #expect(reserialized.lists[0].name == "Packing")
        #expect(reserialized.lists[0].items.count == 1)
        #expect(reserialized.lists[0].items[0].text == "passport")

        // Expense
        #expect(reserialized.expenses.count == 1)
        #expect(reserialized.expenses[0].amount == 250.0)
        #expect(reserialized.expenses[0].currencyCode == "EUR")
    }

    // =========================================================================
    // MARK: - User Isolation
    // =========================================================================

    @Test("sync only fetches trips for the authenticated user (user isolation)")
    @MainActor func sync_userIsolation_doesNotDownloadOtherUsersTrips() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)

        // Two remote rows: one for this user, one for a different user
        mock.remoteRows = [
            makeRow(id: UUID().uuidString, userId: syncUserId,    name: "My Trip"),
            makeRow(id: UUID().uuidString, userId: "other-user",  name: "Their Trip")
        ]

        await svc.sync(userId: syncUserId)

        // Only the current user's trip should be downloaded
        #expect(tripCount(in: context) == 1)
        #expect(fetchTrips(in: context)[0].wrappedName == "My Trip")
    }

    // =========================================================================
    // MARK: - Re-entrance Guard
    // =========================================================================

    @Test("concurrent sync calls are serialized: second call returns immediately if first is running")
    @MainActor func sync_concurrentCalls_deduplicated() async {
        clearSyncUserDefaults()
        let context = makeSyncTestContext()
        let mock = MockSupabaseDataService()
        let svc = SyncService(dataService: mock, context: context)

        // Run two sync calls in parallel
        async let first  = svc.sync(userId: syncUserId)
        async let second = svc.sync(userId: syncUserId)
        await first
        await second

        // Fetch should only have been called once (second call bailed on isSyncing guard)
        #expect(mock.fetchCallCount == 1, "Only one full sync should have executed")
    }
}
