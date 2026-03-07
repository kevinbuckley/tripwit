import BackgroundTasks
import CoreData
import WidgetKit
import os.log

private let bgLog = Logger(subsystem: "com.kevinbuckley.travelplanner", category: "BackgroundTask")

/// Manages BGTaskScheduler registrations and execution for background app refresh.
///
/// Registers two tasks:
///  - `appRefresh`: Refreshes widget data and trips (BGAppRefreshTask, ~15 min minimum interval)
///  - `processing`: Re-indexes Spotlight (BGProcessingTask, requires power + network optional)
enum BackgroundTaskManager {

    // MARK: - Task Identifiers (must be registered in Info.plist BGTaskSchedulerPermittedIdentifiers)

    static let appRefreshID   = "com.kevinbuckley.travelplanner.appRefresh"
    static let processingID   = "com.kevinbuckley.travelplanner.processing"

    static var allIdentifiers: [String] { [appRefreshID, processingID] }

    // MARK: - Registration

    /// Call once at app startup (before app goes to background).
    static func registerTasks(context: NSManagedObjectContext) {
        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: appRefreshID,
            using: nil
        ) { task in
            handleAppRefresh(task: task as! BGAppRefreshTask, context: context)
        }

        BGTaskScheduler.shared.register(
            forTaskWithIdentifier: processingID,
            using: nil
        ) { task in
            handleProcessing(task: task as! BGProcessingTask, context: context)
        }
    }

    // MARK: - Scheduling

    /// Schedule the next app refresh. Call after each execution and at app launch.
    static func scheduleAppRefresh() {
        let request = BGAppRefreshTaskRequest(identifier: appRefreshID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: 15 * 60)  // 15 minutes minimum
        do {
            try BGTaskScheduler.shared.submit(request)
            bgLog.info("[BG] Scheduled appRefresh")
        } catch {
            bgLog.warning("[BG] Could not schedule appRefresh: \(error.localizedDescription)")
        }
    }

    /// Schedule the next Spotlight re-index processing task.
    static func scheduleProcessing() {
        let request = BGProcessingTaskRequest(identifier: processingID)
        request.requiresNetworkConnectivity = false
        request.requiresExternalPower       = false
        request.earliestBeginDate           = Date(timeIntervalSinceNow: 60 * 60)  // 1 hour minimum
        do {
            try BGTaskScheduler.shared.submit(request)
            bgLog.info("[BG] Scheduled processing")
        } catch {
            bgLog.warning("[BG] Could not schedule processing: \(error.localizedDescription)")
        }
    }

    // MARK: - Handlers

    private static func handleAppRefresh(task: BGAppRefreshTask, context: NSManagedObjectContext) {
        // Schedule the next refresh immediately
        scheduleAppRefresh()

        let opTask = Task {
            do {
                try await refreshWidgetData(context: context)
                task.setTaskCompleted(success: true)
                bgLog.info("[BG] appRefresh completed")
            } catch {
                task.setTaskCompleted(success: false)
                bgLog.warning("[BG] appRefresh failed: \(error.localizedDescription)")
            }
        }

        task.expirationHandler = {
            opTask.cancel()
            task.setTaskCompleted(success: false)
            bgLog.warning("[BG] appRefresh expired")
        }
    }

    private static func handleProcessing(task: BGProcessingTask, context: NSManagedObjectContext) {
        scheduleProcessing()

        let opTask = Task {
            await reindexSpotlight(context: context)
            task.setTaskCompleted(success: true)
            bgLog.info("[BG] processing completed")
        }

        task.expirationHandler = {
            opTask.cancel()
            task.setTaskCompleted(success: false)
            bgLog.warning("[BG] processing expired")
        }
    }

    // MARK: - Work

    private static func refreshWidgetData(context: NSManagedObjectContext) async throws {
        try await context.perform {
            let request = NSFetchRequest<TripEntity>(entityName: "TripEntity")
            request.sortDescriptors = [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)]
            let trips = try context.fetch(request)

            if let active = trips.first(where: { $0.isActive }) ?? trips.first {
                let data = WidgetDataStore.buildData(from: active)
                WidgetDataStore.write(data)
            }
            WidgetCenter.shared.reloadAllTimelines()
        }
    }

    private static func reindexSpotlight(context: NSManagedObjectContext) async {
        await context.perform {
            SpotlightService.indexAllTrips(in: context)
        }
    }
}
