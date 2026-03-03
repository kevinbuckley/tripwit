import CoreData
import CloudKit
import os

private let pcLog = Logger(subsystem: "com.kevinbuckley.travelplanner", category: "Persistence")

final class PersistenceController: ObservableObject {

    static let shared = PersistenceController()

    let container: NSPersistentContainer

    private static let containerIdentifier = "iCloud.com.kevinbuckley.travelplanner"
    private static let appTransactionAuthorName = "TripWit"

    /// True when running under XCTest — uses a plain container to avoid
    /// CloudKit entity registration that conflicts with test containers.
    private static let isRunningTests = ProcessInfo.processInfo.environment["XCTestConfigurationFilePath"] != nil

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

    init(inMemory: Bool = false) {
        if Self.isRunningTests || inMemory {
            container = NSPersistentContainer(name: "TripWit")
        } else {
            container = NSPersistentCloudKitContainer(name: "TripWit")
        }

        if Self.isRunningTests || inMemory {
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

            // Private store — user's own data, synced across their devices via CloudKit
            let privateURL = storeDir.appending(path: "Private.sqlite")
            let privateDesc = NSPersistentStoreDescription(url: privateURL)
            let privateOptions = NSPersistentCloudKitContainerOptions(
                containerIdentifier: Self.containerIdentifier
            )
            privateOptions.databaseScope = .private
            privateDesc.cloudKitContainerOptions = privateOptions
            privateDesc.setOption(true as NSNumber,
                                  forKey: NSPersistentHistoryTrackingKey)
            privateDesc.setOption(true as NSNumber,
                                  forKey: NSPersistentStoreRemoteChangeNotificationPostOptionKey)

            container.persistentStoreDescriptions = [privateDesc]
        }

        container.loadPersistentStores { description, error in
            if let error {
                pcLog.error("Core Data store failed to load (\(description.url?.lastPathComponent ?? "unknown", privacy: .public)): \(error.localizedDescription, privacy: .public)")
                // If a store fails to load, try to destroy it and reload.
                // This handles corrupted stores or stores left over from SwiftData migration.
                if let url = description.url {
                    pcLog.warning("Attempting to destroy and recreate store at \(url.lastPathComponent, privacy: .public)")
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
        // where the "truth" is what's on the server.
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergeByPropertyStoreTrumpMergePolicy

        if !Self.isRunningTests {
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
    }

    /// Remove any leftover SwiftData .store files from before the Core Data migration.
    private static func cleanUpLegacyStores(in directory: URL) {
        let fm = FileManager.default
        guard let contents = try? fm.contentsOfDirectory(atPath: directory.path) else { return }
        for file in contents {
            // Remove SwiftData .store files and their companions
            if file.hasSuffix(".store") || file.hasSuffix(".store-shm") || file.hasSuffix(".store-wal") {
                let url = directory.appending(path: file)
                try? fm.removeItem(at: url)
                pcLog.info("Removed legacy SwiftData file: \(file, privacy: .public)")
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
            pcLog.error("Save error: \(error.localizedDescription, privacy: .public)")
        }
    }
}
