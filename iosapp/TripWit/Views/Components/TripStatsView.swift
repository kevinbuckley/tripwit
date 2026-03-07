import SwiftUI
import Charts
import CoreData
import TripCore

// MARK: - TripStatsView

/// A fullscreen stats sheet driven entirely by `TripStatsDataSource` pure functions.
///
/// Three sections:
/// 1. Summary strip — total stops / days / categories at a glance
/// 2. Progress ring — animated circle showing visited fraction
/// 3. Stops per day — bar chart with the busiest day highlighted
/// 4. Category breakdown — animated donut + legend
struct TripStatsView: View {

    let trip: TripEntity
    @State private var appeared = false

    // MARK: - Derived data

    private var tripCoreDays: [Day] {
        trip.daysArray.map { day in
            let stops = day.stopsArray.map { stop in
                Stop(
                    dayId:     day.id ?? UUID(),
                    name:      stop.wrappedName,
                    latitude:  stop.latitude,
                    longitude: stop.longitude,
                    category:  StopCategory(rawValue: stop.wrappedCategoryRaw) ?? .other,
                    sortOrder: Int(stop.sortOrder)
                )
            }
            return Day(
                id:        day.id ?? UUID(),
                tripId:    trip.id ?? UUID(),
                date:      day.wrappedDate,
                dayNumber: Int(day.dayNumber),
                stops:     stops
            )
        }
    }

