import SwiftUI
import CoreData
import TripCore

#if canImport(FoundationModels)
import FoundationModels

/// A lightweight suggestion picker for the Add Stop flow.
/// Shows AI-generated stop ideas based on nearby stops or the trip destination.
/// Single-tap selection returns a suggestion to the parent via completion handler.
@available(iOS 26, *)
struct AISuggestForAddStopSheet: View {

    @Environment(\.dismiss) private var dismiss

    let day: DayEntity
    let onSelect: (SuggestedStop) -> Void

    @State private var planner = AITripPlanner()

    private var destination: String {
        let dayLoc = day.wrappedLocation
        if !dayLoc.isEmpty { return dayLoc }
        return day.trip?.wrappedDestination ?? ""
    }

    /// Stops on this day that have coordinates.
    private var dayStopsWithCoords: [StopEntity] {
        day.stopsArray.filter { $0.latitude != 0 || $0.longitude != 0 }
    }

    /// Falls back to stops from other days if this day has no coordinates.
    private var referenceStops: [StopEntity] {
        if !dayStopsWithCoords.isEmpty {
            return dayStopsWithCoords
        }
        guard let trip = day.trip else { return [] }
        return trip.daysArray
            .flatMap { $0.stopsArray }
            .filter { $0.latitude != 0 || $0.longitude != 0 }
    }

    /// Whether we have nearby coordinates to use for suggestNearby.
    private var hasNearbyCoords: Bool {
        !referenceStops.isEmpty
    }

    /// Centroid of reference stops for nearby suggestions.
    private var centroid: (lat: Double, lon: Double) {
        guard !referenceStops.isEmpty else { return (0, 0) }
        let lats = referenceStops.map(\.latitude)
        let lons = referenceStops.map(\.longitude)
        return (lats.reduce(0, +) / Double(lats.count), lons.reduce(0, +) / Double(lons.count))
    }

    var body: some View {
        NavigationStack {
            contentBody
                .navigationTitle("AI Suggestions")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .task { await generate() }
        }
    }

    // MARK: - Content

    @ViewBuilder
    private var contentBody: some View {
        if planner.isGenerating {
            generatingView
        } else if let error = planner.errorMessage {
            errorView(error)
        } else if planner.suggestions.isEmpty {
            emptyView
        } else {
            suggestionsList
        }
    }

    private var generatingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text(hasNearbyCoords ? "Finding places nearby..." : "Thinking about \(destination)...")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Tap a suggestion to use it")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await generate() }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "sparkles")
                .font(.system(size: 44))
                .foregroundStyle(.purple)
            Text("No suggestions yet")
                .font(.headline)
            Spacer()
        }
        .padding()
    }

    // MARK: - Suggestions List

    private var suggestionsList: some View {
        List {
            Section {
                ForEach(Array(planner.suggestions.enumerated()), id: \.offset) { _, suggestion in
                    suggestionRow(suggestion)
                }
            } header: {
                Text(hasNearbyCoords ? "Places near your stops" : "Suggestions for \(destination)")
                    .textCase(nil)
            } footer: {
                Text("Powered by Apple Intelligence · On-device · Private")
                    .font(.caption2)
            }

            Section {
                Button {
                    Task { await generate() }
                } label: {
                    Label("Generate More Ideas", systemImage: "arrow.clockwise")
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    private func suggestionRow(_ suggestion: SuggestedStop) -> some View {
        let category = AITripPlanner.mapCategory(suggestion.category)

        return Button {
            onSelect(suggestion)
            dismiss()
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                    Text(suggestion.reason)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                    HStack(spacing: 8) {
                        categoryBadge(category)
                        durationBadge(suggestion.durationMinutes)
                    }
                }
                Spacer()
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.purple)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Badges

    private func categoryBadge(_ category: StopCategory) -> some View {
        let label = categoryLabel(category)
        let icon = categoryIcon(category)
        return Label(label, systemImage: icon)
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(categoryColor(category).opacity(0.15))
            .foregroundStyle(categoryColor(category))
            .clipShape(Capsule())
    }

    private func durationBadge(_ minutes: Int) -> some View {
        let text = minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
        return Label(text, systemImage: "clock")
            .font(.caption2)
            .foregroundStyle(.secondary)
    }

    // MARK: - AI Generation

    private func generate() async {
        let existingNames = day.stopsArray.map(\.wrappedName)

        if hasNearbyCoords {
            // Use nearby suggestions based on centroid of existing stops
            let center = centroid
            let refStop = referenceStops.first
            await planner.suggestNearby(
                stopName: refStop?.wrappedName ?? destination,
                stopCategory: refStop?.category.rawValue ?? "attraction",
                latitude: center.lat,
                longitude: center.lon,
                existingStops: existingNames,
                radiusMiles: 2.0
            )
        } else {
            // Fall back to destination-based suggestions
            let totalDays = Int(day.trip?.daysArray.count ?? 1)
            await planner.suggestStops(
                destination: destination,
                dayNumber: Int(day.dayNumber),
                totalDays: totalDays,
                existingStops: existingNames
            )
        }
    }

    // MARK: - Helpers

    private func categoryLabel(_ cat: StopCategory) -> String {
        switch cat {
        case .accommodation: "Stay"
        case .restaurant: "Food"
        case .attraction: "See"
        case .transport: "Transit"
        case .activity: "Do"
        case .other: "Other"
        }
    }

    private func categoryIcon(_ cat: StopCategory) -> String {
        switch cat {
        case .accommodation: "bed.double.fill"
        case .restaurant: "fork.knife"
        case .attraction: "star.fill"
        case .transport: "airplane"
        case .activity: "figure.run"
        case .other: "mappin"
        }
    }

    private func categoryColor(_ cat: StopCategory) -> Color {
        switch cat {
        case .accommodation: .purple
        case .restaurant: .orange
        case .attraction: .yellow
        case .transport: .blue
        case .activity: .green
        case .other: .gray
        }
    }
}
#endif
