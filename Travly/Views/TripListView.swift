import SwiftUI
import CoreData
import TripCore

struct TripListView: View {

    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)]) private var allTrips: FetchedResults<TripEntity>

    @State private var showingAddTrip = false
    @State private var tripToDelete: TripEntity?

    private let sharingService = CloudKitSharingService()

    /// Own trips (not shared with me by others).
    private var ownTrips: [TripEntity] {
        allTrips.filter { !sharingService.isParticipant($0) }
    }

    /// Trips shared with me by others.
    private var sharedWithMeTrips: [TripEntity] {
        allTrips.filter { sharingService.isParticipant($0) }
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
                if let trip = tripToDelete {
                    DataManager(context: viewContext).deleteTrip(trip)
                    tripToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { tripToDelete = nil }
        } message: {
            if let trip = tripToDelete {
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
    }

    // MARK: - Row

    @ViewBuilder
    private func tripRow(_ trip: TripEntity, showOwner: Bool = false) -> some View {
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