    private var activityPoints: [DayActivityPoint] {
        TripStatsDataSource.dayActivityPoints(from: tripCoreDays)
    }
    private var categorySlices: [CategorySlice] {
        TripStatsDataSource.categoryBreakdown(from: tripCoreDays)
    }
    private var allStops: [StopEntity] {
        trip.daysArray.flatMap { $0.stopsArray }
    }
    private var visitedCount: Int { allStops.filter(\.isVisited).count }
    private var snap: ProgressSnapshot {
        TripStatsDataSource.progressSnapshot(totalStops: allStops.count, visitedStops: visitedCount)
    }
    private var busiestStopCount: Int {
        activityPoints.map(\.stopCount).max() ?? 0
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    summaryStrip
                    progressSection
                    if !activityPoints.isEmpty { activitySection }
                    if !categorySlices.isEmpty { categorySection }
                    Spacer(minLength: 24)
                }
                .padding(.horizontal, 16)
                .padding(.top, 8)
            }
            .background(Color(.systemGroupedBackground).ignoresSafeArea())
            .navigationTitle("Trip Stats")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            // Tiny delay so the sheet is fully presented before chart animations fire
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                withAnimation(.spring(duration: 0.7, bounce: 0.1)) { appeared = true }
            }
        }
    }

    // MARK: - Summary Strip

    private var summaryStrip: some View {
        HStack(spacing: 0) {
            statChip(value: "\(allStops.count)",       label: "Stops",      icon: "mappin")
            Divider().frame(height: 36)
            statChip(value: "\(trip.daysArray.count)", label: "Days",       icon: "calendar")
            Divider().frame(height: 36)
            statChip(value: "\(categorySlices.count)", label: "Categories", icon: "square.grid.2x2.fill")
        }
        .padding(.vertical, 14)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func statChip(value: String, label: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.weight(.bold))
                .monospacedDigit()
                .contentTransition(.numericText())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Progress Ring

    private var progressSection: some View {
        card {
            sectionHeader("Progress", icon: "chart.pie.fill")

            HStack(spacing: 24) {
                // Animated ring
                ZStack {
                    Circle()
                        .stroke(Color(.systemFill), lineWidth: 10)
                    Circle()
                        .trim(from: 0, to: appeared ? snap.visitedFraction : 0)
                        .stroke(style: StrokeStyle(lineWidth: 10, lineCap: .round))
                        .foregroundStyle(progressColor)
                        .rotationEffect(.degrees(-90))
                        .animation(.spring(duration: 0.9, bounce: 0.2), value: appeared)
                    VStack(spacing: 0) {
                        Text("\(Int((appeared ? snap.visitedFraction : 0) * 100))%")
                            .font(.title3.weight(.bold))
                            .monospacedDigit()
                        Text("done")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                .frame(width: 84, height: 84)

                // Legend rows
                VStack(alignment: .leading, spacing: 10) {
                    legendRow("Visited",   count: snap.visitedStops,   color: progressColor)
                    legendRow("Remaining", count: snap.remainingStops, color: Color(.systemFill))
                    Divider()
                    legendRow("Total",     count: snap.totalStops,     color: .primary)
                }
            }
            .padding(.top, 8)
        }
    }

    private var progressColor: Color {
        switch snap.visitedFraction {
        case 1.0:       return .green
        case 0.5...:    return .blue
        default:        return .orange
        }
    }

    private func legendRow(_ label: String, count: Int, color: Color) -> some View {
        HStack(spacing: 8) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption).foregroundStyle(.secondary)
            Spacer()
            Text("\(count)")
                .font(.caption.weight(.semibold))
                .monospacedDigit()
                .foregroundStyle(.primary)
        }
    }

    // MARK: - Activity Bar Chart

    private var activitySection: some View {
        card {
            sectionHeader("Stops per Day", icon: "chart.bar.fill")

            Chart(activityPoints) { point in
                BarMark(
                    x: .value("Day",   point.label),
                    y: .value("Stops", appeared ? point.stopCount : 0)
                )
                .foregroundStyle(
                    point.stopCount == busiestStopCount && busiestStopCount > 0
                    ? Color.blue
                    : Color.blue.opacity(0.45)
                )
                .cornerRadius(5)
                .annotation(position: .top, alignment: .center) {
                    if point.stopCount > 0 {
                        Text("\(point.stopCount)")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
            .chartYAxis(.hidden)
            .chartXAxis {
                AxisMarks { value in
                    AxisValueLabel {
                        if let label = value.as(String.self) {
                            // "Day 3" → "D3" to save space
                            Text(label.replacingOccurrences(of: "Day ", with: "D"))
                                .font(.system(size: 9))
                        }
                    }
                }
            }
            .frame(height: 130)
            .animation(.spring(duration: 0.7, bounce: 0.1).delay(0.05), value: appeared)
            .padding(.top, 8)
        }
    }

    // MARK: - Category Donut

    private var categorySection: some View {
        card {
            sectionHeader("By Category", icon: "square.grid.2x2.fill")

            HStack(alignment: .center, spacing: 20) {
                // Donut
                Chart(categorySlices) { slice in
                    SectorMark(
                        angle: .value("Count", appeared ? slice.count : 0),
                        innerRadius: .ratio(0.56),
                        angularInset: 2
                    )
                    .foregroundStyle(color(for: slice.category))
                    .cornerRadius(4)
                }
                .frame(width: 104, height: 104)
                .animation(.spring(duration: 0.8, bounce: 0.15).delay(0.1), value: appeared)

                // Legend
                VStack(alignment: .leading, spacing: 7) {
                    ForEach(categorySlices) { slice in
                        HStack(spacing: 7) {
                            RoundedRectangle(cornerRadius: 2)
                                .fill(color(for: slice.category))
                                .frame(width: 10, height: 10)
                            Text(slice.category.rawValue.capitalized)
                                .font(.caption)
                                .foregroundStyle(.primary)
                            Spacer(minLength: 4)
                            Text("\(slice.count)")
                                .font(.caption.weight(.semibold))
                                .monospacedDigit()
                            Text(String(format: "%.0f%%", slice.fraction * 100))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .frame(width: 30, alignment: .trailing)
                        }
                    }
                }
            }
            .padding(.top, 8)
        }
    }

    // MARK: - Helpers

    @ViewBuilder
    private func card<Content: View>(@ViewBuilder _ content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            content()
        }
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground),
                    in: RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private func sectionHeader(_ title: String, icon: String) -> some View {
        Label(title, systemImage: icon)
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(.secondary)
    }

    private func color(for category: StopCategory) -> Color {
        switch category {
        case .restaurant:    return .orange
        case .attraction:    return .blue
        case .accommodation: return .purple
        case .transport:     return .teal
        case .activity:      return .green
        case .other:         return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    TripStatsView(trip: {
        let ctx = NSPersistentContainer(name: "TripWit").viewContext
        let t = TripEntity(context: ctx)
        t.id = UUID(); t.name = "Paris Adventure"; t.destination = "Paris"
        t.statusRaw = "planning"
        return t
    }())
}
