import SwiftUI
import CoreData

struct SettingsView: View {

    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: []) private var allTrips: FetchedResults<TripEntity>

    @State private var showingDeleteConfirmation = false
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
    }

    private func loadSampleData() {
        let manager = DataManager(context: viewContext)
        manager.loadSampleDataIfEmpty()
        if allTrips.isEmpty {
            showingSampleDataLoaded = true
        }
    }

    private func deleteAllTrips() {
        let manager = DataManager(context: viewContext)
        for trip in allTrips {
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
