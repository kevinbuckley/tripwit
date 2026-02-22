import SwiftUI
import CoreData
import CloudKit
import os.log

private let appLog = Logger(subsystem: "com.kevinbuckley.travelplanner", category: "App")

@main
struct TravlyApp: App {

    let persistence = PersistenceController.shared
    @State private var locationManager = LocationManager()
    @State private var pendingImportURL: URL?
    @State private var shareAcceptAlert: ShareAcceptAlert?

    /// UIApplicationDelegate adapter to handle CloudKit share acceptance.
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        WindowGroup {
            ContentView(pendingImportURL: $pendingImportURL)
                .environment(locationManager)
                .environment(\.managedObjectContext, persistence.viewContext)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
                .alert(item: $shareAcceptAlert) { alert in
                    Alert(
                        title: Text(alert.title),
                        message: Text(alert.message),
                        dismissButton: .default(Text("OK"))
                    )
                }
        }
    }

    /// Route incoming URLs to the right handler
    private func handleIncomingURL(_ url: URL) {
        appLog.info("[URL] Received URL: \(url.absoluteString)")

        if url.scheme == "travly" && url.host == "share" {
            // travly://share?url=<encoded_share_url>
            handleShareURL(url)
        } else if url.pathExtension == "travly" {
            // .travly file import
            pendingImportURL = url
        } else {
            appLog.warning("[URL] Unhandled URL: \(url.absoluteString)")
        }
    }

    /// Accept a CloudKit share from a wrapped URL.
    /// Extracts the real share.icloud.com URL, fetches metadata, and accepts the share.
    private func handleShareURL(_ url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              let urlParam = components.queryItems?.first(where: { $0.name == "url" })?.value,
              let shareURL = URL(string: urlParam)
        else {
            appLog.error("[SHARE-ACCEPT] Could not extract share URL from: \(url.absoluteString)")
            shareAcceptAlert = ShareAcceptAlert(
                title: "Invalid Share Link",
                message: "This share link appears to be invalid. Please ask the sender to share again."
            )
            return
        }

        appLog.info("[SHARE-ACCEPT] Accepting share from URL: \(shareURL.absoluteString)")

        // Show a loading indicator (we'll use an alert for simplicity)
        shareAcceptAlert = ShareAcceptAlert(
            title: "Joining Trip...",
            message: "Connecting to the shared trip. This may take a moment."
        )

        Task {
            do {
                // Step 1: Fetch the share metadata from the URL
                let metadata = try await fetchShareMetadata(from: shareURL)
                appLog.info("[SHARE-ACCEPT] Fetched metadata for share: \(metadata.share.recordID)")

                // Step 2: Accept the share into the shared persistent store
                guard let sharedStore = persistence.sharedPersistentStore else {
                    appLog.error("[SHARE-ACCEPT] No shared store available")
                    await MainActor.run {
                        shareAcceptAlert = ShareAcceptAlert(
                            title: "Error",
                            message: "Could not join the trip. Please try again."
                        )
                    }
                    return
                }

                try await persistence.container.acceptShareInvitations(
                    from: [metadata],
                    into: sharedStore
                )

                appLog.info("[SHARE-ACCEPT] Successfully accepted share!")
                await MainActor.run {
                    shareAcceptAlert = ShareAcceptAlert(
                        title: "Trip Joined!",
                        message: "You've successfully joined the shared trip. It will appear in your trips list shortly."
                    )
                }
            } catch {
                appLog.error("[SHARE-ACCEPT] Error accepting share: \(error.localizedDescription)")
                await MainActor.run {
                    shareAcceptAlert = ShareAcceptAlert(
                        title: "Could Not Join Trip",
                        message: "There was an error joining the trip: \(error.localizedDescription)"
                    )
                }
            }
        }
    }

    /// Fetch CKShare.Metadata from a share URL using CKFetchShareMetadataOperation
    private func fetchShareMetadata(from url: URL) async throws -> CKShare.Metadata {
        try await withCheckedThrowingContinuation { continuation in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            operation.shouldFetchRootRecord = true

            var foundMetadata: CKShare.Metadata?

            operation.perShareMetadataResultBlock = { shareURL, result in
                switch result {
                case .success(let metadata):
                    appLog.info("[SHARE-ACCEPT] Got metadata for \(shareURL)")
                    foundMetadata = metadata
                case .failure(let error):
                    appLog.error("[SHARE-ACCEPT] perShareMetadata error: \(error.localizedDescription)")
                }
            }

            operation.fetchShareMetadataResultBlock = { result in
                switch result {
                case .success:
                    if let metadata = foundMetadata {
                        continuation.resume(returning: metadata)
                    } else {
                        continuation.resume(throwing: NSError(
                            domain: "Travly", code: -1,
                            userInfo: [NSLocalizedDescriptionKey: "No metadata returned for share URL"]
                        ))
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            let container = CKContainer(identifier: "iCloud.com.kevinbuckley.travelplanner")
            container.add(operation)
        }
    }
}

// MARK: - Share Accept Alert

struct ShareAcceptAlert: Identifiable {
    let id = UUID()
    let title: String
    let message: String
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

    /// This is still needed for cases where the OS intercepts a share.icloud.com
    /// URL directly (e.g. from older invitations or if someone manually shares the raw URL).
    func windowScene(
        _ windowScene: UIWindowScene,
        userDidAcceptCloudKitShareWith cloudKitShareMetadata: CKShare.Metadata
    ) {
        appLog.info("[SHARE-ACCEPT] System accepted share via userDidAcceptCloudKitShareWith")
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
