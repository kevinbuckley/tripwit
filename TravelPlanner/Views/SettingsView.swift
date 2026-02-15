import SwiftUI
import SwiftData

struct SettingsView: View {

    @Environment(\.modelContext) private var modelContext
    @Query private var allTrips: [TripEntity]

    @State private var showingDeleteConfirmation = false
    @State private var showingSampleDataLoaded = false

    var body: some View {
        List {
            // App Info
            Section {
                HStack(spacing: 14) {
                    Image(systemName: "airplane.circle.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.blue)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Trav")
                            .font(.headline)
                        Text("Version 1.0")
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

            // Data Management
            Section {
                Button {
                    loadSampleData()
                } label: {
                    Label("Load Sample Data", systemImage: "tray.and.arrow.down")
                }

                Button(role: .destructive) {
                    showingDeleteConfirmation = true
                } label: {
                    Label("Delete All Trips", systemImage: "trash")
                        .foregroundStyle(.red)
                }
            } header: {
                Text("Data Management")
            } footer: {
                Text("Sample data creates example trips for testing. Deleting all trips cannot be undone.")
            }

            // Credits
            Section {
                VStack(alignment: .leading, spacing: 6) {
                    Text("Built with SwiftUI & SwiftData")
                        .font(.subheadline)
                    Text("iOS 17+ | Swift 6")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 2)
            } header: {
                Text("Credits")
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
}
