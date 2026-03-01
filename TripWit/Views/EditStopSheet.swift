import SwiftUI
import CoreData
import MapKit
import TripCore

struct EditStopSheet: View {

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let stop: StopEntity

    @State private var name: String
    @State private var category: StopCategory
    @State private var notes: String
    @State private var useArrivalTime: Bool
    @State private var arrivalTime: Date
    @State private var useDepartureTime: Bool
    @State private var departureTime: Date
    @State private var latitude: Double
    @State private var longitude: Double
    @State private var locationName: String
    @State private var locationCity: String
    @State private var destinationRegion: MKCoordinateRegion?
    @State private var tripCountry: String = ""
    @State private var countryRegion: MKCoordinateRegion?

    // Booking fields (contextual, shown based on category)
    @State private var confirmationCode: String
    @State private var useCheckOutDate: Bool
    @State private var checkOutDate: Date
    @State private var airlineName: String
    @State private var flightNumberText: String
    @State private var departureAirportText: String
    @State private var arrivalAirportText: String

    init(stop: StopEntity) {
        self.stop = stop
        _name = State(initialValue: stop.name ?? "")
        _category = State(initialValue: stop.category)
        _notes = State(initialValue: stop.notes ?? "")
        _useArrivalTime = State(initialValue: stop.arrivalTime != nil)
        _arrivalTime = State(initialValue: stop.arrivalTime ?? Date())
        _useDepartureTime = State(initialValue: stop.departureTime != nil)
        _departureTime = State(initialValue: stop.departureTime ?? Date())
        _latitude = State(initialValue: stop.latitude)
        _longitude = State(initialValue: stop.longitude)
        _locationName = State(initialValue: stop.name ?? "")
        _locationCity = State(initialValue: "")
        _confirmationCode = State(initialValue: stop.confirmationCode ?? "")
        _useCheckOutDate = State(initialValue: stop.checkOutDate != nil)
        _checkOutDate = State(initialValue: stop.checkOutDate ?? Date())
        _airlineName = State(initialValue: stop.airline ?? "")
        _flightNumberText = State(initialValue: stop.flightNumber ?? "")
        _departureAirportText = State(initialValue: stop.departureAirport ?? "")
        _arrivalAirportText = State(initialValue: stop.arrivalAirport ?? "")
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasLocation: Bool {
        latitude != 0 || longitude != 0
    }

    /// Best available region for biasing location search results.
    /// Walks a 5-level fallback chain from most-specific to most-broad.
    private var searchRegion: MKCoordinateRegion? {
        guard let day = stop.day else { return destinationRegion ?? countryRegion }

        // 1. Day's geocoded coordinates
        if day.locationLatitude != 0 || day.locationLongitude != 0 {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: day.locationLatitude, longitude: day.locationLongitude),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }

        // 2. Centroid of other stops on this day (exclude self to avoid stale coords)
        let dayStops = day.stopsArray.filter { $0.id != stop.id && ($0.latitude != 0 || $0.longitude != 0) }
        if !dayStops.isEmpty {
            let avgLat = dayStops.map(\.latitude).reduce(0, +) / Double(dayStops.count)
            let avgLon = dayStops.map(\.longitude).reduce(0, +) / Double(dayStops.count)
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }

        // 3. Nearest other day with day-level coordinates; otherwise centroid of all trip stops
        if let trip = day.trip {
            let nearbyDay = trip.daysArray
                .filter { $0.dayNumber != day.dayNumber && ($0.locationLatitude != 0 || $0.locationLongitude != 0) }
                .min(by: { abs($0.dayNumber - day.dayNumber) < abs($1.dayNumber - day.dayNumber) })
            if let nd = nearbyDay {
                return MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: nd.locationLatitude, longitude: nd.locationLongitude),
                    span: MKCoordinateSpan(latitudeDelta: 0.2, longitudeDelta: 0.2)
                )
            }
            let allStops = trip.daysArray.flatMap(\.stopsArray)
                .filter { $0.id != stop.id && ($0.latitude != 0 || $0.longitude != 0) }
            if !allStops.isEmpty {
                let avgLat = allStops.map(\.latitude).reduce(0, +) / Double(allStops.count)
                let avgLon = allStops.map(\.longitude).reduce(0, +) / Double(allStops.count)
                return MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                    span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
                )
            }
        }

        // 4. Geocoded trip destination (moderate span)
        if let region = destinationRegion { return region }

        // 5. Country-level broad fallback
        return countryRegion
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Stop Name", text: $name)
                    CategoryPicker(selection: $category)
                } header: {
                    Text("Details")
                }

                Section {
                    if hasLocation {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            Text(locationName.isEmpty ? String(format: "%.4f, %.4f", latitude, longitude) : locationName)
                                .font(.subheadline)
                            Spacer()
                            Button("Clear") {
                                latitude = 0
                                longitude = 0
                                locationName = ""
                            }
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                    }
                    LocationSearchView(
                        selectedName: $locationName,
                        selectedLatitude: $latitude,
                        selectedLongitude: $longitude,
                        selectedCity: $locationCity,
                        searchRegion: searchRegion,
                        category: category,
                        tripCountry: tripCountry.isEmpty ? nil : tripCountry
                    )
                    .listRowInsets(EdgeInsets())
                } header: {
                    Text("Location")
                } footer: {
                    Text("Search to update the location, or clear to remove it.")
                        .font(.caption2)
                }

                Section {
                    Toggle("Set Arrival Time", isOn: $useArrivalTime)
                    if useArrivalTime {
                        DatePicker("Arrival", selection: $arrivalTime, displayedComponents: .hourAndMinute)
                    }
                    Toggle("Set Departure Time", isOn: $useDepartureTime)
                    if useDepartureTime {
                        DatePicker(
                            "Departure",
                            selection: $departureTime,
                            in: (useArrivalTime ? arrivalTime : .distantPast)...,
                            displayedComponents: .hourAndMinute
                        )
                    }
                } header: {
                    Text("Times")
                }

                bookingFieldsSection

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Notes")
                }
            }
            .task {
                await geocodeDestination()
            }
            .navigationTitle("Edit Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        saveChanges()
                    }
                    .fontWeight(.semibold)
                    .disabled(!isValid)
                }
            }
        }
    }

    private func geocodeDestination() async {
        guard let destination = stop.day?.trip?.destination, !destination.isEmpty else { return }
        let geocoder = CLGeocoder()
        guard let placemarks = try? await geocoder.geocodeAddressString(destination),
              let placemark = placemarks.first,
              let location = placemark.location else { return }

        destinationRegion = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
        // Extract country for query enrichment and broad fallback region
        if let country = placemark.country {
            tripCountry = country
            countryRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
            )
        }
    }

    @ViewBuilder
    private var bookingFieldsSection: some View {
        if category == .accommodation {
            Section {
                TextField("Confirmation Code", text: $confirmationCode)
                    .textInputAutocapitalization(.characters)
                Toggle("Set Check-out Date", isOn: $useCheckOutDate)
                if useCheckOutDate {
                    DatePicker("Check-out", selection: $checkOutDate, displayedComponents: [.date])
                }
            } header: {
                Text("Booking Details")
            }
        } else if category == .transport {
            Section {
                TextField("Confirmation Code", text: $confirmationCode)
                    .textInputAutocapitalization(.characters)
                TextField("Airline", text: $airlineName)
                TextField("Flight Number", text: $flightNumberText)
                    .textInputAutocapitalization(.characters)
                TextField("From Airport (e.g. LAX)", text: $departureAirportText)
                    .textInputAutocapitalization(.characters)
                TextField("To Airport (e.g. NRT)", text: $arrivalAirportText)
                    .textInputAutocapitalization(.characters)
            } header: {
                Text("Flight Details")
            }
        }
    }

    private func saveChanges() {
        let locationChanged = (latitude != stop.latitude || longitude != stop.longitude)

        stop.name = name.trimmingCharacters(in: .whitespaces)
        stop.category = category
        stop.notes = notes.trimmingCharacters(in: .whitespaces)
        stop.arrivalTime = useArrivalTime ? arrivalTime : nil
        stop.departureTime = useDepartureTime ? departureTime : nil
        stop.latitude = latitude
        stop.longitude = longitude

        // Booking fields — nil-out empty strings
        let trimmedCode = confirmationCode.trimmingCharacters(in: .whitespaces)
        stop.confirmationCode = trimmedCode.isEmpty ? nil : trimmedCode
        stop.checkOutDate = (category == .accommodation && useCheckOutDate) ? checkOutDate : nil
        stop.airline = airlineName.isEmpty ? nil : airlineName
        stop.flightNumber = flightNumberText.isEmpty ? nil : flightNumberText
        stop.departureAirport = departureAirportText.isEmpty ? nil : departureAirportText
        stop.arrivalAirport = arrivalAirportText.isEmpty ? nil : arrivalAirportText

        stop.day?.trip?.updatedAt = Date()
        try? viewContext.save()

        // Re-populate place details if location changed
        if locationChanged && (latitude != 0 || longitude != 0) {
            Task {
                await populatePlaceDetails()
            }
        }

        dismiss()
    }

    private func populatePlaceDetails() async {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = stop.wrappedName
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude),
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )
        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            if let item = response.mapItems.first {
                await MainActor.run {
                    stop.phone = item.phoneNumber
                    if let url = item.url { stop.website = url.absoluteString }
                    let pm = item.placemark
                    let parts = [pm.subThoroughfare, pm.thoroughfare, pm.locality, pm.administrativeArea, pm.postalCode].compactMap { $0 }
                    if !parts.isEmpty { stop.address = parts.joined(separator: ", ") }
                    stop.day?.trip?.updatedAt = Date()
                    try? viewContext.save()
                }
            }
        } catch { }
    }
}
