import SwiftUI
import CoreData
import MapKit
import TripCore

struct ActiveTripDashboard: View {

    @ObservedObject var trip: TripEntity

    @State private var isExpanded: Bool = true
    @State private var showingAddStop: Bool = false
    @State private var showingQuickAdd: Bool = false

    private let calendar = Calendar.current

    // MARK: - Computed Properties

    private var todayDay: DayEntity? {
        let today = calendar.startOfDay(for: Date())
        return trip.daysArray.first { calendar.isDate($0.wrappedDate, inSameDayAs: today) }
    }

    private var dayNumber: Int {
        Int(todayDay?.dayNumber ?? 1)
    }

    private var totalDays: Int {
        trip.durationInDays
    }

    private var todayStops: [StopEntity] {
        guard let day = todayDay else { return [] }
        return day.stopsArray.sorted { lhs, rhs in
            switch (lhs.arrivalTime, rhs.arrivalTime) {
            case let (a?, b?): return a < b
            case (.some, .none): return true
            case (.none, .some): return false
            case (.none, .none): return lhs.sortOrder < rhs.sortOrder
            }
        }
    }

    private var nextUpcomingStopID: UUID? {
        let now = Date()
        return todayStops.first { stop in
            guard let arrival = stop.arrivalTime else { return false }
            return arrival > now
        }?.id ?? todayStops.last?.id
    }

    private var dateText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: Date())
    }

    // MARK: - Body

    var body: some View {
        if trip.isDeleted || trip.managedObjectContext == nil {
            EmptyView()
        } else {
            dashboardContent
        }
    }

    private var dashboardContent: some View {
        VStack(spacing: 0) {
            headerBar
            if isExpanded {
                expandedContent
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 0))
        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
        .animation(.easeInOut(duration: 0.3), value: isExpanded)
        .sheet(isPresented: $showingAddStop) {
            addStopSheet
        }
        .sheet(isPresented: $showingQuickAdd) {
            quickAddSheet
        }
    }

    // MARK: - Header Bar

    private var headerBar: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.3)) {
                isExpanded.toggle()
            }
        } label: {
            headerContent
        }
        .buttonStyle(.plain)
    }

    private var headerContent: some View {
        HStack(spacing: 8) {
            activeDot
            headerLabels
            Spacer()
            chevron
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.08))
    }

    private var activeDot: some View {
        Circle()
            .fill(Color.green)
            .frame(width: 8, height: 8)
    }

    private var headerLabels: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("ACTIVE TRIP")
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundStyle(.green)
                .tracking(0.5)
            Text("Day \(dayNumber) of \(trip.wrappedName)")
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundStyle(.primary)
                .lineLimit(1)
            headerSubtitle
        }
    }

    private var headerSubtitle: some View {
        HStack(spacing: 4) {
            Text(dateText)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text("\u{00B7}")
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(trip.wrappedDestination)
                .font(.caption)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
    }

    private var chevron: some View {
        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
            .font(.caption)
            .fontWeight(.semibold)
            .foregroundStyle(.secondary)
    }

    // MARK: - Expanded Content

    private var expandedContent: some View {
        VStack(alignment: .leading, spacing: 0) {
            itineraryHeader
            if todayStops.isEmpty {
                emptyState
            } else {
                stopsTimeline
            }
            addStopButton
        }
        .frame(maxHeight: 300)
    }

    private var itineraryHeader: some View {
        Text("TODAY'S ITINERARY")
            .font(.caption)
            .fontWeight(.bold)
            .foregroundStyle(.secondary)
            .tracking(0.5)
            .padding(.horizontal, 16)
            .padding(.top, 12)
            .padding(.bottom, 6)
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 8) {
            Image(systemName: "calendar.badge.plus")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("No stops planned for today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 20)
    }

    // MARK: - Stops Timeline

    private var stopsTimeline: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(Array(todayStops.enumerated()), id: \.element.id) { index, stop in
                    timelineRow(stop: stop, index: index)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    private func timelineRow(stop: StopEntity, index: Int) -> some View {
        let isFirst = index == 0
        let isLast = index == todayStops.count - 1
        let isNext = stop.id == nextUpcomingStopID
        let stopIsPast = isStopPast(stop)

        return NavigationLink(destination: StopDetailView(stop: stop)) {
            TimelineStopRow(
                stop: stop,
                isFirst: isFirst,
                isLast: isLast,
                isNextUpcoming: isNext,
                isPast: stopIsPast
            )
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Stop Buttons

    private var addStopButton: some View {
        HStack(spacing: 10) {
            quickAddButton
            planStopButton
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var quickAddButton: some View {
        Button {
            showingQuickAdd = true
        } label: {
            quickAddLabel
        }
        .buttonStyle(.plain)
    }

    private var quickAddLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "location.fill")
                .font(.caption)
                .foregroundStyle(.green)
            Text("I'm Here")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.green)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.green.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private var planStopButton: some View {
        Button {
            showingAddStop = true
        } label: {
            planStopLabel
        }
        .buttonStyle(.plain)
    }

    private var planStopLabel: some View {
        HStack(spacing: 6) {
            Image(systemName: "plus.circle.fill")
                .font(.caption)
                .foregroundStyle(.blue)
            Text("Plan a Stop")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundStyle(.blue)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .padding(.horizontal, 12)
        .background(Color.blue.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var addStopSheet: some View {
        if let day = todayDay {
            AddStopSheet(day: day)
        }
    }

    @ViewBuilder
    private var quickAddSheet: some View {
        if let day = todayDay {
            QuickAddStopSheet(day: day)
        }
    }

    // MARK: - Helpers

    private func isStopPast(_ stop: StopEntity) -> Bool {
        guard let arrival = stop.arrivalTime else { return false }
        return arrival < Date()
    }
}
