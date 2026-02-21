import SwiftUI
import CoreData
import TripCore

struct ContentView: View {

    @Environment(\.managedObjectContext) private var viewContext
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false

    @Binding var pendingImportURL: URL?
    @State private var pendingImport: TripTransfer?
    @State private var importError: String?
    @State private var selectedTab = 1
    @State private var tripsNavPath = NavigationPath()
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)]) private var allTrips: FetchedResults<TripEntity>

    #if DEBUG
    /// Screenshot mode: pass `-screenshotTab trips` (or `map`, `settings`, `tripdetail`) as launch arg.
    /// Only available in debug builds for generating App Store screenshots.
    private var screenshotTab: String? {
        if let idx = ProcessInfo.processInfo.arguments.firstIndex(of: "-screenshotTab"),
           idx + 1 < ProcessInfo.processInfo.arguments.count {
            return ProcessInfo.processInfo.arguments[idx + 1]
        }
        return nil
    }

    private var isScreenshotMode: Bool { screenshotTab != nil }
    #else
    private var isScreenshotMode: Bool { false }
    #endif

    var body: some View {
        Group {
            if hasCompletedOnboarding || isScreenshotMode {
                mainTabView
                    .onAppear {
                        #if DEBUG
                        if isScreenshotMode {
                            seedScreenshotDataIfNeeded()
                            switch screenshotTab {
                            case "map": selectedTab = 0
                            case "trips": selectedTab = 1
                            case "wishlist": selectedTab = 2
                            case "settings": selectedTab = 3
                            case "tripdetail":
                                selectedTab = 1
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                    if let first = allTrips.first(where: { $0.status == .active }) ?? allTrips.first {
                                        tripsNavPath.append(first.id)
                                    }
                                }
                            default: selectedTab = 1
                            }
                        }
                        #endif
                    }
            } else {
                WelcomeView(hasCompletedOnboarding: $hasCompletedOnboarding)
            }
        }
        .onChange(of: pendingImportURL) { _, url in
            guard let url else { return }
            do {
                pendingImport = try TripShareService.decodeTrip(from: url)
            } catch {
                importError = error.localizedDescription
            }
            pendingImportURL = nil
        }
        .sheet(item: $pendingImport) { transfer in
            ImportTripSheet(transfer: transfer) { importedTripID in
                hasCompletedOnboarding = true
                selectedTab = 1
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    tripsNavPath.append(importedTripID)
                }
            }
        }
        .alert("Import Error", isPresented: Binding(
            get: { importError != nil },
            set: { if !$0 { importError = nil } }
        )) {
            Button("OK", role: .cancel) { importError = nil }
        } message: {
            Text(importError ?? "Could not read the trip file.")
        }
    }

    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            NavigationStack {
                TripMapView(onGoToTrips: { selectedTab = 1 })
            }
            .tabItem {
                Label("Map", systemImage: "map")
            }
            .tag(0)

            NavigationStack(path: $tripsNavPath) {
                TripListView()
                    .navigationDestination(for: UUID.self) { tripID in
                        if let trip = allTrips.first(where: { $0.id == tripID }) {
                            TripDetailView(trip: trip)
                        }
                    }
            }
            .tabItem {
                Label("Trips", systemImage: "list.bullet")
            }
            .tag(1)

            NavigationStack {
                WishlistView()
            }
            .tabItem {
                Label("Wishlist", systemImage: "heart")
            }
            .tag(2)

            NavigationStack {
                SettingsView()
            }
            .tabItem {
                Label("Settings", systemImage: "gear")
            }
            .tag(3)
        }
        .tint(.blue)
    }

    #if DEBUG
    private func seedScreenshotDataIfNeeded() {
        let request: NSFetchRequest<TripEntity> = TripEntity.fetchRequest() as! NSFetchRequest<TripEntity>
        let count = (try? viewContext.count(for: request)) ?? 0
        if count == 0 {
            let manager = DataManager(context: viewContext)
            manager.loadSampleDataIfEmpty()
        }
        let wishlistRequest: NSFetchRequest<WishlistItemEntity> = WishlistItemEntity.fetchRequest() as! NSFetchRequest<WishlistItemEntity>
        let wishlistCount = (try? viewContext.count(for: wishlistRequest)) ?? 0
        if wishlistCount == 0 {
            seedWishlistItems()
        }
    }

    private func seedWishlistItems() {
        let items: [(String, String, Double, Double, StopCategory)] = [
            ("Sagrada Família", "Barcelona", 41.4036, 2.1744, .attraction),
            ("Tsukiji Outer Market", "Tokyo", 35.6654, 139.7707, .restaurant),
            ("Santorini Sunset", "Santorini", 36.4310, 25.4315, .activity),
            ("Banff National Park", "Alberta", 51.4968, -115.9281, .activity),
            ("Borough Market", "London", 51.5055, -0.0910, .restaurant),
            ("Colosseum", "Rome", 41.8902, 12.4922, .attraction),
        ]
        for (name, city, lat, lon, cat) in items {
            WishlistItemEntity.create(in: viewContext, name: name, destination: city, latitude: lat, longitude: lon, category: cat)
        }
        try? viewContext.save()
    }
    #endif
}
