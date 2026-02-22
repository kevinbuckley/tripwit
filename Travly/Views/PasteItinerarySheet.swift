import SwiftUI
import CoreData
import MapKit
import TripCore

// MARK: - Parsed Data Types (used by both AI and regex parsers)

struct ParsedStop: Identifiable {
    let id = UUID()
    var name: String
    var note: String
    var category: StopCategory
    var durationMinutes: Int
}

struct ParsedDay: Identifiable {
    let id = UUID()
    var dayNumber: Int
    var stops: [ParsedStop]
}

// MARK: - Regex-Based Itinerary Parser (works on all devices)

struct ItineraryTextParser {

    /// Parse free-form itinerary text into structured days and stops using heuristics.
    static func parse(text: String, totalDays: Int) -> [ParsedDay] {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        var days: [ParsedDay] = []
        var currentDayNumber = 1
        var currentStops: [ParsedStop] = []

        for line in lines {
            // Check if this line is a day header
            if let dayNum = parseDayHeader(line, maxDay: totalDays) {
                // Save previous day if it has stops
                if !currentStops.isEmpty {
                    days.append(ParsedDay(dayNumber: currentDayNumber, stops: currentStops))
                    currentStops = []
                }
                currentDayNumber = dayNum
                continue
            }

            // Try to parse as a stop
            if let stop = parseStopLine(line) {
                currentStops.append(stop)
            }
        }

        // Save the last day
        if !currentStops.isEmpty {
            days.append(ParsedDay(dayNumber: currentDayNumber, stops: currentStops))
        }

        // Clamp day numbers to trip range
        return days.map { day in
            var d = day
            d.dayNumber = min(max(d.dayNumber, 1), totalDays)
            return d
        }
    }

    // MARK: - Day Header Detection

