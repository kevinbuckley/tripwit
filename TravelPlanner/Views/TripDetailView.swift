import SwiftUI
import SwiftData
import TripCore

struct TripDetailView: View {

    @Environment(\.modelContext) private var modelContext

    @Bindable var trip: TripEntity

    @State private var showingEditTrip = false
    @State private var showingAddStop = false
    @State private var selectedDayForStop: DayEntity?
    @State private var selectedDayForAI: DayEntity?
    @State private var selectedDayForVibe: DayEntity?
    @State private var showingStartConfirmation = false
    @State private var showingCompleteConfirmation = false

    private var sortedDays: [DayEntity] {
        trip.days.sorted { $0.dayNumber < $1.dayNumber }
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    var body: some View {
        List {
            // MARK: - Header
            headerSection

            // MARK: - Status Actions
            statusActionSection

            // MARK: - Itinerary
            if !sortedDays.isEmpty {
                ForEach(sortedDays) { day in
                    daySection(day)
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(trip.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showingEditTrip = true
                } label: {
                    Text("Edit")
                }
            }
        }
        .sheet(isPresented: $showingEditTrip) {
            EditTripSheet(trip: trip)
        }
        .sheet(item: $selectedDayForStop) { day in
            AddStopSheet(day: day)
        }
        .sheet(item: $selectedDayForAI) { day in
            aiSuggestSheet(day: day)
        }
        .sheet(item: $selectedDayForVibe) { day in
            vibeSheet(day: day)
        }
        .alert("Start Trip?", isPresented: $showingStartConfirmation) {
            Button("Start", role: .none) {
                trip.status = .active
                DataManager(modelContext: modelContext).updateTrip(trip)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will mark your trip as active.")
        }
        .alert("Complete Trip?", isPresented: $showingCompleteConfirmation) {
            Button("Complete", role: .none) {
                trip.status = .completed
                DataManager(modelContext: modelContext).updateTrip(trip)
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("This will mark your trip as completed.")
        }
    }

    // MARK: - Header Section

    private var headerSection: some View {
        Section {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(spacing: 6) {
                            Image(systemName: "mappin.and.ellipse")
                                .foregroundStyle(.red)
                            Text(trip.destination)
                                .font(.title3)
                                .fontWeight(.medium)
                        }
                        Text("\(dateFormatter.string(from: trip.startDate)) - \(dateFormatter.string(from: trip.endDate))")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    StatusBadge(status: trip.status)
                }

                HStack(spacing: 16) {
                    Label("\(trip.durationInDays) days", systemImage: "calendar")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label("\(trip.days.count) day plans", systemImage: "list.bullet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    let stopCount = trip.days.reduce(0) { $0 + $1.stops.count }
                    Label("\(stopCount) stops", systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            if !trip.notes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(trip.notes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Status Actions

    @ViewBuilder
    private var statusActionSection: some View {
        if trip.status == .planning {
            Section {
                Button {
                    showingStartConfirmation = true
                } label: {
                    Label("Start Trip", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .tint(.green)
            }
        } else if trip.status == .active {
            Section {
                Button {
                    showingCompleteConfirmation = true
                } label: {
                    Label("Complete Trip", systemImage: "checkmark.circle.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 4)
                }
                .tint(.orange)
            }
        }
    }

    // MARK: - Day Section

    private func daySection(_ day: DayEntity) -> some View {
        Section {
            let sortedStops = day.stops.sorted { $0.sortOrder < $1.sortOrder }

            if !day.notes.isEmpty {
                Text(day.notes)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            }

            ForEach(sortedStops) { stop in
                NavigationLink(destination: StopDetailView(stop: stop)) {
                    StopRowView(stop: stop)
                }
            }
            .onDelete { offsets in
                deleteStops(from: sortedStops, at: offsets)
            }
            .onMove { source, destination in
                moveStops(in: day, from: source, to: destination)
            }

            HStack {
                Button {
                    selectedDayForStop = day
                } label: {
                    Label("Add Stop", systemImage: "plus.circle")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }

                Spacer()

                aiVibeButton(day: day)
                aiSuggestButton(day: day)
            }
        } header: {
            HStack {
                Text("Day \(day.dayNumber)")
                    .fontWeight(.semibold)
                Spacer()
                Text(day.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func deleteStops(from stops: [StopEntity], at offsets: IndexSet) {
        let manager = DataManager(modelContext: modelContext)
        for index in offsets {
            manager.deleteStop(stops[index])
        }
    }

    private func moveStops(in day: DayEntity, from source: IndexSet, to destination: Int) {
        let manager = DataManager(modelContext: modelContext)
        manager.reorderStops(in: day, from: source, to: destination)
    }

    // MARK: - AI Suggestions

    @ViewBuilder
    private func aiSuggestButton(day: DayEntity) -> some View {
        if #available(iOS 26, *) {
            Button {
                selectedDayForAI = day
            } label: {
                Label("Suggest", systemImage: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(.purple)
            }
        }
    }

    @ViewBuilder
    private func aiVibeButton(day: DayEntity) -> some View {
        if #available(iOS 26, *) {
            Button {
                selectedDayForVibe = day
            } label: {
                Label("Vibe", systemImage: "wand.and.stars")
                    .font(.subheadline)
                    .foregroundStyle(.purple)
            }
        }
    }

    @ViewBuilder
    private func vibeSheet(day: DayEntity) -> some View {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            PlanDayVibeSheet(
                day: day,
                destination: trip.destination,
                totalDays: trip.durationInDays
            )
        }
        #else
        Text("Apple Intelligence requires iOS 26")
        #endif
    }

    @ViewBuilder
    private func aiSuggestSheet(day: DayEntity) -> some View {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            SuggestStopsSheet(
                day: day,
                destination: trip.destination,
                totalDays: trip.durationInDays
            )
        }
        #else
        Text("Apple Intelligence requires iOS 26")
        #endif
    }
}
