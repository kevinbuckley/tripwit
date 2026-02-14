import SwiftUI
import SwiftData
import TripCore

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26, *)
struct PlanDayVibeSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let day: DayEntity
    let destination: String
    let totalDays: Int

    @State private var planner = AITripPlanner()
    @State private var selectedIndices: Set<Int> = []
    @State private var addedCount = 0
    @State private var customVibe = ""
    @State private var activeVibe: String?

    private let presetVibes: [(emoji: String, label: String, prompt: String)] = [
        ("😌", "Relaxing", "A relaxing, low-key day with great food, cozy cafés, parks, and no rushing"),
        ("🏛️", "Culture", "A culture-filled day with museums, galleries, historic sites, and local art"),
        ("🍽️", "Foodie", "An epic food day — best local dishes, street food, markets, bakeries, and fine dining"),
        ("🥾", "Adventure", "An adventurous active day — hiking, exploring off-the-beaten-path spots, and outdoor activities"),
        ("👨‍👩‍👧‍👦", "Family", "A family-friendly day with activities kids will love, easy dining, and fun attractions"),
        ("🛍️", "Shopping", "A shopping day — local markets, boutiques, artisan shops, and trendy neighborhoods"),
        ("📸", "Instagram", "A photogenic day hitting the most beautiful and scenic spots for amazing photos"),
        ("🌙", "Nightlife", "A day that starts late and ends late — brunch, sunset spots, cocktail bars, live music"),
    ]

    var body: some View {
        NavigationStack {
            Group {
                if activeVibe == nil {
                    vibePickerView
                } else {
                    resultsView
                }
            }
            .navigationTitle("Plan a Day")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { toolbarContent }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("Done") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            if activeVibe != nil && !selectedIndices.isEmpty {
                Button {
                    addSelectedStops()
                } label: {
                    Text("Add \(selectedIndices.count)")
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Vibe Picker

    private var vibePickerView: some View {
        ScrollView {
            VStack(spacing: 24) {
                vibeHeader
                presetVibeGrid
                customVibeSection
            }
            .padding()
        }
    }

    private var vibeHeader: some View {
        VStack(spacing: 8) {
            Image(systemName: "wand.and.stars")
                .font(.system(size: 44))
                .foregroundStyle(.purple)
            Text("What kind of day?")
                .font(.title2)
                .fontWeight(.bold)
            Text("Pick a vibe and AI will plan Day \(day.dayNumber) in \(destination)")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, 8)
    }

    private var presetVibeGrid: some View {
        LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            ForEach(Array(presetVibes.enumerated()), id: \.offset) { _, vibe in
                vibeChip(emoji: vibe.emoji, label: vibe.label, prompt: vibe.prompt)
            }
        }
    }

    private func vibeChip(emoji: String, label: String, prompt: String) -> some View {
        Button {
            activeVibe = prompt
            Task { await generateForVibe(prompt) }
        } label: {
            vibeChipLabel(emoji: emoji, label: label)
        }
        .buttonStyle(.plain)
    }

    private func vibeChipLabel(emoji: String, label: String) -> some View {
        VStack(spacing: 6) {
            Text(emoji)
                .font(.system(size: 32))
            Text(label)
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.primary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    private var customVibeSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Or describe your own vibe:")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            HStack(spacing: 10) {
                TextField("e.g. romantic evening with river views...", text: $customVibe, axis: .vertical)
                    .lineLimit(1...3)
                    .textFieldStyle(.roundedBorder)
                Button {
                    let vibe = customVibe.trimmingCharacters(in: .whitespaces)
                    guard !vibe.isEmpty else { return }
                    activeVibe = vibe
                    Task { await generateForVibe(vibe) }
                } label: {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.title2)
                        .foregroundColor(customVibe.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .purple)
                }
                .disabled(customVibe.trimmingCharacters(in: .whitespaces).isEmpty)
            }
        }
    }

    // MARK: - Results View

    @ViewBuilder
    private var resultsView: some View {
        if planner.isGenerating {
            generatingView
        } else if let error = planner.errorMessage {
            errorView(error)
        } else {
            suggestionsList
        }
    }

    private var generatingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Planning your day...")
                .font(.headline)
            vibeLabel
            Spacer()
        }
        .padding()
    }

    @ViewBuilder
    private var vibeLabel: some View {
        if let vibe = activeVibe {
            let matched = presetVibes.first { $0.prompt == vibe }
            if let matched = matched {
                Text("\(matched.emoji) \(matched.label) day in \(destination)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else {
                Text("\"\(vibe)\"")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .italic()
            }
        }
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
            HStack(spacing: 12) {
                Button("Try Again") {
                    if let vibe = activeVibe {
                        Task { await generateForVibe(vibe) }
                    }
                }
                .buttonStyle(.borderedProminent)
                Button("Pick Another Vibe") {
                    activeVibe = nil
                    planner.errorMessage = nil
                }
                .buttonStyle(.bordered)
            }
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
                vibeHeaderSection

                Section {
                    ForEach(Array(planner.suggestions.enumerated()), id: \.offset) { index, suggestion in
                        suggestionRow(suggestion, index: index)
                    }
                } header: {
                    Text("Tap to select stops for Day \(day.dayNumber)")
                        .textCase(nil)
                } footer: {
                    Text("Powered by Apple Intelligence · On-device · Private")
                        .font(.caption2)
                }

                Section {
                    Button {
                        if let vibe = activeVibe {
                            Task { await generateForVibe(vibe) }
                        }
                    } label: {
                        Label("Regenerate This Vibe", systemImage: "arrow.clockwise")
                    }
                    Button {
                        activeVibe = nil
                        planner.suggestions = []
                        selectedIndices = []
                    } label: {
                        Label("Pick a Different Vibe", systemImage: "wand.and.stars")
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private var vibeHeaderSection: some View {
        Section {
            HStack(spacing: 12) {
                vibeHeaderIcon
                VStack(alignment: .leading, spacing: 2) {
                    vibeHeaderTitle
                    Text("Day \(day.dayNumber) · \(destination)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    @ViewBuilder
    private var vibeHeaderIcon: some View {
        if let vibe = activeVibe, let matched = presetVibes.first(where: { $0.prompt == vibe }) {
            Text(matched.emoji)
                .font(.title)
        } else {
            Image(systemName: "wand.and.stars")
                .font(.title2)
                .foregroundColor(.purple)
        }
    }

    @ViewBuilder
    private var vibeHeaderTitle: some View {
        if let vibe = activeVibe, let matched = presetVibes.first(where: { $0.prompt == vibe }) {
            Text("\(matched.label) Day")
                .font(.subheadline)
                .fontWeight(.semibold)
        } else if let vibe = activeVibe {
            Text("\"\(vibe)\"")
                .font(.subheadline)
                .fontWeight(.semibold)
                .italic()
        }
    }

    private func suggestionRow(_ suggestion: SuggestedStop, index: Int) -> some View {
        let isSelected = selectedIndices.contains(index)
        let category = AITripPlanner.mapCategory(suggestion.category)
        let orderLabel = stopOrderLabel(index)

        return Button {
            toggleSelection(index)
        } label: {
            suggestionRowContent(suggestion, isSelected: isSelected, category: category, orderLabel: orderLabel)
        }
        .buttonStyle(.plain)
    }

    private func suggestionRowContent(_ suggestion: SuggestedStop, isSelected: Bool, category: StopCategory, orderLabel: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .font(.title3)
                .foregroundColor(isSelected ? .blue : .gray)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(orderLabel)
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.purple.opacity(0.7))
                        .clipShape(Capsule())
                    Text(suggestion.name)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                }
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

    private func stopOrderLabel(_ index: Int) -> String {
        let total = planner.suggestions.count
        if total <= 1 { return "Stop" }
        if index == 0 { return "Morning" }
        if index == total - 1 { return "Evening" }
        if index == total / 2 || (total > 4 && index == total / 2 - 1) { return "Lunch" }
        return "Stop \(index + 1)"
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

    // MARK: - Badges

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

    // MARK: - Actions

    private func toggleSelection(_ index: Int) {
        if selectedIndices.contains(index) {
            selectedIndices.remove(index)
        } else {
            selectedIndices.insert(index)
        }
    }

    private func generateForVibe(_ vibe: String) async {
        selectedIndices = []
        let existingNames = day.stops.map(\.name)
        await planner.planDayByVibe(
            vibe: vibe,
            destination: destination,
            dayNumber: day.dayNumber,
            totalDays: totalDays,
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
