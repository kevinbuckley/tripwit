import SwiftUI
import SwiftData
import MapKit
import TripCore

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26, *)
struct PasteItinerarySheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss

    let trip: TripEntity

    @State private var planner = AITripPlanner()
    @State private var inputText = ""
    @State private var phase: Phase = .input
    @State private var selectedStops: Set<String> = [] // "dayNum-stopIndex"
    @State private var addedCount = 0
    @State private var geocodingInProgress = false

    private enum Phase {
        case input
        case parsing
        case preview
        case error(String)
    }

    private var sortedDays: [DayEntity] {
        trip.days.sorted { $0.dayNumber < $1.dayNumber }
    }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Paste Itinerary")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        confirmationButton
                    }
                }
        }
    }

    // MARK: - Content Router

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .input:
            inputView
        case .parsing:
            parsingView
        case .preview:
            previewView
        case .error(let message):
            errorView(message)
        }
    }

    @ViewBuilder
    private var confirmationButton: some View {
        switch phase {
        case .input:
            Button("Parse") { parseText() }
                .fontWeight(.semibold)
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).count < 10)
        case .preview:
            if !selectedStops.isEmpty {
                Button("Add \(selectedStops.count)") { addSelectedStops() }
                    .fontWeight(.semibold)
            }
        default:
            EmptyView()
        }
    }

    // MARK: - Input Phase

    private var inputView: some View {
        VStack(spacing: 0) {
            pasteHeader

            TextEditor(text: $inputText)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 4)
                .overlay(
                    Group {
                        if inputText.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "doc.on.clipboard")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.tertiary)
                                Text("Paste your itinerary here")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text("From ChatGPT, a travel blog,\na friend's message — any text works")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .allowsHitTesting(false)
                        }
                    }
                )

            pasteFromClipboardButton
        }
    }

    private var pasteHeader: some View {
        VStack(spacing: 4) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundStyle(.purple)
                Text("Apple Intelligence will parse your text into stops")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.purple.opacity(0.08))
        }
    }

    private var pasteFromClipboardButton: some View {
        Button {
            if let clipboard = UIPasteboard.general.string, !clipboard.isEmpty {
                inputText = clipboard
            }
        } label: {
            Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
        }
        .buttonStyle(.borderedProminent)
        .tint(.purple)
        .padding(.horizontal)
        .padding(.bottom, 12)
    }

    // MARK: - Parsing Phase

    private var parsingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Parsing your itinerary...")
                .font(.headline)
            Text("Apple Intelligence is extracting stops from your text")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    // MARK: - Error Phase

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
            HStack(spacing: 16) {
                Button("Edit Text") {
                    phase = .input
                }
                .buttonStyle(.bordered)
                Button("Try Again") {
                    parseText()
                }
                .buttonStyle(.borderedProminent)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Preview Phase

    private var previewView: some View {
        VStack(spacing: 0) {
            if addedCount > 0 {
                addedBanner
            }

            List {
                if let parsed = planner.parsedItinerary {
                    summarySection(parsed)

                    ForEach(parsed.days.sorted(by: { $0.dayNumber < $1.dayNumber }), id: \.dayNumber) { parsedDay in
                        dayPreviewSection(parsedDay)
                    }

                    Section {
                        Button {
                            phase = .input
                        } label: {
                            Label("Edit Original Text", systemImage: "pencil")
                        }
                    }
                }
            }
            .listStyle(.insetGrouped)
        }
    }

    private func summarySection(_ parsed: ParsedItinerary) -> some View {
        let totalStops = parsed.days.reduce(0) { $0 + $1.stops.count }
        return Section {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundColor(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Found \(totalStops) stop\(totalStops == 1 ? "" : "s") across \(parsed.days.count) day\(parsed.days.count == 1 ? "" : "s")")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text("Tap to select, then add to your trip")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                selectAll()
            } label: {
                Label(
                    selectedStops.count == totalStopsCount ? "Deselect All" : "Select All",
                    systemImage: selectedStops.count == totalStopsCount ? "xmark.circle" : "checkmark.circle"
                )
                .font(.subheadline)
            }
        }
    }

    private func dayPreviewSection(_ parsedDay: ParsedItineraryDay) -> some View {
        let dayNum = min(parsedDay.dayNumber, sortedDays.count)
        let dayEntity = dayNum > 0 && dayNum <= sortedDays.count ? sortedDays[dayNum - 1] : nil
        let dateStr = dayEntity?.formattedDate ?? ""

        return Section {
            ForEach(Array(parsedDay.stops.enumerated()), id: \.offset) { index, stop in
                let key = "\(parsedDay.dayNumber)-\(index)"
                let isSelected = selectedStops.contains(key)
                let category = AITripPlanner.mapCategory(stop.category)

                Button {
                    toggleStop(key)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundColor(isSelected ? .blue : .gray)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(stop.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            if !stop.note.isEmpty {
                                Text(stop.note)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(2)
                            }
                            HStack(spacing: 8) {
                                categoryBadge(category)
                                if stop.durationMinutes > 0 {
                                    durationBadge(stop.durationMinutes)
                                }
                            }
                        }

                        Spacer()
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
            }
        } header: {
            HStack {
                Text("Day \(parsedDay.dayNumber)")
                    .fontWeight(.semibold)
                Spacer()
                if !dateStr.isEmpty {
                    Text(dateStr)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var addedBanner: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            Text("\(addedCount) stop\(addedCount == 1 ? "" : "s") added to \(trip.name)")
                .font(.subheadline)
                .fontWeight(.medium)
            if geocodingInProgress {
                Spacer()
                ProgressView()
                    .controlSize(.small)
                Text("Geocoding...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal)
        .padding(.vertical, 10)
        .background(Color.green.opacity(0.1))
    }

    // MARK: - Actions

    private func parseText() {
        phase = .parsing
        Task {
            await planner.parseItinerary(
                text: inputText,
                destination: trip.destination,
                totalDays: trip.durationInDays
            )
            if let _ = planner.parsedItinerary {
                selectAll()
                phase = .preview
            } else {
                phase = .error(planner.errorMessage ?? "Could not parse the itinerary. Please try again.")
            }
        }
    }

    private func toggleStop(_ key: String) {
        if selectedStops.contains(key) {
            selectedStops.remove(key)
        } else {
            selectedStops.insert(key)
        }
    }

    private var totalStopsCount: Int {
        planner.parsedItinerary?.days.reduce(0) { $0 + $1.stops.count } ?? 0
    }

    private func selectAll() {
        selectedStops.removeAll()
        guard let parsed = planner.parsedItinerary else { return }
        for parsedDay in parsed.days {
            for index in 0..<parsedDay.stops.count {
                selectedStops.insert("\(parsedDay.dayNumber)-\(index)")
            }
        }
    }

    private func addSelectedStops() {
        guard let parsed = planner.parsedItinerary else { return }
        let manager = DataManager(modelContext: modelContext)
        var count = 0
        var addedStopEntities: [(StopEntity, String)] = [] // (entity, destination for geocoding)

        for parsedDay in parsed.days {
            let dayNum = min(max(parsedDay.dayNumber, 1), sortedDays.count)
            guard dayNum > 0, dayNum <= sortedDays.count else { continue }
            let dayEntity = sortedDays[dayNum - 1]

            for (index, parsedStop) in parsedDay.stops.enumerated() {
                let key = "\(parsedDay.dayNumber)-\(index)"
                guard selectedStops.contains(key) else { continue }

                let category = AITripPlanner.mapCategory(parsedStop.category)
                let stop = manager.addStop(
                    to: dayEntity,
                    name: parsedStop.name,
                    latitude: 0,
                    longitude: 0,
                    category: category,
                    notes: parsedStop.note
                )
                addedStopEntities.append((stop, trip.destination))
                count += 1
            }
        }

        addedCount += count
        selectedStops = []

        // Background geocoding
        if !addedStopEntities.isEmpty {
            geocodingInProgress = true
            Task {
                await geocodeStops(addedStopEntities)
                geocodingInProgress = false
            }
        }
    }

    private func geocodeStops(_ stops: [(StopEntity, String)]) async {
        let geocoder = CLGeocoder()
        for (stop, destination) in stops {
            let query = "\(stop.name), \(destination)"
            do {
                let placemarks = try await geocoder.geocodeAddressString(query)
                if let location = placemarks.first?.location {
                    await MainActor.run {
                        stop.latitude = location.coordinate.latitude
                        stop.longitude = location.coordinate.longitude
                        try? modelContext.save()
                    }
                }
            } catch {
                // Geocoding failed for this stop — leave coordinates at 0,0
            }
            // Rate limit: Apple recommends max 1 request per second
            try? await Task.sleep(for: .milliseconds(600))
        }
    }

    // MARK: - UI Helpers

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
        let text = minutes >= 60 ? "\(minutes / 60)h \(minutes % 60 > 0 ? " \(minutes % 60)m" : "")" : "\(minutes)m"
        return Label(text, systemImage: "clock")
            .font(.caption2)
            .foregroundColor(.secondary)
    }

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
