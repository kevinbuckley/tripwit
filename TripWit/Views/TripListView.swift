import SwiftUI
import CoreData
import CloudKit
import TripCore
import os.log

private let listLog = Logger(subsystem: "com.kevinbuckley.travelplanner", category: "TripList")

struct TripListView: View {

    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)]) private var allTrips: FetchedResults<TripEntity>

    @State private var showingAddTrip = false
    @State private var tripToDelete: TripEntity?
    @State private var isRefreshing = false

    private let sharingService = CloudKitSharingService()
    private let persistence = PersistenceController.shared

    /// All valid (non-deleted) trips.
    private var validTrips: [TripEntity] {
        allTrips.filter { !$0.isDeleted && $0.managedObjectContext != nil }
    }

    /// Own trips (not shared with me by others).
    private var ownTrips: [TripEntity] {
        validTrips.filter { !sharingService.isParticipant($0) }
    }

    /// Trips shared with me by others.
    private var sharedWithMeTrips: [TripEntity] {
        validTrips.filter { sharingService.isParticipant($0) }
    }

    private var activeTrips: [TripEntity] {
        ownTrips.filter { $0.status == .active }
    }

    private var upcomingTrips: [TripEntity] {
        ownTrips.filter { $0.status == .planning && $0.isFuture }
    }

    private var pastTrips: [TripEntity] {
        ownTrips.filter { $0.status == .completed }
    }

    private var planningCurrentTrips: [TripEntity] {
        ownTrips.filter { $0.status == .planning && !$0.isFuture }
    }

    var body: some View {
        Group {
            if allTrips.isEmpty {
                emptyStateView
            } else {
                tripListContent
            }
        }
        .navigationTitle("My Trips")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingAddTrip = true
                } label: {
                    Image(systemName: "plus")
                }
            }
        }
        .sheet(isPresented: $showingAddTrip) {
            AddTripSheet()
        }
        .alert("Delete Trip?", isPresented: Binding(
            get: { tripToDelete != nil },
            set: { if !$0 { tripToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let trip = tripToDelete, !trip.isDeleted {
                    DataManager(context: viewContext).deleteTrip(trip)
                }
                tripToDelete = nil
            }
            Button("Cancel", role: .cancel) { tripToDelete = nil }
        } message: {
            if let trip = tripToDelete, !trip.isDeleted {
                Text("Delete \"\(trip.wrappedName)\" and all its stops, bookings, and comments? This cannot be undone.")
            }
        }
    }

    // MARK: - Empty State

    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "airplane.departure")
                .font(.system(size: 64))
                .foregroundStyle(.blue.opacity(0.6))
            Text("No Trips Yet")
                .font(.title2)
                .fontWeight(.semibold)
            Text("Plan your first adventure and keep\nyour itinerary organized.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                showingAddTrip = true
            } label: {
                Label("Plan Your First Trip", systemImage: "plus.circle.fill")
                    .font(.headline)
                    .padding(.horizontal, 24)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .padding(.top, 8)
            Spacer()
        }
        .padding()
    }

    // MARK: - Trip List

    private var tripListContent: some View {
        List {
            if !activeTrips.isEmpty {
                Section {
                    ForEach(activeTrips) { trip in
                        NavigationLink(destination: TripDetailView(trip: trip)) {
                            tripRow(trip)
                        }
                    }
                    .onDelete { offsets in
                        if let index = offsets.first {
                            tripToDelete = activeTrips[index]
                        }
                    }
                } header: {
                    Label("Active", systemImage: "location.fill")
                        .foregroundStyle(.green)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            if !upcomingTrips.isEmpty || !planningCurrentTrips.isEmpty {
                let combined = planningCurrentTrips + upcomingTrips
                Section {
                    ForEach(combined) { trip in
                        NavigationLink(destination: TripDetailView(trip: trip)) {
                            tripRow(trip)
                        }
                    }
                    .onDelete { offsets in
                        if let index = offsets.first {
                            tripToDelete = combined[index]
                        }
                    }
                } header: {
                    Label("Upcoming", systemImage: "calendar")
                        .foregroundStyle(.blue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            if !pastTrips.isEmpty {
                Section {
                    ForEach(pastTrips) { trip in
                        NavigationLink(destination: TripDetailView(trip: trip)) {
                            tripRow(trip)
                        }
                    }
                    .onDelete { offsets in
                        if let index = offsets.first {
                            tripToDelete = pastTrips[index]
                        }
                    }
                } header: {
                    Label("Past", systemImage: "checkmark.circle")
                        .foregroundStyle(.gray)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }

            // Shared with Me section
            if !sharedWithMeTrips.isEmpty {
                Section {
                    ForEach(sharedWithMeTrips) { trip in
                        NavigationLink(destination: TripDetailView(trip: trip)) {
                            tripRow(trip, showOwner: true)
                        }
                    }
                    // No swipe-to-delete for shared trips
                } header: {
                    Label("Shared with Me", systemImage: "person.2.fill")
                        .foregroundStyle(.purple)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
            }
        }
        .listStyle(.insetGrouped)
        .refreshable {
            await refreshTrips()
        }
    }

    /// Force CloudKit to re-import shared records and refresh the view context.
    private func refreshTrips() async {
        isRefreshing = true
        listLog.info("[REFRESH] Pull-to-refresh triggered")

        // Step 1: Fetch all shared zones from CloudKit to wake up the sync engine.
        let ckContainer = CKContainer(identifier: "iCloud.com.kevinbuckley.travelplanner")
        let sharedDB = ckContainer.sharedCloudDatabase
        do {
            let zones = try await sharedDB.allRecordZones()
            listLog.info("[REFRESH] Found \(zones.count) shared zone(s)")
            // Touch each zone to trigger NSPersistentCloudKitContainer to notice them
            for zone in zones {
                listLog.info("[REFRESH]   Zone: \(zone.zoneID.zoneName) owner: \(zone.zoneID.ownerName)")
                let changes = try await sharedDB.recordZoneChanges(inZoneWith: zone.zoneID, since: nil)
                listLog.info("[REFRESH]   Zone has \(changes.modificationResultsByID.count) records")
            }
        } catch {
            listLog.error("[REFRESH] Failed to fetch shared zones: \(error.localizedDescription)")
        }

        // Step 2: Wait for CloudKit to process, then let Core Data merge naturally.
        // NOTE: Do NOT call refreshCloudKitSync() — removing/re-adding the shared store
        // can crash if views are concurrently accessing entities from that store.
        try? await Task.sleep(for: .seconds(3))
        listLog.info("[REFRESH] Refresh complete")
        isRefreshing = false
    }

    // MARK: - Row

    @ViewBuilder
    private func tripRow(_ trip: TripEntity, showOwner: Bool = false) -> some View {
        if trip.isDeleted || trip.managedObjectContext == nil {
            Text("Trip removed")
                .foregroundStyle(.secondary)
        } else {
            HStack {
                TripRowView(trip: trip)
                if sharingService.isShared(trip) && !showOwner {
                    Spacer()
                    Image(systemName: "person.2.fill")
                        .font(.caption)
                        .foregroundStyle(.blue.opacity(0.7))
                }
            }
            .overlay(alignment: .bottomTrailing) {
                if showOwner, let ownerName = sharingService.ownerName(for: trip) {
                    Text("by \(ownerName)")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .padding(.trailing, 4)
                }
            }
        }
    }
}
