import SwiftUI
import CoreData
import os.log

private let appLog = Logger(subsystem: "com.kevinbuckley.travelplanner", category: "App")

@main
struct TripWitApp: App {

    let persistence = PersistenceController.shared
    @State private var locationManager = LocationManager()
    @State private var pendingImportURL: URL?

    var body: some Scene {
        WindowGroup {
            ContentView(pendingImportURL: $pendingImportURL)
                .environment(locationManager)
                .environment(\.managedObjectContext, persistence.viewContext)
                .onOpenURL { url in
                    handleIncomingURL(url)
                }
        }
    }

    /// Route incoming URLs — only .tripwit file imports
    private func handleIncomingURL(_ url: URL) {
        appLog.info("[URL] Received URL: \(url.absoluteString)")

        if url.pathExtension == "tripwit" {
            pendingImportURL = url
        } else {
            appLog.warning("[URL] Unhandled URL: \(url.absoluteString)")
        }
    }
}
