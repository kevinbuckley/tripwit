import SwiftUI
import CoreData
import CloudKit

@main
struct TravlyApp: App {

    let persistence = PersistenceController.shared
    @State private var locationManager = LocationManager()
    @State private var pendingImportURL: URL?

    /// UIApplicationDelegate adapter to handle CloudKit share acceptance.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(pendingImportURL: $pendingImportURL)
                .environment(locationManager)
                .environment(\.managedObjectContext, persistence.viewContext)
                .onOpenURL { url in
                    if url.pathExtension == "travly" {
                        pendingImportURL = url
                    }
                }
        }
    }
}

// MARK: - AppDelegate for CloudKit Share Acceptance

class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        configurationForConnecting connectingSceneSession: UISceneSession,
        options: UIScene.ConnectionOptions
    ) -> UISceneConfiguration {
        let config = UISceneConfiguration(
            name: nil,
            sessionRole: connectingSceneSession.role
        )
        config.delegateClass = SceneDelegate.self
        return config
    }
}

class SceneDelegate: NSObject, UIWindowSceneDelegate {

    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        let sharingService = CloudKitSharingService()
        Task {
            do {
                try await sharingService.acceptShare(cloudKitShareMetadata)
            } catch {
                print("Failed to accept CloudKit share: \(error)")
            }
        }
    }
}
