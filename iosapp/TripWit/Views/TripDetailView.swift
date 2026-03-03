import SwiftUI
import CoreData
import MapKit
import CoreLocation
import TripCore

struct TripDetailView: View {

    @Environment(\.managedObjectContext) private var viewContext

    @ObservedObject var trip: TripEntity

    @State private var showingEditTrip = false
    @State private var showingAddStop = false
    @State private var selectedDayForStop: DayEntity?
    @State private var travelTimeService = TravelTimeService()
    @State private var weatherService = WeatherService()
    @State private var stopToDelete: StopEntity?
    @State private var dayForLocationEdit: DayEntity?
    @State private var dayForNotesEdit: DayEntity?
    @State private var editingDayNotes: String = ""
    @State private var calendarExportMessage: String?
    @State private var showingCalendarResult = false
    @State private var isExportingCalendar = false
    @State private var draggingStopID: String?
    @State private var dropTargetDayID: UUID?

    private var sortedDays: [DayEntity] {
        trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }
    }

    /// Groups consecutive days that share the same location into segments.
    private var locationSegments: [(location: String, days: [DayEntity])] {
        var segments: [(location: String, days: [DayEntity])] = []
        for day in sortedDays {
            let loc = day.wrappedLocation.isEmpty ? trip.wrappedDestination : day.wrappedLocation
            if let last = segments.last, last.location == loc {
                segments[segments.count - 1].days.append(day)
            } else {
                segments.append((location: loc, days: [day]))
            }
        }
        return segments
    }

    private var dateFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }

    var body: some View {
        if trip.isDeleted || trip.managedObjectContext == nil {
            deletedTripView
        } else {
            tripList
                .toolbar { tripToolbar }
        }
    }

    /// Shown when the observed trip has been deleted.
    private var deletedTripView: some View {
        VStack(spacing: 16) {
            Image(systemName: "trash.circle")
                .font(.system(size: 48))
                .foregroundStyle(.secondary)
            Text("Trip No Longer Available")
                .font(.title3)
                .fontWeight(.semibold)
            Text("This trip may have been deleted.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .navigationTitle("Trip Removed")
    }

    // MARK: - Trip List

    private var tripList: some View {
        List {
            headerSection

            if !sortedDays.isEmpty {
                let segments = locationSegments
                let isMultiCity = segments.count > 1

                ForEach(Array(segments.enumerated()), id: \.offset) { segIndex, segment in
                    if isMultiCity {
                        locationHeader(segment.location, days: segment.days)
                    }
                    ForEach(segment.days) { day in
                        daySection(day)
                    }
                }
            }

            // MARK: - Planning Todos (aggregated)
            planningTodosSection

            TripListsSection(trip: trip)
        }
        .listStyle(.insetGrouped)
        .navigationTitle(trip.wrappedName)
        .navigationBarTitleDisplayMode(.large)
        .task(id: trip.objectID) {
            if !trip.isPast {
                await weatherService.fetchWeather(
                    destination: weatherLocation,
                    startDate: trip.wrappedStartDate,
                    endDate: trip.wrappedEndDate
                )
            }
        }
        .alert("Calendar", isPresented: $showingCalendarResult) {
            Button("OK", role: .cancel) { }
        } message: {
            if let message = calendarExportMessage {
                Text(message)
            }
        }
        .sheet(isPresented: $showingEditTrip) {
            EditTripSheet(trip: trip)
        }
        .sheet(item: $selectedDayForStop) { day in
            AddStopSheet(day: day)
        }
        .sheet(item: $dayForLocationEdit) { day in
            SetDayLocationSheet(day: day, trip: trip)
        }
        .alert("Day Description", isPresented: Binding(
            get: { dayForNotesEdit != nil },
            set: { if !$0 { dayForNotesEdit = nil } }
        )) {
            TextField("e.g. Explore the old town", text: $editingDayNotes)
            Button("Save") {
                if let day = dayForNotesEdit {
                    day.notes = editingDayNotes.trimmingCharacters(in: .whitespaces)
                    trip.updatedAt = Date()
                    try? viewContext.save()
                    dayForNotesEdit = nil
                }
            }
            Button("Clear", role: .destructive) {
                if let day = dayForNotesEdit {
                    day.notes = ""
                    trip.updatedAt = Date()
                    try? viewContext.save()
                    dayForNotesEdit = nil
                }
            }
            Button("Cancel", role: .cancel) { dayForNotesEdit = nil }
        } message: {
            if let day = dayForNotesEdit {
                Text("Set a description for Day \(day.dayNumber)")
            }
        }
        .alert("Delete Stop?", isPresented: Binding(
            get: { stopToDelete != nil },
            set: { if !$0 { stopToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let stop = stopToDelete {
                    DataManager(context: viewContext).deleteStop(stop)
                    stopToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { stopToDelete = nil }
        } message: {
            if let stop = stopToDelete {
                Text("Are you sure you want to delete \"\(stop.wrappedName)\"? This cannot be undone.")
            }
        }
    }

    // MARK: - Toolbar

    @ToolbarContentBuilder
    private var tripToolbar: some ToolbarContent {
        ToolbarItem(placement: .primaryAction) {
            HStack(spacing: 16) {
                Menu {
                    Button {
                        shareTripFile()
                    } label: {
                        Label("Share Trip", systemImage: "paperplane")
                    }
                    Button {
                        shareTripPDF()
                    } label: {
                        Label("Share as PDF", systemImage: "doc.richtext")
                    }
                    Button {
                        shareTripText()
                    } label: {
                        Label("Share as Text", systemImage: "text.alignleft")
                    }
                    Divider()
                    Button {
                        exportToCalendar()
                    } label: {
                        Label("Add to Calendar", systemImage: "calendar.badge.plus")
                    }
                    .disabled(isExportingCalendar)
                } label: {
                    Image(systemName: "square.and.arrow.up")
                }
                .accessibilityLabel("Share trip")
                Button {
                    showingEditTrip = true
                } label: {
                    Text("Edit")
                }
            }
        }
    }

    // MARK: - Planning Todos (Aggregated)

    private var allStopTodos: [(stop: StopEntity, todo: StopTodoEntity)] {
        sortedDays.flatMap { day in
            day.stopsArray.flatMap { stop in
                stop.todosArray.map { (stop: stop, todo: $0) }
            }
        }
    }

    @ViewBuilder
    private var planningTodosSection: some View {
        let todos = allStopTodos
        if !todos.isEmpty {
            Section {
                let incomplete = todos.filter { !$0.todo.isCompleted }
                let completed = todos.filter { $0.todo.isCompleted }

                ForEach(incomplete, id: \.todo.id) { item in
                    todoAggregateRow(item.stop, todo: item.todo)
                }
                ForEach(completed, id: \.todo.id) { item in
                    todoAggregateRow(item.stop, todo: item.todo)
                }
            } header: {
                HStack {
                    Label("Planning Todos", systemImage: "checklist")
                    Spacer()
                    let done = todos.filter { $0.todo.isCompleted }.count
                    Text("\(done)/\(todos.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func todoAggregateRow(_ stop: StopEntity, todo: StopTodoEntity) -> some View {
        HStack(spacing: 10) {
            Button {
                todo.isCompleted.toggle()
                trip.updatedAt = Date()
                try? viewContext.save()
            } label: {
                Image(systemName: todo.isCompleted ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(todo.isCompleted ? .green : .gray)
            }
            .buttonStyle(.plain)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(todo.wrappedText)
                    .font(.subheadline)
                    .strikethrough(todo.isCompleted)
                    .foregroundStyle(todo.isCompleted ? .secondary : .primary)
                Text(stop.wrappedName)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
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
                            Text(trip.wrappedDestination)
                                .font(.title3)
                                .fontWeight(.medium)
                        }
                        if trip.hasCustomDates {
                            Text("\(dateFormatter.string(from: trip.wrappedStartDate)) - \(dateFormatter.string(from: trip.wrappedEndDate))")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Dates not set")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }
                    }
                    Spacer()
                    StatusBadge(status: trip.displayStatus)
                }

                HStack(spacing: 16) {
                    if trip.hasCustomDates {
                        Label("\(trip.durationInDays) days", systemImage: "calendar")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Label("\(trip.daysArray.count) day plans", systemImage: "list.bullet")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    let stopCount = trip.daysArray.reduce(0) { $0 + $1.stopsArray.count }
                    Label("\(stopCount) stops", systemImage: "mappin")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.vertical, 4)

            if !trip.wrappedNotes.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Notes")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .textCase(.uppercase)
                    Text(trip.wrappedNotes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    // MARK: - Weather (per-day)

    /// Location used for weather fetch — first day with a location, else trip destination.
    private var weatherLocation: String {
        if let firstLoc = sortedDays.first(where: { !$0.wrappedLocation.isEmpty })?.wrappedLocation {
            return firstLoc
        }
        return trip.wrappedDestination
    }

    /// Finds the weather forecast whose date matches a given day.
    private func forecast(for day: DayEntity) -> WeatherService.DayForecast? {
        guard let dayDate = day.date else { return nil }
        return weatherService.forecasts.first {
            Calendar.current.isDate($0.date, inSameDayAs: dayDate)
        }
    }

    @ViewBuilder
    private func weatherRow(for day: DayEntity) -> some View {
        if let fc = forecast(for: day) {
            HStack(spacing: 6) {
                Image(systemName: WeatherService.weatherIcon(for: fc.conditionCode))
                    .font(.caption)
                    .foregroundStyle(weatherIconColor(for: fc.conditionCode))
                Text(WeatherService.weatherDescription(for: fc.conditionCode))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(Int(fc.highTemp))° / \(Int(fc.lowTemp))°")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                if fc.precipProbability > 0 {
                    HStack(spacing: 2) {
                        Image(systemName: "drop.fill")
                            .font(.system(size: 8))
                            .foregroundStyle(.blue)
                        Text("\(fc.precipProbability)%")
                            .font(.system(size: 9))
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
    }

    private func weatherIconColor(for code: Int) -> Color {
        switch WeatherService.weatherColor(for: code) {
        case "yellow": return .yellow
        case "orange": return .orange
        case "blue": return .blue
        case "cyan": return .cyan
        case "purple": return .purple
        default: return .gray
        }
    }

    // MARK: - Location Header

    private func locationHeader(_ location: String, days: [DayEntity]) -> some View {
        Section {
            HStack(spacing: 10) {
                Image(systemName: "mappin.circle.fill")
                    .font(.title3)
                    .foregroundStyle(.red)
                VStack(alignment: .leading, spacing: 2) {
                    Text(location)
                        .font(.headline)
                        .fontWeight(.bold)
                    if let first = days.first, let last = days.last {
                        if first.dayNumber == last.dayNumber {
                            Text("Day \(first.dayNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Days \(first.dayNumber)–\(last.dayNumber)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                Spacer()
                Text("\(days.count) day\(days.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.tertiarySystemFill))
                    .clipShape(Capsule())
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Active Accommodation

    /// Finds an accommodation stop from another day whose stay spans this day.
    private func activeAccommodation(for day: DayEntity) -> StopEntity? {
        guard let dayDate = day.date else { return nil }
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: dayDate)

        for otherDay in sortedDays where otherDay.id != day.id {
            guard let otherDate = otherDay.date else { continue }
            let otherStart = calendar.startOfDay(for: otherDate)
            // Only look at days before this one
            guard otherStart < dayStart else { continue }

            for stop in otherDay.stopsArray {
                guard stop.category == .accommodation,
                      let checkOut = stop.checkOutDate else { continue }
                let checkOutStart = calendar.startOfDay(for: checkOut)
                // This day is between check-in (exclusive) and check-out (exclusive)
                if dayStart > otherStart && dayStart < checkOutStart {
                    return stop
                }
            }
        }
        return nil
    }

    // MARK: - Day Notes

    @ViewBuilder
    private func dayNotesRow(_ day: DayEntity) -> some View {
        Button {
            editingDayNotes = day.wrappedNotes
            dayForNotesEdit = day
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "pencil.line")
                    .font(.caption)
                    .foregroundStyle(.blue)
                if day.wrappedNotes.isEmpty {
                    Text("Add a description for this day...")
                        .font(.subheadline)
                        .foregroundStyle(.tertiary)
                        .italic()
                } else {
                    Text(day.wrappedNotes)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Day Section

    @ViewBuilder
    private func stopRow(stop: StopEntity, index: Int, sortedStops: [StopEntity], day: DayEntity) -> some View {
        NavigationLink(destination: StopDetailView(stop: stop)) {
            StopRowView(stop: stop)
        }
        .draggable((stop.id ?? UUID()).uuidString) {
            Label(stop.wrappedName, systemImage: "mappin.circle.fill")
                .padding(8)
                .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 8))
                .onAppear { draggingStopID = (stop.id ?? UUID()).uuidString }
                .onDisappear {
                    draggingStopID = nil
                    dropTargetDayID = nil
                }
        }
        .contextMenu {
            if sortedDays.count > 1 {
                Menu("Move to...") {
                    ForEach(sortedDays.filter { $0.id != day.id }) { targetDay in
                        Button {
                            moveStopToDay(stop, targetDay: targetDay)
                        } label: {
                            Label("Day \(targetDay.dayNumber) — \(targetDay.formattedDate)", systemImage: "arrow.right")
                        }
                    }
                }
            }
            Button(role: .destructive) {
                stopToDelete = stop
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }

        // Show travel time between consecutive stops
        if index < sortedStops.count - 1 {
            let nextStop = sortedStops[index + 1]
            let hasFrom = stop.latitude != 0 || stop.longitude != 0
            let hasTo = nextStop.latitude != 0 || nextStop.longitude != 0
            if hasFrom && hasTo {
                TravelTimeRow(
                    estimate: travelTimeService.estimate(from: stop.id ?? UUID(), to: nextStop.id ?? UUID())
                )
                .task {
                    await travelTimeService.calculateTravelTime(from: stop, to: nextStop)
                }
            }
        }
    }

    private func daySection(_ day: DayEntity) -> some View {
        let sortedStops = day.stopsArray.sorted { $0.sortOrder < $1.sortOrder }
        let locatedStops = sortedStops.filter { $0.latitude != 0 || $0.longitude != 0 }
        let accommodation = activeAccommodation(for: day)

        return Section {
            dayNotesRow(day)

            weatherRow(for: day)

            // "Staying at" banner for multi-day accommodation
            if let accommodation {
                stayingAtRow(accommodation)
                // Travel time from hotel to first located stop on this day
                if let firstStop = locatedStops.first,
                   (accommodation.latitude != 0 || accommodation.longitude != 0) {
                    TravelTimeRow(
                        estimate: travelTimeService.estimate(from: accommodation.id ?? UUID(), to: firstStop.id ?? UUID())
                    )
                    .task {
                        await travelTimeService.calculateTravelTime(from: accommodation, to: firstStop)
                    }
                }
            }

            // Daily distance/time summary — includes hotel leg when present
            daySummaryRow(locatedStops: locatedStops, leadingAccommodation: accommodation)

            // Drop zone row — visible only while a stop is being dragged to a different day
            if draggingStopID != nil {
                let isTarget = dropTargetDayID == day.id
                HStack {
                    Spacer()
                    Label(isTarget ? "Release to move here" : "Move to Day \(day.dayNumber)",
                          systemImage: isTarget ? "arrow.down.circle.fill" : "arrow.right.circle")
                        .font(.subheadline)
                        .foregroundStyle(isTarget ? .white : .blue)
                    Spacer()
                }
                .padding(.vertical, 6)
                .background(isTarget ? Color.blue : Color.blue.opacity(0.08),
                            in: RoundedRectangle(cornerRadius: 8))
                .listRowBackground(Color.clear)
                .dropDestination(for: String.self) { items, _ in
                    guard let uuidString = items.first,
                          let stop = findStop(byID: uuidString),
                          stop.day?.id != day.id else { return false }
                    moveStopToDay(stop, targetDay: day)
                    draggingStopID = nil
                    dropTargetDayID = nil
                    return true
                } isTargeted: { isTargeted in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        dropTargetDayID = isTargeted ? day.id : (dropTargetDayID == day.id ? nil : dropTargetDayID)
                    }
                }
            }

            ForEach(Array(sortedStops.enumerated()), id: \.element.id) { index, stop in
                stopRow(stop: stop, index: index, sortedStops: sortedStops, day: day)
            }
            .onDelete { offsets in
                let stops = day.stopsArray.sorted { $0.sortOrder < $1.sortOrder }
                if let index = offsets.first {
                    stopToDelete = stops[index]
                }
            }
            .onMove { source, destination in
                moveStops(in: day, from: source, to: destination)
            }

            Button {
                selectedDayForStop = day
            } label: {
                Label("Add Stop", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }

            openDayInMapsButton(day: day)
        } header: {
            HStack {
                Text("Day \(day.dayNumber)")
                    .fontWeight(.semibold)
                Spacer()
                if !day.wrappedLocation.isEmpty && locationSegments.count <= 1 {
                    Text(day.wrappedLocation)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Text(day.formattedDate)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
            .contextMenu {
                Button {
                    dayForLocationEdit = day
                } label: {
                    Label("Set Location", systemImage: "mappin.and.ellipse")
                }
            }
        }
    }

    private func stayingAtRow(_ accommodation: StopEntity) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "bed.double.fill")
                .font(.caption)
                .foregroundStyle(.purple)
            Text("Staying at \(accommodation.wrappedName)")
                .font(.caption)
                .foregroundStyle(.purple)
            if let nights = accommodation.nightCount {
                Text("(\(nights) night\(nights == 1 ? "" : "s"))")
                    .font(.caption)
                    .foregroundStyle(.purple.opacity(0.7))
            }
            Spacer()
        }
        .padding(.vertical, 2)
    }

    // MARK: - Daily Summary

    @ViewBuilder
    private func daySummaryRow(locatedStops: [StopEntity], leadingAccommodation: StopEntity? = nil) -> some View {
        // Resolve hotel leg: hotel must have coordinates and there must be a first located stop.
        let firstLocated = locatedStops.first
        let hotelLegValid: Bool = {
            guard let hotel = leadingAccommodation, let _ = firstLocated,
                  hotel.latitude != 0 || hotel.longitude != 0,
                  hotel.id != nil else { return false }
            return true
        }()

        // Show summary when there are ≥2 stops OR hotel + ≥1 stop.
        let hasEnoughLegs = locatedStops.count >= 2 || (locatedStops.count >= 1 && hotelLegValid)

        if hasEnoughLegs {
            // Gather MapKit estimates for consecutive stop pairs.
            let stopEstimates = consecutiveEstimates(for: locatedStops)

            // Look up the hotel→firstStop estimate (already being calculated by the banner above).
            let hotelEstimate: TravelTimeService.TravelEstimate? = {
                guard hotelLegValid,
                      let hotel = leadingAccommodation, let first = firstLocated,
                      let hID = hotel.id, let fID = first.id else { return nil }
                return travelTimeService.estimate(from: hID, to: fID)
            }()

            let allEstimates = [hotelEstimate].compactMap { $0 } + stopEstimates
            let totalMinutes = allEstimates.compactMap(\.drivingMinutes).reduce(0, +)

            // Prefer actual road distances from MapKit (consistent with TravelTimeRow).
            // Fall back to straight-line while estimates are still loading.
            let routeDistanceM = allEstimates.compactMap(\.distanceMeters).reduce(0.0, +)
            let displayKm: Double = {
                if routeDistanceM > 0 { return routeDistanceM / 1000.0 }
                // Straight-line fallback — prepend hotel position when applicable.
                var stopsForLine = locatedStops
                if hotelLegValid, let hotel = leadingAccommodation { stopsForLine = [hotel] + stopsForLine }
                return stopsForLine.count >= 2 ? totalDistance(for: stopsForLine) : 0
            }()

            if displayKm > 0 || totalMinutes > 0 {
                HStack(spacing: 16) {
                    if displayKm > 0 {
                        Label(formatDistance(displayKm), systemImage: "point.topleft.down.to.point.bottomright.curvepath")
                            .font(.caption)
                            .foregroundStyle(.teal)
                    }
                    if totalMinutes > 0 {
                        Label(formatDuration(totalMinutes), systemImage: "car.fill")
                            .font(.caption)
                            .foregroundStyle(.teal)
                    }
                    Spacer()
                }
                .padding(.vertical, 2)
            }
        }
    }

    private func totalDistance(for stops: [StopEntity]) -> Double {
        var total: Double = 0
        for i in 0..<(stops.count - 1) {
            let from = CLLocation(latitude: stops[i].latitude, longitude: stops[i].longitude)
            let to = CLLocation(latitude: stops[i + 1].latitude, longitude: stops[i + 1].longitude)
            total += from.distance(from: to)
        }
        return total / 1000.0 // km
    }

    private func consecutiveEstimates(for stops: [StopEntity]) -> [TravelTimeService.TravelEstimate] {
        var results: [TravelTimeService.TravelEstimate] = []
        for i in 0..<(stops.count - 1) {
            guard let fromID = stops[i].id, let toID = stops[i + 1].id else { continue }
            if let est = travelTimeService.estimate(from: fromID, to: toID) {
                results.append(est)
            }
        }
        return results
    }

    private func formatDistance(_ km: Double) -> String {
        if Locale.current.measurementSystem == .us {
            let miles = km * 0.621371
            return String(format: "%.1f mi", miles)
        }
        return String(format: "%.1f km", km)
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        }
        let hours = minutes / 60
        let mins = minutes % 60
        return mins > 0 ? "\(hours)h \(mins)m" : "\(hours)h"
    }

    // MARK: - Actions

    private func deleteStops(from stops: [StopEntity], at offsets: IndexSet) {
        let manager = DataManager(context: viewContext)
        for index in offsets {
            manager.deleteStop(stops[index])
        }
    }

    private func moveStops(in day: DayEntity, from source: IndexSet, to destination: Int) {
        let manager = DataManager(context: viewContext)
        manager.reorderStops(in: day, from: source, to: destination)
    }

    private func moveStopToDay(_ stop: StopEntity, targetDay: DayEntity) {
        let manager = DataManager(context: viewContext)
        manager.moveStop(stop, to: targetDay)
    }

    private func findStop(byID uuidString: String) -> StopEntity? {
        guard let uuid = UUID(uuidString: uuidString) else { return nil }
        return sortedDays.flatMap(\.stopsArray).first { $0.id == uuid }
    }

    // MARK: - Share

    private func shareTripFile() {
        do {
            let fileURL = try TripShareService.exportTrip(trip)
            ShareSheet.shareTripFile(fileURL, tripName: trip.wrappedName)
        } catch {
            // Export failed silently — user can retry
        }
    }

    private func shareTripPDF() {
        let data = TripPDFGenerator.generatePDF(for: trip)
        ShareSheet.share(pdfData: data, filename: "\(trip.wrappedName) Itinerary.pdf")
    }

    private func shareTripText() {
        let text = TripTextExporter.generateText(for: trip)
        ShareSheet.shareText(text)
    }

    // MARK: - Calendar Export

    private func exportToCalendar() {
        isExportingCalendar = true
        let calendarDays = sortedDays.map { day in
            let stopNames = day.stopsArray.sorted { $0.sortOrder < $1.sortOrder }.map(\.wrappedName)
            return (dayNumber: Int(day.dayNumber), date: day.wrappedDate, notes: day.wrappedNotes, stopNames: stopNames)
        }
        let tripName = trip.wrappedName
        let destination = trip.wrappedDestination

        Task {
            let service = CalendarService()
            do {
                let count = try await service.exportTrip(
                    name: tripName,
                    destination: destination,
                    days: calendarDays
                )
                calendarExportMessage = "Added \(count) day\(count == 1 ? "" : "s") to your calendar."
            } catch {
                calendarExportMessage = error.localizedDescription
            }
            isExportingCalendar = false
            showingCalendarResult = true
        }
    }

    // MARK: - Paste Itinerary

    // MARK: - Open Day in Apple Maps

    private func openDayInMapsButton(day: DayEntity) -> some View {
        let locatedStops = day.stopsArray.sorted { $0.sortOrder < $1.sortOrder }
            .filter { $0.latitude != 0 || $0.longitude != 0 }
        return Group {
            if locatedStops.count >= 2 {
                Button {
                    openDayInAppleMaps(stops: locatedStops)
                } label: {
                    Label("Open in Apple Maps", systemImage: "map")
                        .font(.subheadline)
                        .foregroundStyle(.blue)
                }
            }
        }
    }

    private func openDayInAppleMaps(stops: [StopEntity]) {
        guard stops.count >= 2 else { return }
        let mapItems = stops.map { stop -> MKMapItem in
            let placemark = MKPlacemark(coordinate: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude))
            let item = MKMapItem(placemark: placemark)
            item.name = stop.wrappedName
            return item
        }
        // Open with all stops as waypoints
        MKMapItem.openMaps(with: mapItems, launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving
        ])
    }

}
