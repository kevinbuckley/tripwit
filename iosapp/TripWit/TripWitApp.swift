import SwiftUI
import CoreData
import GoogleSignIn
import os.log

// MARK: - Environment key for optional SyncService

private struct SyncServiceKey: EnvironmentKey {
    static let defaultValue: SyncService? = nil
}

extension EnvironmentValues {
    var syncService: SyncService? {
        get { self[SyncServiceKey.self] }
        set { self[SyncServiceKey.self] = newValue }
    }
}

private let appLog = Logger(subsystem: "com.kevinbuckley.travelplanner", category: "App")

@main
struct TripWitApp: App {

    let persistence = PersistenceController.shared
    @State private var locationManager = LocationManager()
    @State private var authService = AuthService()
    @State private var syncService: SyncService?
    @State private var pendingImportURL: URL?
    @State private var pendingQuickAction: QuickActionService.ShortcutType?
    @State private var pendingDeepLink: DeepLinkRouter.Route?
    @Environment(\.scenePhase) private var scenePhase

    init() {
        QuickActionService.registerShortcuts()
        // Background tasks must be registered before app finishes launching.
        BackgroundTaskManager.registerTasks(context: PersistenceController.shared.viewContext)
    }

    var body: some Scene {
        WindowGroup {
            ContentView(
                pendingImportURL: $pendingImportURL,
                pendingQuickAction: $pendingQuickAction,
                pendingDeepLink: $pendingDeepLink
            )
            .environment(locationManager)
            .environment(authService)
            .environment(\.syncService, syncService)
            .environment(\.managedObjectContext, persistence.viewContext)
            .onOpenURL { url in
                handleIncomingURL(url)
            }
            .onChange(of: authService.isSignedIn) { _, isSignedIn in
                if isSignedIn, let client = authService.supabase {
                    let dataService = SupabaseDataService(client: client)
                    let svc = SyncService(dataService: dataService, context: persistence.viewContext)
                    syncService = svc
                    // First sync after sign-in
                    if let userId = authService.userId {
                        Task { await svc.sync(userId: userId) }
                    }
                } else {
                    syncService = nil
                }
            }
            .onChange(of: scenePhase) { _, phase in
                if phase == .active {
                    // Reschedule background tasks each time the app becomes active.
                    BackgroundTaskManager.scheduleAppRefresh()
                    BackgroundTaskManager.scheduleProcessing()

                    if let svc = syncService, svc.shouldAutoSync,
                       let userId = authService.userId {
                        Task { await svc.sync(userId: userId) }
                    }
                }
            }
        }
    }

    /// Route incoming URLs — .tripwit file imports, tripwit:// deep links, and Google Sign-In
    private func handleIncomingURL(_ url: URL) {
        appLog.info("[URL] Received URL: \(url.absoluteString)")

        // Google Sign-In callback
        if GIDSignIn.sharedInstance.handle(url) { return }

        if url.pathExtension == "tripwit" {
            pendingImportURL = url
        } else if let route = DeepLinkRouter.route(from: url) {
            pendingDeepLink = route
        } else {
            appLog.warning("[URL] Unhandled URL: \(url.absoluteString)")
        }
    }
}

// MARK: - UIApplicationDelegate (Quick Actions)

final class AppDelegate: NSObject, UIApplicationDelegate {

    var pendingQuickActionType: QuickActionService.ShortcutType?

    /// Called when app is already running and user taps a quick action.
    func application(
        _ application: UIApplication,
        performActionFor shortcutItem: UIApplicationShortcutItem,
        completionHandler: @escaping (Bool) -> Void
    ) {
        pendingQuickActionType = QuickActionService.type(for: shortcutItem)
        completionHandler(pendingQuickActionType != nil)
    }
}
