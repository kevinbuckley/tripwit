import CoreData
import CloudKit

final class PersistenceController: ObservableObject {

    static let shared = PersistenceController()

    let container: NSPersistentCloudKitContainer
    let cloudContainer: CKContainer

    private static let containerIdentifier = "iCloud.com.kevinbuckley.travelplanner"
    private static let appTransactionAuthorName = "TripWit"

    /// Token for tracking which persistent history changes have been consumed.
    private var lastHistoryToken: NSPersistentHistoryToken? {
        get {
            guard let data = UserDefaults.standard.data(forKey: "PersistentHistoryToken") else { return nil }
            return try? NSKeyedUnarchiver.unarchivedObject(ofClass: NSPersistentHistoryToken.self, from: data)
        }
        set {
            if let newValue, let data = try? NSKeyedArchiver.archivedData(withRootObject: newValue, requiringSecureCoding: true) {
                UserDefaults.standard.set(data, forKey: "PersistentHistoryToken")
            }
        }
    }

    var viewContext: NSManagedObjectContext {
        container.viewContext
    }

    /// Keep references to store descriptions so we can identify private vs shared stores by URL.
    private var privateStoreURL: URL?
    private var sharedStoreURL: URL?

    init(inMemory: Bool = false) {
        container = NSPersistentCloudKitContainer(name: "TripWit")
        cloudContainer = CKContainer(identifier: Self.containerIdentifier)

        if inMemory {
            let desc = NSPersistentStoreDescription()
            desc.url = URL(fileURLWithPath: "/dev/null")
            container.persistentStoreDescriptions = [desc]
        } else {
            let storeDir = FileManager.default.urls(
                for: .applicationSupportDirectory,
                in: .userDomainMask
            ).first!

            // Clean up any old SwiftData .store files from before migration
            Self.cleanUpLegacyStores(in: storeDir)

            // Private store — user's own data
            let privateURL = storeDir.appending(path: "Private.sqlite")
            let privateDesc = NSPersistentStoreDescription(url: privateURL)
            // Do NOT set configuration — let all entities be available in both stores.
            // CloudKit dual-store requires entities in both private and shared stores.
            let privateOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Self.containerIdentifier
            )
            privateOptions.databaseScope = .private
            privateDesc.cloudKitContainerOptions = privateOptions
            privateDesc.setOption(true as NSNumber,
                                  forKey: NSPersistentHistoryTrackingKey)
            privateDesc.setOption(true as NSNumber,
                                  forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            // Shared store — data shared with/by others
            let sharedURL = storeDir.appending(path: "Shared.sqlite")
            let sharedDesc = NSPersistentStoreDescription(url: sharedURL)
            // Do NOT set configuration — same reason as above.
            let sharedOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Self.containerIdentifier
            )
            sharedOptions.databaseScope = .shared
            sharedDesc.cloudKitContainerOptions = sharedOptions
            sharedDesc.setOption(true as NSNumber,
                                 forKey: NSPersistentHistoryTrackingKey)
            sharedDesc.setOption(true as NSNumber,
                                 forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            container.persistentStoreDescriptions = [privateDesc, sharedDesc]
            privateStoreURL = privateURL
            sharedStoreURL = sharedURL
        }

        container.loadPersistentStores { description, error in
            if let error {
                print("Core Data store failed to load (\(description.url?.lastPathComponent ?? "unknown")): \(error)")
                // If a store fails to load, try to destroy it and reload.
                // This handles corrupted stores or stores left over from SwiftData migration.
                if let url = description.url {
                    print("Attempting to destroy and recreate store at \(url.lastPathComponent)")
                    try? FileManager.default.removeItem(at: url)
                    // Also remove WAL/SHM companions
                    try? FileManager.default.removeItem(at: url.appendingPathExtension("shm"))
                    try? FileManager.default.removeItem(at: url.appendingPathExtension("wal"))
                    let urlPath = url.path
                    try? FileManager.default.removeItem(atPath: urlPath + "-shm")
                    try? FileManager.default.removeItem(atPath: urlPath + "-wal")
                }
            }
        }

        // Use NSMergeByPropertyStoreTrumpMergePolicy so remote/server changes
        // take priority over local in-memory changes. This is correct for CloudKit sync
        // where the "truth" is what's on the server, especially with 5 concurrent editors.
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

        // Set transaction author so persistent history can distinguish
        // local changes from remote ones — critical for deduplication.
        container.viewContext.transactionAuthor = Self.appTransactionAuthorName

        // Listen for remote changes
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleRemoteChange),
            name: .NSPersistentStoreRemoteChange,
            object: container.persistentStoreCoordinator
        )
    }

    /// Remove any leftover SwiftData .store files from before the Core Data migration.
    /// Also removes any corrupted Core Data .sqlite files if flagged.
    private static func cleanUpLegacyStores(in directory: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: directory.path) else { return }
        for file in contents {
            // Remove SwiftData .store files and their companions
            if file.hasSuffix(".store") || file.hasSuffix(".store-shm") || file.hasSuffix(".store-wal") {
                let url = directory.appending(path: file)
                try? fm.removeItem(at: url)
                print("Removed legacy SwiftData file: \(file)")
            }
        }
    }

    // Process persistent history on remote changes to ensure
    // all devices converge to the same state after concurrent edits.
    @objc private func handleRemoteChange(_ notification: Notification) {
        let context = container.newBackgroundContext()
        context.transactionAuthor = "\(Self.appTransactionAuthorName)-history"
        context.perform {
            let request = NSPersistentHistoryChangeRequest.fetchHistory(after: self.lastHistoryToken)

            if let result = try? context.execute(request) as? NSPersistentHistoryResult,
               let transactions = result.result as? [NSPersistentHistoryTransaction] {

                // Filter to only remote transactions (not authored by us)
                let remoteTransactions = transactions.filter {
                    $0.author != Self.appTransactionAuthorName
                }

                if !remoteTransactions.isEmpty {
                    // Merge remote changes into the viewContext on the main thread
                    DispatchQueue.main.async {
                        for transaction in remoteTransactions {
                            self.container.viewContext.mergeChanges(fromContextDidSave: transaction.objectIDNotification())
                        }
                    }
                }

                // Update the token to the latest transaction
                if let lastToken = transactions.last?.token {
                    self.lastHistoryToken = lastToken
                }
            }

            // Purge old history (older than 7 days) to prevent unbounded growth
            let purgeDate = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
            let purgeRequest = NSPersistentHistoryChangeRequest.deleteHistory(before: purgeDate)
            try? context.execute(purgeRequest)
        }
    }

    // MARK: - Save

    func save() {
        let context = viewContext
        guard context.hasChanges else { return }
        do {
            try context.save()
        } catch {
            print("Save error: \(error)")
        }
    }

    // MARK: - CloudKit Sharing

    /// Check if an object is in the shared store.
    func isShared(_ object: NSManagedObject) -> Bool {
        guard let store = object.objectID.persistentStore else { return false }
        return store.url == sharedStoreURL
    }

    /// Check if the object is shared AND the current user is a participant (not owner).
    func isParticipant(_ object: NSManagedObject) -> Bool {
        guard isShared(object) else { return false }
        guard let share = existingShare(for: object) else { return false }
        return share.currentUserParticipant?.role != .owner
    }

    /// Get the existing CKShare for a managed object.
    func existingShare(for object: NSManagedObject) -> CKShare? {
        do {
            let shares = try container.fetchShares(matching: [object.objectID])
            return shares[object.objectID]
        } catch {
            print("Error fetching share: \(error)")
            return nil
        }
    }

    /// Check if the current user can edit a shared object.
    /// Returns true for unshared objects (owner's own data).
    func canEdit(_ object: NSManagedObject) -> Bool {
        // Unshared objects are always editable
        guard let share = existingShare(for: object) else { return true }
        // Owner can always edit
        if share.currentUserParticipant?.role == .owner { return true }
        // Participants need readWrite permission
        return share.currentUserParticipant?.permission == .readWrite
    }

    /// Find the trip entity that owns a child object (day, stop, booking, etc.).
    /// Traverses relationships upward to find the root TripEntity for permission checks.
    func owningTrip(for object: NSManagedObject) -> TripEntity? {
        if let trip = object as? TripEntity { return trip }
        if let day = object as? DayEntity { return day.trip }
        if let stop = object as? StopEntity { return stop.day?.trip }
        if let comment = object as? CommentEntity { return comment.stop?.day?.trip }
        if let booking = object as? BookingEntity { return booking.trip }
        if let expense = object as? ExpenseEntity { return expense.trip }
        if let list = object as? TripListEntity { return list.trip }
        if let item = object as? TripListItemEntity { return item.list?.trip }
        return nil
    }

    /// The private persistent store (identified by URL).
    var privatePersistentStore: NSPersistentStore? {
        guard let privateStoreURL else { return nil }
        return container.persistentStoreCoordinator.persistentStores.first {
            $0.url == privateStoreURL
        }
    }

    /// The shared persistent store (identified by URL).
    var sharedPersistentStore: NSPersistentStore? {
        guard let sharedStoreURL else { return nil }
        return container.persistentStoreCoordinator.persistentStores.first {
            $0.url == sharedStoreURL
        }
    }
}
