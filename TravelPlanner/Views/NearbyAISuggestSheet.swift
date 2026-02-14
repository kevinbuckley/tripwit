import SwiftUI
import SwiftData
import TripCore

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26, *)
struct NearbyAISuggestSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let stop: StopEntity
    let day: DayEntity

    @State private var planner = AITripPlanner()
    @State private var selectedIndices: Set<Int> = []
    @State private var addedCount = 0

    var body: some View {
        NavigationStack {
            contentBody
                .navigationTitle("Nearby")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar { toolbarItems }
                .task { await generateNearby() }
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

    @ToolbarContentBuilder
    private var toolbarItems: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            if !planner.suggestions.isEmpty && !selectedIndices.isEmpty {
                Button {
                    addSelectedStops()
                } label: {
                    Text("Add \(selectedIndices.count)")
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - States

    private var generatingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Finding places near \(stop.name)...")
                .font(.headline)
                .multilineTextAlignment(.center)
            Text("Apple Intelligence is looking for nearby attractions and restaurants")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
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
                Task { await generateNearby() }
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
        VStack(spacing: 0) {
            if addedCount > 0 {
                addedBanner
            }

            List {
                nearbyHeader

                Section {
                    ForEach(Array(planner.suggestions.enumerated()), id: \.offset) { index, suggestion in
                        suggestionRow(suggestion, index: index)
                    }
                } header: {
                    Text("Tap to select, then add to Day \(day.dayNumber)")
                        .textCase(nil)
                } footer: {
                    Text("Powered by Apple Intelligence · On-device · Private")
                        .font(.caption2)
                }

                Section {
                    Button {
                        Task { await generateNearby() }
                    } label: {
                        Label("Generate More Ideas", systemImage: "arrow.clockwise")
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var nearbyHeader: some View {
        Section {
            HStack(spacing: 12) {
                Image(systemName: "location.circle.fill")
                    .font(.title2)
                    .foregroundColor(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Near \(stop.name)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(String(format: "%.4f, %.4f", stop.latitude, stop.longitude))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    private func suggestionRow(_ suggestion: SuggestedStop, index: Int) -> some View {
        let isSelected = selectedIndices.contains(index)
        let category = AITripPlanner.mapCategory(suggestion.category)

        return Button {
            toggleSelection(index)
        } label: {
            suggestionRowContent(suggestion, isSelected: isSelected, category: category)
        }
        .buttonStyle(.plain)
    }

    private func suggestionRowContent(_ suggestion: SuggestedStop, isSelected: Bool, category: StopCategory) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(isSelected ? .blue : .gray)

            VStack(alignment: .leading, spacing: 4) {
                Text(suggestion.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(suggestion.reason)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
                HStack(spacing: 8) {
                    categoryBadge(category)
                    durationBadge(suggestion.durationMinutes)
                }
            }

            Spacer()
        }
        .contentShape(Rectangle())
    }

    private func categoryBadge(_ category: StopCategory) -> some View {
        Label(categoryLabel(category), systemImage: categoryIcon(category))
            .font(.caption2)
            .fontWeight(.medium)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(categoryColor(category).opacity(0.15))
            .foregroundColor(categoryColor(category))
            .clipShape(Capsule())
    }

    private func durationBadge(_ minutes: Int) -> some View {
        let text = minutes >= 60 ? "\(minutes / 60)h \(minutes % 60)m" : "\(minutes)m"
        return Label(text, systemImage: "clock")
            .font(.caption2)
            .foregroundColor(.secondary)
    }

    private var addedBanner: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("\(addedCount) stop\(addedCount == 1 ? "" : "s") added to Day \(day.dayNumber)")
                .font(.subheadline)
                .fontWeight(.medium)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.1))
    }

    // MARK: - Actions

    private func toggleSelection(_ index: Int) {
        if selectedIndices.contains(index) {
            selectedIndices.remove(index)
        } else {
            selectedIndices.insert(index)
        }
    }

    private func generateNearby() async {
        selectedIndices = []
        let existingNames = day.stops.map(\.name)
        await planner.suggestNearby(
            stopName: stop.name,
            stopCategory: stop.category.rawValue,
            latitude: stop.latitude,
            longitude: stop.longitude,
            existingStops: existingNames
        )
    }

    private func addSelectedStops() {
        let manager = DataManager(modelContext: modelContext)
        var count = 0

        for index in selectedIndices.sorted() {
            guard index < planner.suggestions.count else { continue }
            let suggestion = planner.suggestions[index]
            let category = AITripPlanner.mapCategory(suggestion.category)

            manager.addStop(
                to: day,
                name: suggestion.name,
                latitude: 0,
                longitude: 0,
                category: category,
                notes: suggestion.reason
            )
            count += 1
        }

        addedCount += count
        selectedIndices = []
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