    private static func parseDayHeader(_ line: String, maxDay: Int) -> Int? {
        let lowered = line.lowercased()

        // "Day 1", "Day 1:", "Day 1 -", "Day 1 –", "**Day 1**", "## Day 1"
        let dayPatterns: [String] = [
            #"(?:^|\*{1,2}|#{1,3}\s*)day\s+(\d+)"#,
        ]

        for pattern in dayPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: lowered, range: NSRange(lowered.startIndex..., in: lowered)),
               let numRange = Range(match.range(at: 1), in: lowered),
               let num = Int(lowered[numRange]) {
                return min(num, maxDay)
            }
        }

        return nil
    }

    // MARK: - Stop Line Detection

    private static func parseStopLine(_ line: String) -> ParsedStop? {
        var cleaned = line

        // Strip markdown formatting: **, *, -, •, numbered list prefixes
        let prefixPatterns = [
            #"^\s*[-•*]\s*"#,           // bullet points
            #"^\s*\d+[.)]\s*"#,          // numbered lists
            #"^\s*\*{1,2}(.*?)\*{1,2}"#, // bold text (we keep inner content)
        ]

        for pattern in prefixPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: []) {
                let range = NSRange(cleaned.startIndex..., in: cleaned)
                if let match = regex.firstMatch(in: cleaned, range: range) {
                    // For bold pattern, extract inner text
                    if pattern.contains("\\*") && match.numberOfRanges > 1,
                       let innerRange = Range(match.range(at: 1), in: cleaned) {
                        let boldText = String(cleaned[innerRange])
                        let afterBold = String(cleaned[cleaned.index(cleaned.startIndex, offsetBy: match.range.upperBound)...])
                        cleaned = boldText + afterBold
                    } else {
                        cleaned = String(cleaned[cleaned.index(cleaned.startIndex, offsetBy: match.range.upperBound)...])
                    }
                }
            }
        }

        // Strip remaining markdown bold/italic markers
        cleaned = cleaned.replacingOccurrences(of: "**", with: "")
        cleaned = cleaned.replacingOccurrences(of: "__", with: "")
        cleaned = cleaned.trimmingCharacters(in: .whitespaces)

        // Skip empty lines or very short lines (likely headers or separators)
        guard cleaned.count >= 3 else { return nil }

        // Skip lines that look like section headers without stop info
        let skipPatterns = [
            #"^(morning|afternoon|evening|night|lunch|dinner|breakfast|brunch)$"#,
            #"^(overview|summary|tips|notes|budget|getting around|transportation).*$"#,
        ]
        for pattern in skipPatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) != nil {
                return nil
            }
        }

        // Extract time-of-day prefix like "Morning:", "10:00 AM:", etc.
        var note = ""
        var stopName = cleaned

        // Match "Morning: Place Name" or "10:00 AM - Place Name" patterns
        let timePatterns = [
            #"^(morning|afternoon|evening|night|lunch|dinner|breakfast|brunch)\s*[:–\-]\s*"#,
            #"^\d{1,2}:\d{2}\s*(?:am|pm)?\s*[:–\-]\s*"#,
            #"^\d{1,2}\s*(?:am|pm)\s*[:–\-]\s*"#,
        ]
        for pattern in timePatterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: stopName, range: NSRange(stopName.startIndex..., in: stopName)) {
                let prefix = String(stopName[Range(match.range, in: stopName)!])
                note = prefix.trimmingCharacters(in: .whitespaces).trimmingCharacters(in: CharacterSet(charactersIn: ":-–"))
                stopName = String(stopName[stopName.index(stopName.startIndex, offsetBy: match.range.upperBound)...])
                    .trimmingCharacters(in: .whitespaces)
                break
            }
        }

        // Extract parenthetical notes like "(2 hours)" or "(great views)"
        if let parenRegex = try? NSRegularExpression(pattern: #"\(([^)]+)\)"#),
           let match = parenRegex.firstMatch(in: stopName, range: NSRange(stopName.startIndex..., in: stopName)),
           let innerRange = Range(match.range(at: 1), in: stopName) {
            let parenContent = String(stopName[innerRange])
            if !note.isEmpty { note += " · " }
            note += parenContent
            stopName = parenRegex.stringByReplacingMatches(
                in: stopName,
                range: NSRange(stopName.startIndex..., in: stopName),
                withTemplate: ""
            ).trimmingCharacters(in: .whitespaces)
        }

        // Split on " - " or " – " to separate name from description
        let separators = [" - ", " – ", " — ", ": "]
        for sep in separators {
            if let sepRange = stopName.range(of: sep) {
                let possibleName = String(stopName[stopName.startIndex..<sepRange.lowerBound]).trimmingCharacters(in: .whitespaces)
                let description = String(stopName[sepRange.upperBound...]).trimmingCharacters(in: .whitespaces)
                // Only split if the first part looks like a place name (not too long)
                if possibleName.count >= 3 && possibleName.count <= 80 {
                    stopName = possibleName
                    if !description.isEmpty {
                        if !note.isEmpty { note += " · " }
                        note += description
                    }
                    break
                }
            }
        }

        stopName = stopName.trimmingCharacters(in: .whitespaces)
        guard stopName.count >= 2 else { return nil }

        // Guess category from keywords
        let category = guessCategory(name: stopName, note: note)

        // Guess duration from category
        let duration = guessDuration(category: category, note: note)

        return ParsedStop(
            name: stopName,
            note: note,
            category: category,
            durationMinutes: duration
        )
    }

    // MARK: - Category Guessing

    private static func guessCategory(name: String, note: String) -> StopCategory {
        let combined = (name + " " + note).lowercased()

        let restaurantKeywords = ["restaurant", "café", "cafe", "bistro", "bakery", "bar", "pub",
                                   "food", "eat", "lunch", "dinner", "breakfast", "brunch", "ramen",
                                   "sushi", "pizza", "coffee", "tea house", "patisserie", "brasserie",
                                   "trattoria", "tavern", "grill", "deli", "market hall", "food hall"]
        let attractionKeywords = ["museum", "gallery", "temple", "shrine", "cathedral", "church",
                                   "palace", "castle", "tower", "monument", "memorial", "park",
                                   "garden", "bridge", "viewpoint", "landmark", "basilica", "ruins",
                                   "library", "opera", "theater", "theatre", "square", "plaza",
                                   "arch", "fountain", "statue"]
        let activityKeywords = ["tour", "cruise", "hike", "walk", "shop", "shopping", "market",
                                 "spa", "beach", "swim", "kayak", "bike", "cycle", "class",
                                 "workshop", "show", "concert", "festival", "experience", "explore"]
        let transportKeywords = ["airport", "station", "terminal", "port", "train", "bus", "ferry",
                                  "taxi", "transfer", "departure", "arrival", "check-in", "checkout"]
        let accommodationKeywords = ["hotel", "hostel", "airbnb", "resort", "lodge", "inn", "motel",
                                      "accommodation", "check in", "check-in"]

        if restaurantKeywords.contains(where: { combined.contains($0) }) { return .restaurant }
        if attractionKeywords.contains(where: { combined.contains($0) }) { return .attraction }
        if activityKeywords.contains(where: { combined.contains($0) }) { return .activity }
        if transportKeywords.contains(where: { combined.contains($0) }) { return .transport }
        if accommodationKeywords.contains(where: { combined.contains($0) }) { return .accommodation }

        return .attraction // default
    }

    private static func guessDuration(category: StopCategory, note: String) -> Int {
        // Try to extract explicit duration from note
        let lowNote = note.lowercased()
        if let hourRegex = try? NSRegularExpression(pattern: #"(\d+)\s*(?:hr|hour)"#),
           let match = hourRegex.firstMatch(in: lowNote, range: NSRange(lowNote.startIndex..., in: lowNote)),
           let numRange = Range(match.range(at: 1), in: lowNote),
           let hours = Int(lowNote[numRange]) {
            return hours * 60
        }
        if let minRegex = try? NSRegularExpression(pattern: #"(\d+)\s*(?:min)"#),
           let match = minRegex.firstMatch(in: lowNote, range: NSRange(lowNote.startIndex..., in: lowNote)),
           let numRange = Range(match.range(at: 1), in: lowNote),
           let mins = Int(lowNote[numRange]) {
            return mins
        }

        // Default durations by category
        switch category {
        case .restaurant: return 75
        case .attraction: return 90
        case .activity: return 120
        case .transport: return 30
        case .accommodation: return 0
        case .other: return 60
        }
    }
}

// MARK: - PasteItinerarySheet

struct PasteItinerarySheet: View {

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let trip: TripEntity

    @State private var inputText = ""
    @State private var phase: Phase = .input
    @State private var parsedDays: [ParsedDay] = []
    @State private var selectedStops: Set<String> = [] // "dayNum-stopIndex"
    @State private var addedCount = 0
    @State private var geocodingInProgress = false
    @State private var parseErrorMessage: String?

    /// Holds a reference to AITripPlanner when available (stored as Any to avoid availability issues).
    @State private var aiPlannerRef: AnyObject?

    private enum Phase {
        case input
        case parsing
        case preview
        case error(String)
    }

    private var sortedDays: [DayEntity] {
        trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }
    }

    private var hasAI: Bool {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            return AITripPlanner.isDeviceSupported
        }
        #endif
        return false
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
        HStack(spacing: 8) {
            Image(systemName: hasAI ? "sparkles" : "text.magnifyingglass")
                .foregroundStyle(.purple)
            Text(hasAI
                 ? "Apple Intelligence will parse your text into stops"
                 : "Your text will be parsed into stops automatically")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity)
        .background(Color.purple.opacity(0.08))
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
            Text(hasAI
                 ? "Apple Intelligence is extracting stops from your text"
                 : "Extracting stops from your text")
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
                summarySection

                ForEach(parsedDays.sorted(by: { $0.dayNumber < $1.dayNumber })) { parsedDay in
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
            .listStyle(.insetGrouped)
        }
    }

    private var summarySection: some View {
        let totalStops = parsedDays.reduce(0) { $0 + $1.stops.count }
        return Section {
            HStack(spacing: 12) {
                Image(systemName: "checkmark.seal.fill")
                    .font(.title2)
                    .foregroundStyle(.green)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Found \(totalStops) stop\(totalStops == 1 ? "" : "s") across \(parsedDays.count) day\(parsedDays.count == 1 ? "" : "s")")
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

    private func dayPreviewSection(_ parsedDay: ParsedDay) -> some View {
        let dayNum = min(parsedDay.dayNumber, sortedDays.count)
        let dayEntity = dayNum > 0 && dayNum <= sortedDays.count ? sortedDays[dayNum - 1] : nil
        let dateStr = dayEntity?.formattedDate ?? ""

        return Section {
            ForEach(Array(parsedDay.stops.enumerated()), id: \.element.id) { index, stop in
                let key = "\(parsedDay.dayNumber)-\(index)"
                let isSelected = selectedStops.contains(key)

                Button {
                    toggleStop(key)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                            .font(.title3)
                            .foregroundStyle(isSelected ? .blue : .gray)

                        VStack(alignment: .leading, spacing: 4) {
                            Text(stop.name)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundStyle(.primary)
                            if !stop.note.isEmpty {
                                Text(stop.note)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .lineLimit(2)
                            }
                            HStack(spacing: 8) {
                                categoryBadge(stop.category)
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
                .foregroundStyle(.green)
            Text("\(addedCount) stop\(addedCount == 1 ? "" : "s") added to \(trip.wrappedName)")
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

        if hasAI {
            parseWithAI()
        } else {
            parseWithRegex()
        }
    }

    private func parseWithRegex() {
        // Run on background to avoid blocking UI
        Task {
            let result = ItineraryTextParser.parse(
                text: inputText,
                totalDays: trip.durationInDays
            )

            await MainActor.run {
                if result.isEmpty || result.allSatisfy({ $0.stops.isEmpty }) {
                    phase = .error("Could not find any stops in the text. Try formatting each stop on its own line, optionally grouped under \"Day 1\", \"Day 2\", etc.")
                } else {
                    parsedDays = result
                    selectAll()
                    phase = .preview
                }
            }
        }
    }

    private func parseWithAI() {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            let planner = AITripPlanner()
            self.aiPlannerRef = planner
            Task {
                await planner.parseItinerary(
                    text: inputText,
                    destination: trip.wrappedDestination,
                    totalDays: trip.durationInDays
                )
                if let parsed = planner.parsedItinerary {
                    // Convert AI result to our local ParsedDay/ParsedStop types
                    parsedDays = parsed.days.map { aiDay in
                        ParsedDay(
                            dayNumber: aiDay.dayNumber,
                            stops: aiDay.stops.map { aiStop in
                                ParsedStop(
                                    name: aiStop.name,
                                    note: aiStop.note,
                                    category: AITripPlanner.mapCategory(aiStop.category),
                                    durationMinutes: aiStop.durationMinutes
                                )
                            }
                        )
                    }
                    if parsedDays.isEmpty || parsedDays.allSatisfy({ $0.stops.isEmpty }) {
                        // AI returned nothing — fall back to regex
                        parseWithRegex()
                    } else {
                        selectAll()
                        phase = .preview
                    }
                } else {
                    // AI failed — fall back to regex
                    parseWithRegex()
                }
            }
            return
        }
        #endif
        parseWithRegex()
    }

    private func toggleStop(_ key: String) {
        if selectedStops.contains(key) {
            selectedStops.remove(key)
        } else {
            selectedStops.insert(key)
        }
    }

    private var totalStopsCount: Int {
        parsedDays.reduce(0) { $0 + $1.stops.count }
    }

    private func selectAll() {
        selectedStops.removeAll()
        for parsedDay in parsedDays {
            for index in 0..<parsedDay.stops.count {
                selectedStops.insert("\(parsedDay.dayNumber)-\(index)")
            }
        }
    }

    private func addSelectedStops() {
        let manager = DataManager(context: viewContext)
        var count = 0
        var addedStopEntities: [(StopEntity, String)] = []

        for parsedDay in parsedDays {
            let dayNum = min(max(parsedDay.dayNumber, 1), sortedDays.count)
            guard dayNum > 0, dayNum <= sortedDays.count else { continue }
            let dayEntity = sortedDays[dayNum - 1]

            for (index, parsedStop) in parsedDay.stops.enumerated() {
                let key = "\(parsedDay.dayNumber)-\(index)"
                guard selectedStops.contains(key) else { continue }

                let stop = manager.addStop(
                    to: dayEntity,
                    name: parsedStop.name,
                    latitude: 0,
                    longitude: 0,
                    category: parsedStop.category,
                    notes: parsedStop.note
                )
                let geocodeDest = dayEntity.wrappedLocation.isEmpty ? trip.wrappedDestination : dayEntity.wrappedLocation
                addedStopEntities.append((stop, geocodeDest))
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

        // Auto-dismiss after a brief moment so user sees success
        Task {
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run { dismiss() }
        }
    }

    private func geocodeStops(_ stops: [(StopEntity, String)]) async {
        let geocoder = CLGeocoder()
        for (stop, destination) in stops {
            let query = "\(stop.wrappedName), \(destination)"
            do {
                let placemarks = try await geocoder.geocodeAddressString(query)
                if let location = placemarks.first?.location {
                    await MainActor.run {
                        stop.latitude = location.coordinate.latitude
                        stop.longitude = location.coordinate.longitude
                        stop.day?.trip?.updatedAt = Date()
                        try? viewContext.save()
                    }
                }
            } catch {
                // Geocoding failed — leave coordinates at 0,0
            }
            // Rate limit
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
            .foregroundStyle(categoryColor(category))
            .clipShape(Capsule())
    }

    private func durationBadge(_ minutes: Int) -> some View {
        let text: String
        if minutes >= 60 {
            let h = minutes / 60
            let m = minutes % 60
            text = m > 0 ? "\(h)h \(m)m" : "\(h)h"
        } else {
            text = "\(minutes)m"
        }
        return Label(text, systemImage: "clock")
            .font(.caption2)
            .foregroundStyle(.secondary)
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
