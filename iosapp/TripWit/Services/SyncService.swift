import Foundation
import CoreData
import os

@Observable
@MainActor
final class SyncService {

    // MARK: - State

    enum SyncState: Sendable, Equatable {
        case idle
        case syncing
        case error(String)
        case lastSynced(Date)
    }

    private(set) var state: SyncState = .idle

    private let dataService: SupabaseDataServiceProtocol
    private let context: NSManagedObjectContext
    private let log = Logger(subsystem: "com.kevinbuckley.travelplanner", category: "Sync")

    // Debounce tracking
    private var pendingSyncTask: Task<Void, Never>?

    /// The Supabase user ID, set when auth completes.
    var userId: String?

    nonisolated(unsafe) private var saveObserver: Any?
    /// Flag to prevent re-entrant sync when SyncService itself saves.
    private var isSyncing = false

    init(dataService: SupabaseDataServiceProtocol, context: NSManagedObjectContext) {
        self.dataService = dataService
        self.context = context
        observeContextSaves()
    }

    deinit {
        let observer = saveObserver
        if let observer {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    // MARK: - Auto-sync on Core Data saves

    private func observeContextSaves() {
        saveObserver = NotificationCenter.default.addObserver(
            forName: .NSManagedObjectContextDidSave,
            object: context,
            queue: .main
        ) { [weak self] notification in
            guard let self, !self.isSyncing, let userId = self.userId else { return }

            // Check if any TripEntity was modified
            let inserted = notification.userInfo?[NSInsertedObjectsKey] as? Set<NSManagedObject> ?? []
            let updated = notification.userInfo?[NSUpdatedObjectsKey] as? Set<NSManagedObject> ?? []
            let deleted = notification.userInfo?[NSDeletedObjectsKey] as? Set<NSManagedObject> ?? []

            // Record deleted trips
            for obj in deleted {
                if let trip = obj as? TripEntity, let id = trip.id?.uuidString {
                    self.recordLocalDelete(tripId: id)
                }
            }

            // Find any modified trip to push
            let changedTrips = (inserted.union(updated))
                .compactMap { obj -> TripEntity? in
                    if let trip = obj as? TripEntity { return trip }
                    if let day = obj as? DayEntity { return day.trip }
                    if let stop = obj as? StopEntity { return stop.day?.trip }
                    if let expense = obj as? ExpenseEntity { return expense.trip }
                    if let booking = obj as? BookingEntity { return booking.trip }
                    if let list = obj as? TripListEntity { return list.trip }
                    return nil
                }

            // Deduplicate and push each changed trip
            let uniqueTrips = Set(changedTrips.compactMap { $0.id })
            if !uniqueTrips.isEmpty {
                // Use the first modified trip for debounced push
                if let trip = changedTrips.first {
                    self.pushTrip(trip, userId: userId)
                }
            }
        }
    }

    // MARK: - UserDefaults keys

    private static let knownRemoteIdsKey = "supabase_knownRemoteTripIds"
    private static let deletedLocalIdsKey = "supabase_deletedLocalTripIds"
    private static let lastSyncDateKey = "supabase_lastSyncDate"

    // MARK: - Full Sync

    func sync(userId: String) async {
        guard !isSyncing else { return }
        isSyncing = true
        defer { isSyncing = false }
        state = .syncing
        log.info("Starting sync for user \(userId)")

        do {
            // 1. Fetch remote
            let remoteRows = try await dataService.fetchAllTrips(userId: userId)
            // Normalize IDs to lowercase — web uses crypto.randomUUID() (lowercase)
            // while Swift UUID().uuidString is uppercase. Lowercasing both sides
            // ensures they match, preventing duplicate imports on every sync.
            let remoteById = Dictionary(remoteRows.map { ($0.id.lowercased(), $0) }, uniquingKeysWith: { _, b in b })

            // 2. Fetch local
            let localTrips = fetchLocalTrips()
            let localById = Dictionary(
                localTrips.compactMap { trip -> (String, TripEntity)? in
                    guard let id = trip.id?.uuidString.lowercased() else { return nil }
                    return (id, trip)
                },
                uniquingKeysWith: { _, b in b }
            )

            // 3. Load tracking sets (normalize stored values to lowercase for consistency)
            let knownRemoteIds = Set(loadStringSet(key: Self.knownRemoteIdsKey).map { $0.lowercased() })
            var deletedLocalIds = Set(loadStringSet(key: Self.deletedLocalIdsKey).map { $0.lowercased() })

            // 4a. Local-only trips → upload (unless deleted remotely)
            for (localId, localTrip) in localById where remoteById[localId] == nil {
                if knownRemoteIds.contains(localId) {
                    // Was on remote last time, now missing → deleted remotely
                    log.info("Trip \(localId) deleted remotely, removing locally")
                    context.delete(localTrip)
                } else {
                    // New local trip → upload
                    log.info("Uploading local trip \(localId) to Supabase")
                    let row = SupabaseDataService.tripEntityToRow(localTrip, userId: userId)
                    try await dataService.upsertTrip(row)
                }
            }

            // 4b. Remote-only trips → download (unless deleted locally)
            for (remoteId, remoteRow) in remoteById where localById[remoteId] == nil {
                if deletedLocalIds.contains(remoteId) {
                    // Deleted locally → propagate delete to remote
                    // Use remoteRow.id (original case) so the Supabase eq() filter matches.
                    log.info("Trip \(remoteId) deleted locally, deleting from Supabase")
                    try await dataService.deleteTrip(id: remoteRow.id)
                    deletedLocalIds.remove(remoteId)
                } else {
                    // New remote trip → import
                    log.info("Downloading remote trip \(remoteId) into Core Data")
                    _ = SupabaseDataService.importRow(remoteRow, into: context)
                }
            }

            // 4c. Both sides → last-write-wins
            let iso = ISO8601DateFormatter()
            for (id, localTrip) in localById {
                guard let remoteRow = remoteById[id] else { continue }

                let localUpdated = localTrip.updatedAt ?? Date.distantPast
                let remoteUpdated = iso.date(from: remoteRow.updatedAt) ?? Date.distantPast

                if localUpdated > remoteUpdated {
                    log.info("Trip \(id): local newer, pushing to Supabase")
                    let row = SupabaseDataService.tripEntityToRow(localTrip, userId: userId)
                    try await dataService.upsertTrip(row)
                } else if remoteUpdated > localUpdated {
                    log.info("Trip \(id): remote newer, updating local")
                    SupabaseDataService.updateEntity(localTrip, from: remoteRow, in: context)
                }
                // Equal → no action
            }

            // 5. Save
            if context.hasChanges {
                try context.save()
            }

            // 6. Update tracking
            let currentRemoteIds = Set(remoteById.keys)
            let uploadedLocalOnlyIds = Set(localById.keys.filter { remoteById[$0] == nil && !knownRemoteIds.contains($0) })
            saveStringSet(currentRemoteIds.union(uploadedLocalOnlyIds), key: Self.knownRemoteIdsKey)
            saveStringSet(deletedLocalIds, key: Self.deletedLocalIdsKey)
            UserDefaults.standard.set(Date(), forKey: Self.lastSyncDateKey)

            state = .lastSynced(Date())
            log.info("Sync completed successfully")
        } catch {
            let message = error.localizedDescription
            state = .error(message)
            log.error("Sync failed: \(message)")
        }
    }

    // MARK: - Single-Trip Push (debounced)

    func pushTrip(_ trip: TripEntity, userId: String) {
        pendingSyncTask?.cancel()
        pendingSyncTask = Task {
            try? await Task.sleep(for: .seconds(3))
            guard !Task.isCancelled else { return }

            do {
                let row = SupabaseDataService.tripEntityToRow(trip, userId: userId)
                try await dataService.upsertTrip(row)
                trip.supabaseSyncedAt = Date()
                if context.hasChanges {
                    isSyncing = true
                    try? context.save()
                    isSyncing = false
                }
                log.info("Pushed trip \(trip.id?.uuidString ?? "?") to Supabase")
            } catch {
                log.error("Push failed: \(error.localizedDescription)")
            }
        }
    }

    // MARK: - Record Local Delete

    func recordLocalDelete(tripId: String) {
        var deleted = loadStringSet(key: Self.deletedLocalIdsKey)
        deleted.insert(tripId.lowercased())
        saveStringSet(deleted, key: Self.deletedLocalIdsKey)
    }

    // MARK: - Last Sync Date

    var lastSyncDate: Date? {
        UserDefaults.standard.object(forKey: Self.lastSyncDateKey) as? Date
    }

    var shouldAutoSync: Bool {
        guard let last = lastSyncDate else { return true }
        return Date().timeIntervalSince(last) > 300 // 5 minutes
    }

    // MARK: - Private Helpers

    private func fetchLocalTrips() -> [TripEntity] {
        let request = NSFetchRequest<TripEntity>(entityName: "TripEntity")
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TripEntity.updatedAt, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    private func loadStringSet(key: String) -> Set<String> {
        let array = UserDefaults.standard.stringArray(forKey: key) ?? []
        return Set(array)
    }

    private func saveStringSet(_ set: Set<String>, key: String) {
        UserDefaults.standard.set(Array(set), forKey: key)
    }
}
