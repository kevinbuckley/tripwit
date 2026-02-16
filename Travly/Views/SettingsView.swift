import SwiftUI
import SwiftData

struct SettingsView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var allTrips: [TripEntity]

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
                        Text("Travly")
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
                let stopCount = allTrips.flatMap(\.days).flatMap(\.stops).count
                let dayCount = allTrips.flatMap(\.days).count
                LabeledContent("Total Trips", value: "\(allTrips.count)")
                LabeledContent("Total Days", value: "\(dayCount)")
                LabeledContent("Total Stops", value: "\(stopCount)")
            } header: {
                Text("Statistics")
            }

            // Photo Matching
            Section {
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("Photo Search Radius")
                        Spacer()
                        Text(formatRadius(photoMatchRadiusMiles))
                            .foregroundStyle(.secondary)
                    }
                    Slider(value: $photoMatchRadiusMiles, in: 0.1...5.0, step: 0.1)
                        .tint(.blue)
                }
                .padding(.vertical, 4)
            } header: {
                Text("Photo Matching")
            } footer: {
                Text("How close a photo must be to a stop to be matched. Larger values find more photos but may be less accurate.")
            }

            // Data Management
            Section {
                Button {
                    loadSampleData()
                } label: {
                    Label("Load Sample Data", systemImage: "tray.and.arrow.down")
                }
                .disabled(!allTrips.isEmpty)

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
                if allTrips.isEmpty {
                    Text("Load sample trips to explore the app.")
                } else {
                    Text("Deleting all trips cannot be undone.")
                }
            }

            // About
            Section {
                Link(destination: URL(string: "https://kevinbuckley.github.io/travly/support.html")!) {
                    Label("Help & Support", systemImage: "questionmark.circle")
                }

                Link(destination: URL(string: "https://kevinbuckley.github.io/travly/privacy.html")!) {
                    Label("Privacy Policy", systemImage: "hand.raised")
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
        let manager = DataManager(modelContext: modelContext)
        manager.loadSampleDataIfEmpty()
        if allTrips.isEmpty {
            showingSampleDataLoaded = true
        }
    }

    private func deleteAllTrips() {
        let manager = DataManager(modelContext: modelContext)
        for trip in allTrips {
            manager.deleteTrip(trip)
        }
    }

    private func formatRadius(_ miles: Double) -> String {
        if Locale.current.measurementSystem == .us {
            if miles < 1.0 {
                let feet = Int(miles * 5280)
                return "\(feet) ft"
            }
            return String(format: "%.1f mi", miles)
        } else {
            let km = miles * 1.60934
            if km < 1.0 {
                return "\(Int(km * 1000)) m"
            }
            return String(format: "%.1f km", km)
        }
    }
}
