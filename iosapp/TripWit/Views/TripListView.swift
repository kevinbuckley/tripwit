import SwiftUI
import CoreData
import TripCore
import os.log

private let listLog = Logger(subsystem: "com.kevinbuckley.travelplanner", category: "TripList")

struct TripListView: View {

    @Environment(\.managedObjectContext) private var viewContext
    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)]) private var allTrips: FetchedResults<TripEntity>

    @State private var showingAddTrip = false
    @State private var tripToDelete: TripEntity?

    /// All valid (non-deleted) trips.
    private var validTrips: [TripEntity] {
        allTrips.filter { !$0.isDeleted && $0.managedObjectContext != nil }
    }

    private var activeTrips: [TripEntity] {
        validTrips.filter { $0.hasCustomDates && $0.isActive }
    }

    private var upcomingTrips: [TripEntity] {
        validTrips.filter { ($0.hasCustomDates && $0.isFuture) || !$0.hasCustomDates }
    }

    private var pastTrips: [TripEntity] {
        validTrips.filter { $0.hasCustomDates && $0.isPast }
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

            if !upcomingTrips.isEmpty {
                Section {
                    ForEach(upcomingTrips) { trip in
                        NavigationLink(destination: TripDetailView(trip: trip)) {
                            tripRow(trip)
                        }
                    }
                    .onDelete { offsets in
                        if let index = offsets.first {
                            tripToDelete = upcomingTrips[index]
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
        }
        .listStyle(.insetGrouped)
    }

    // MARK: - Row

    @ViewBuilder
    private func tripRow(_ trip: TripEntity) -> some View {
        if trip.isDeleted || trip.managedObjectContext == nil {
            Text("Trip removed")
                .foregroundStyle(.secondary)
        } else {
            TripRowView(trip: trip)
        }
    }
}
