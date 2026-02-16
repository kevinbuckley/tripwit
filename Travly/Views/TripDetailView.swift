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
    @State private var showingStartConfirmation = false
    @State private var showingCompleteConfirmation = false
    @State private var showingAddBooking = false
    @State private var travelTimeService = TravelTimeService()
    @State private var stopToDelete: StopEntity?
    @State private var bookingToDelete: BookingEntity?
    @State private var showingPasteItinerary = false

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

            // MARK: - Weather
            if !trip.isPast {
                WeatherSection(trip: trip)
            }

            // MARK: - Bookings
            bookingsSection

            // MARK: - Paste Itinerary
            pasteItinerarySection

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
                HStack(spacing: 16) {
                    Button {
                        shareTripPDF()
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                    .accessibilityLabel("Share itinerary as PDF")
                    Button {
                        showingEditTrip = true
                    } label: {
                        Text("Edit")
                    }
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
        .sheet(isPresented: $showingAddBooking) {
            AddBookingSheet(trip: trip)
        }
        .sheet(isPresented: $showingPasteItinerary) {
            pasteItinerarySheet
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
        .alert("Delete Stop?", isPresented: Binding(
            get: { stopToDelete != nil },
            set: { if !$0 { stopToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let stop = stopToDelete {
                    DataManager(modelContext: modelContext).deleteStop(stop)
                    stopToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { stopToDelete = nil }
        } message: {
            if let stop = stopToDelete {
                Text("Are you sure you want to delete \"\(stop.name)\"? This cannot be undone.")
            }
        }
        .alert("Delete Booking?", isPresented: Binding(
            get: { bookingToDelete != nil },
            set: { if !$0 { bookingToDelete = nil } }
        )) {
            Button("Delete", role: .destructive) {
                if let booking = bookingToDelete {
                    modelContext.delete(booking)
                    try? modelContext.save()
                    bookingToDelete = nil
                }
            }
            Button("Cancel", role: .cancel) { bookingToDelete = nil }
        } message: {
            if let booking = bookingToDelete {
                Text("Are you sure you want to delete \"\(booking.title)\"?")
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

    // MARK: - Bookings Section

    private var sortedBookings: [BookingEntity] {
        trip.bookings.sorted { $0.sortOrder < $1.sortOrder }
    }

    private var bookingsSection: some View {
        Section {
            if sortedBookings.isEmpty {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "suitcase")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("No bookings yet")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 8)
                    Spacer()
                }
            } else {
                ForEach(sortedBookings) { booking in
                    NavigationLink(destination: BookingDetailView(booking: booking)) {
                        bookingRow(booking)
                    }
                }
                .onDelete { offsets in
                    if let index = offsets.first {
                        bookingToDelete = sortedBookings[index]
                    }
                }
            }

            Button {
                showingAddBooking = true
            } label: {
                Label("Add Booking", systemImage: "plus.circle")
                    .font(.subheadline)
                    .foregroundStyle(.blue)
            }
        } header: {
            HStack {
                Text("Flights & Hotels")
                Spacer()
                Text("\(trip.bookings.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func bookingRow(_ booking: BookingEntity) -> some View {
        HStack(spacing: 12) {
            Image(systemName: booking.bookingType.icon)
                .font(.body)
                .foregroundStyle(bookingIconColor(booking))
                .frame(width: 32, height: 32)
                .background(bookingIconColor(booking).opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(booking.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                bookingSubtitle(booking)
            }

            Spacer()

            if !booking.confirmationCode.isEmpty {
                Text(booking.confirmationCode)
                    .font(.caption.monospaced())
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func bookingSubtitle(_ booking: BookingEntity) -> some View {
        switch booking.bookingType {
        case .flight:
            if let dep = booking.departureAirport, let arr = booking.arrivalAirport {
                Text("\(dep) → \(arr)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            } else if let airline = booking.airline {
                Text(airline)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .hotel:
            if let checkIn = booking.checkInDate, let checkOut = booking.checkOutDate {
                let nights = Calendar.current.dateComponents([.day], from: checkIn, to: checkOut).day ?? 0
                Text("\(nights) night\(nights == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .carRental:
            if let pickup = booking.departureTime {
                Text("Pickup: \(pickup, style: .date)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        case .other:
            EmptyView()
        }
    }

    private func bookingIconColor(_ booking: BookingEntity) -> Color {
        switch booking.bookingType {
        case .flight: .blue
        case .hotel: .purple
        case .carRental: .orange
        case .other: .gray
        }
    }

    private func deleteBookings(at offsets: IndexSet) {
        let bookings = sortedBookings
        for index in offsets {
            modelContext.delete(bookings[index])
        }
        try? modelContext.save()
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

            ForEach(Array(sortedStops.enumerated()), id: \.element.id) { index, stop in
                NavigationLink(destination: StopDetailView(stop: stop)) {
                    StopRowView(stop: stop)
                }

                // Show travel time between consecutive stops
                if index < sortedStops.count - 1 {
                    let nextStop = sortedStops[index + 1]
                    let hasFrom = stop.latitude != 0 || stop.longitude != 0
                    let hasTo = nextStop.latitude != 0 || nextStop.longitude != 0
                    if hasFrom && hasTo {
                        TravelTimeRow(
                            estimate: travelTimeService.estimate(from: stop.id, to: nextStop.id)
                        )
                        .task {
                            await travelTimeService.calculateTravelTime(from: stop, to: nextStop)
                        }
                    }
                }
            }
            .onDelete { offsets in
                let stops = day.stops.sorted { $0.sortOrder < $1.sortOrder }
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

            aiSuggestRow(day: day)
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

    // MARK: - Share

    private func shareTripPDF() {
        let data = TripPDFGenerator.generatePDF(for: trip)
        ShareSheet.share(pdfData: data, filename: "\(trip.name) Itinerary.pdf")
    }

    // MARK: - Paste Itinerary

    @ViewBuilder
    private var pasteItinerarySection: some View {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), AITripPlanner.isDeviceSupported {
            Section {
                Button {
                    showingPasteItinerary = true
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: "doc.on.clipboard.fill")
                            .font(.title3)
                            .foregroundStyle(.purple)
                            .frame(width: 32, height: 32)
                            .background(Color.purple.opacity(0.12))
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Paste Itinerary")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                            Text("Import stops from ChatGPT, a blog, or any text")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Image(systemName: "sparkles")
                            .foregroundStyle(.purple)
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.plain)
            }
        }
        #endif
    }

    @ViewBuilder
    private var pasteItinerarySheet: some View {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            PasteItinerarySheet(trip: trip)
        }
        #else
        Text("Apple Intelligence requires iOS 26")
        #endif
    }

    // MARK: - AI Suggestions

    @ViewBuilder
    private func aiSuggestRow(day: DayEntity) -> some View {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), AITripPlanner.isDeviceSupported {
            Button {
                selectedDayForAI = day
            } label: {
                Label("Suggest with AI", systemImage: "sparkles")
                    .font(.subheadline)
                    .foregroundStyle(.purple)
            }
        }
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
