import SwiftUI
import CoreData

struct SettingsView: View {

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(AuthService.self) private var authService
    @Environment(\.syncService) private var syncService
    @FetchRequest(sortDescriptors: []) private var allTrips: FetchedResults<TripEntity>

    @State private var showingDeleteConfirmation = false
    @State private var showingDeleteAccountConfirmation = false
    @State private var showingDeleteAccountError = false
    @State private var deleteAccountErrorMessage = ""
    @State private var showingSampleDataLoaded = false
    @AppStorage("photoMatchRadiusMiles") private var photoMatchRadiusMiles: Double = 1.0

    private var appVersion: String {
        let version = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "1.0"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "1"
        return "Version \(version) (\(build))"
    }

    var body: some View {
        List {
            // App Info
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("TripWit")
                            .font(.headline)
                        Text(appVersion)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)
            }

            // Account
            accountSection

            // Stats
            Section {
                let stopCount = allTrips.flatMap(\.daysArray).flatMap(\.stopsArray).count
                let dayCount = allTrips.flatMap(\.daysArray).count
                LabeledContent("Total Trips", value: "\(allTrips.count)")
                LabeledContent("Total Days", value: "\(dayCount)")
                LabeledContent("Total Stops", value: "\(stopCount)")
            } header: {
                Text("Statistics")
            }

            // Nearby Radius
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Search Radius")
                        Spacer()
                        Text(formatRadius(photoMatchRadiusMiles))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $photoMatchRadiusMiles, in: 0.1...5.0, step: 0.1)
                        .tint(.blue)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Nearby")
            } footer: {
                Text("Used for photo matching and AI nearby suggestions. Larger values find more results but may be less accurate.")
            }

            // Data Management
            Section {
                #if DEBUG
                Button {
                    loadSampleData()
                } label: {
                    Label("Load Sample Data", systemImage: "tray.and.arrow.down")
                }
                .disabled(!allTrips.isEmpty)
                #endif

                if !allTrips.isEmpty {
                    Button(role: .destructive) {
                        showingDeleteConfirmation = true
                    } label: {
                        Label("Delete All Trips", systemImage: "trash")
                            .foregroundStyle(.red)
                    }
                }
            } header: {
                Text("Data Management")
            } footer: {
                #if DEBUG
                if allTrips.isEmpty {
                    Text("Load sample trips to explore the app.")
                } else {
                    Text("Deleting all trips cannot be undone.")
                }
                #else
                if !allTrips.isEmpty {
                    Text("Deleting all trips cannot be undone.")
                }
                #endif
            }

            // Explore TripWit
            Section {
                if let webURL = URL(string: "https://tripwit.app") {
                    Link(destination: webURL) {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8, style: .continuous)
                                    .fill(Color.blue)
                                    .frame(width: 32, height: 32)
                                Image(systemName: "globe")
                                    .font(.system(size: 16, weight: .medium))
                                    .foregroundStyle(.white)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text("TripWit for Web")
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                Text("Plan from any browser at tripwit.app")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 2)
                    }
                }
            } header: {
                Text("Explore TripWit")
            } footer: {
                Text("Your trips are also yours on the web.")
            }

            // About
            Section {
                if let supportURL = URL(string: "https://kevinbuckley.github.io/tripwit/support.html") {
                    Link(destination: supportURL) {
                        Label("Help & Support", systemImage: "questionmark.circle")
                    }
                }

                if let privacyURL = URL(string: "https://kevinbuckley.github.io/tripwit/privacy.html") {
                    Link(destination: privacyURL) {
                        Label("Privacy Policy", systemImage: "hand.raised")
                    }
                }
            } header: {
                Text("About")
            } footer: {
                Text("Made with love for travel.")
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.top, 8)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Settings")
        .alert("Delete All Trips?", isPresented: $showingDeleteConfirmation) {
            Button("Delete All", role: .destructive) {
                deleteAllTrips()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all \(allTrips.count) trips and their data. This cannot be undone.")
        }
        .alert("Sample Data Loaded", isPresented: $showingSampleDataLoaded) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("Example trips have been added to help you explore the app.")
        }
        .alert("Delete Account?", isPresented: $showingDeleteAccountConfirmation) {
            Button("Delete Account", role: .destructive) {
                Task {
                    let dataService: SupabaseDataServiceProtocol? = authService.supabase.map { SupabaseDataService(client: $0) }
                    do {
                        try await authService.deleteAccount(dataService: dataService)
                    } catch {
                        deleteAccountErrorMessage = error.localizedDescription
                        showingDeleteAccountError = true
                    }
                }
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will permanently delete all your synced trip data and sign you out. Local trips on this device will remain. This cannot be undone.")
        }
        .alert("Delete Account Failed", isPresented: $showingDeleteAccountError) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(deleteAccountErrorMessage)
        }
    }

    // MARK: - Account Section

    @ViewBuilder
    private var accountSection: some View {
        Section {
            if authService.isSignedIn {
                // Signed-in state
                HStack(spacing: 12) {
                    ZStack {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color.green)
                            .frame(width: 32, height: 32)
                        Image(systemName: "checkmark.circle.fill")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(authService.userEmail ?? "Signed In")
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                        syncStatusText
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)

                Button {
                    if let userId = authService.userId {
                        Task { await syncService?.sync(userId: userId) }
                    }
                } label: {
                    Label {
                        Text("Sync Now")
                    } icon: {
                        if case .syncing = syncService?.state {
                            ProgressView()
                        } else {
                            Image(systemName: "arrow.triangle.2.circlepath")
                        }
                    }
                }
                .disabled(syncService?.state == .syncing)

                Button(role: .destructive) {
                    Task { await authService.signOut() }
                } label: {
                    Label("Sign Out", systemImage: "rectangle.portrait.and.arrow.right")
                        .foregroundStyle(.red)
                }

                Button(role: .destructive) {
                    showingDeleteAccountConfirmation = true
                } label: {
                    Label("Delete Account", systemImage: "person.crop.circle.badge.minus")
                        .foregroundStyle(.red)
                }
            } else {
                // Not signed in
                Button {
                    Task { await authService.signInWithGoogle() }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 8, style: .continuous)
                                .fill(Color.white)
                                .frame(width: 32, height: 32)
                            Text("G")
                                .font(.system(size: 16, weight: .bold))
                                .foregroundStyle(.blue)
                        }
                        Text("Sign in with Google")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        if authService.isLoading {
                            ProgressView()
                        }
                    }
                    .padding(.vertical, 2)
                }
                .disabled(authService.isLoading)
            }
        } header: {
            Text("Account")
        } footer: {
            if authService.isSignedIn {
                Text("Your trips sync with tripwit.app.")
            } else {
                Text("Sign in to sync your trips with tripwit.app.")
            }
        }
    }

    @ViewBuilder
    private var syncStatusText: some View {
        if let svc = syncService {
            switch svc.state {
            case .idle:
                Text("Connected")
            case .syncing:
                Text("Syncing…")
            case .error(let msg):
                Text("Sync error: \(msg)")
                    .foregroundStyle(.orange)
            case .lastSynced(let date):
                Text("Synced \(date.formatted(.relative(presentation: .named)))")
            }
        } else {
            Text("Connected")
        }
    }

    // MARK: - Helpers

    private func loadSampleData() {
        let manager = DataManager(context: viewContext)
        manager.loadSampleDataIfEmpty()
        if allTrips.isEmpty {
            showingSampleDataLoaded = true
        }
    }

    private func deleteAllTrips() {
        let manager = DataManager(context: viewContext)
        for trip in Array(allTrips) {
            manager.deleteTrip(trip)
        }
    }

    private func formatRadius(_ miles: Double) -> String {
        if miles == 1.0 {
            return "1 mile"
        }
        return String(format: "%.1f miles", miles)
    }
}
