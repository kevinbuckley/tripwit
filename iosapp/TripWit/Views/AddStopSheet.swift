import SwiftUI
import CoreData
import MapKit
import TripCore

struct AddStopSheet: View {

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationManager.self) private var locationManager: LocationManager?

    let day: DayEntity

    @State private var name = ""
    @State private var category: StopCategory = .attraction
    @State private var notes = ""
    @State private var latitude: Double = 0
    @State private var longitude: Double = 0
    @State private var locationName = ""
    @State private var locationCity = ""
    @State private var placeAddress = ""
    @State private var placePhone = ""
    @State private var placeWebsite = ""

    @State private var useArrivalTime = false
    @State private var arrivalTime = Calendar.current.date(bySettingHour: 9, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var useDepartureTime = false
    @State private var departureTime = Calendar.current.date(bySettingHour: 10, minute: 0, second: 0, of: Date()) ?? Date()
    @State private var showingAISuggest = false
    @State private var destinationRegion: MKCoordinateRegion?
    @State private var tripCountry: String = ""
    @State private var countryRegion: MKCoordinateRegion?

    // Booking fields (contextual, shown based on category)
    @State private var confirmationCode = ""
    @State private var useCheckOutDate = false
    @State private var checkOutDate = Date()
    @State private var airlineName = ""
    @State private var flightNumberText = ""
    @State private var departureAirportText = ""
    @State private var arrivalAirportText = ""

    // Only require a name — location is optional for planning
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasLocation: Bool {
        latitude != 0 || longitude != 0
    }

    /// Best available region for biasing location search results.
    /// Walks a 5-level fallback chain from most-specific to most-broad.
    private var searchRegion: MKCoordinateRegion? {
        // 1. Day's geocoded coordinates (set when day has a specific city/location)
        if day.locationLatitude != 0 || day.locationLongitude != 0 {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: day.locationLatitude, longitude: day.locationLongitude),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }

        // 2. Centroid of stops already on this day that have coordinates
        let dayStops = day.stopsArray.filter { $0.latitude != 0 || $0.longitude != 0 }
        if !dayStops.isEmpty {
            let avgLat = dayStops.map(\.latitude).reduce(0, +) / Double(dayStops.count)
            let avgLon = dayStops.map(\.longitude).reduce(0, +) / Double(dayStops.count)
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }

        // 3. Nearest other day that has day-level coordinates; otherwise centroid of all trip stops
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
            let allStops = trip.daysArray.flatMap(\.stopsArray).filter { $0.latitude != 0 || $0.longitude != 0 }
            if !allStops.isEmpty {
                let avgLat = allStops.map(\.latitude).reduce(0, +) / Double(allStops.count)
                let avgLon = allStops.map(\.longitude).reduce(0, +) / Double(allStops.count)
                return MKCoordinateRegion(
                    center: CLLocationCoordinate2D(latitude: avgLat, longitude: avgLon),
                    span: MKCoordinateSpan(latitudeDelta: 0.3, longitudeDelta: 0.3)
                )
            }
        }

        // 4. Geocoded trip destination (moderate span ~55 km radius)
        if let region = destinationRegion { return region }

        // 5. Country-level broad fallback (~1000 km radius)
        return countryRegion
    }

    var body: some View {
        NavigationStack {
            Form {
                aiSuggestSection
                detailsSection
                locationSection
                timesSection
                bookingFieldsSection
                notesSection
            }
            .navigationTitle("Add Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add Stop") { addStop() }
                        .fontWeight(.semibold)
                        .disabled(!isValid)
                }
            }
            .onChange(of: locationName) { _, newValue in
                if name.isEmpty {
                    name = newValue
                }
            }
            .sheet(isPresented: $showingAISuggest) {
                aiSuggestSheet
            }
            .task {
                await geocodeDestination()
            }
        }
    }

    // MARK: - AI Suggest

    @ViewBuilder
    private var aiSuggestSection: some View {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), AITripPlanner.isDeviceSupported {
            Section {
                Button {
                    showingAISuggest = true
                } label: {
                    HStack {
                        Image(systemName: "sparkles")
                            .foregroundStyle(.purple)
                        Text("Suggest with AI")
                            .foregroundStyle(.purple)
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            } footer: {
                Text("Get place ideas based on nearby stops or your destination.")
                    .font(.caption2)
            }
        }
        #endif
    }

    @ViewBuilder
    private var aiSuggestSheet: some View {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            AISuggestForAddStopSheet(day: day) { suggestion in
                name = suggestion.name
                category = AITripPlanner.mapCategory(suggestion.category)
                notes = suggestion.reason
                // Pre-fill the location search name so the user can search for it
                locationName = suggestion.name
            }
        }
        #else
        Text("Apple Intelligence requires iOS 26")
        #endif
    }

    // MARK: - Sections

    private var detailsSection: some View {
        Section {
            TextField("Stop Name (required)", text: $name)
            CategoryPicker(selection: $category)
        } header: {
            Text("Details")
        }
    }

    private var locationSection: some View {
        Section {
            if hasLocation {
                locationSelectedRow
            }
            useCurrentLocationButton
            LocationSearchView(
                selectedName: $locationName,
                selectedLatitude: $latitude,
                selectedLongitude: $longitude,
                selectedCity: $locationCity,
                selectedAddress: $placeAddress,
                selectedPhone: $placePhone,
                selectedWebsite: $placeWebsite,
                searchRegion: searchRegion,
                category: category,
                tripCountry: tripCountry.isEmpty ? nil : tripCountry
            )
            .listRowInsets(EdgeInsets())
        } header: {
            Text("Location")
        } footer: {
            Text("Search for a place, use your current location, or skip — you can add a location later.")
                .font(.caption2)
        }
    }

    private var locationSelectedRow: some View {
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

    @ViewBuilder
    private var useCurrentLocationButton: some View {
        if let locMgr = locationManager {
            Button {
                useCurrentLocation(locMgr)
            } label: {
                HStack {
                    Image(systemName: "location.fill")
                        .foregroundStyle(.blue)
                    Text("Use Current Location")
                        .foregroundStyle(.blue)
                    Spacer()
                    if !locMgr.isAuthorized {
                        Text("Tap to enable")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private var timesSection: some View {
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
    }

    private var notesSection: some View {
        Section {
            TextField("Notes", text: $notes, axis: .vertical)
                .lineLimit(2...4)
        } header: {
            Text("Notes")
        }
    }

    // MARK: - Actions

    private func useCurrentLocation(_ locMgr: LocationManager) {
        if !locMgr.isAuthorized {
            locMgr.requestPermission()
            return
        }
        locMgr.requestLocation()
        if let loc = locMgr.currentLocation {
            latitude = loc.coordinate.latitude
            longitude = loc.coordinate.longitude
            // Reverse geocode for a name
            let geocoder = CLGeocoder()
            let clLocation = CLLocation(latitude: latitude, longitude: longitude)
            geocoder.reverseGeocodeLocation(clLocation) { placemarks, _ in
                if let place = placemarks?.first {
                    let placeName = place.name ?? place.locality ?? "Current Location"
                    locationName = placeName
                }
            }
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

    private func geocodeDestination() async {
        // Always geocode the trip destination so we can extract country for query enrichment,
        // even when the day already has coordinates (levels 1–3 of searchRegion chain handle those).
        guard let destination = day.trip?.destination, !destination.isEmpty else { return }
        let geocoder = CLGeocoder()
        guard let placemarks = try? await geocoder.geocodeAddressString(destination),
              let placemark = placemarks.first,
              let location = placemark.location else { return }

        destinationRegion = MKCoordinateRegion(
            center: location.coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
        )
        // Extract country name for query enrichment ("Eiffel Tower" → "Eiffel Tower, France")
        if let country = placemark.country {
            tripCountry = country
            // Country-level region as the broadest fallback
            countryRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 10.0, longitudeDelta: 10.0)
            )
        }
    }

    private func addStop() {
        let manager = DataManager(context: viewContext)
        let stop = manager.addStop(
            to: day,
            name: name.trimmingCharacters(in: .whitespaces),
            latitude: latitude,
            longitude: longitude,
            category: category,
            notes: notes.trimmingCharacters(in: .whitespaces)
        )
        if useArrivalTime {
            stop.arrivalTime = arrivalTime
        }
        if useDepartureTime {
            stop.departureTime = departureTime
        }

        // Apply place details from search (instant, no second API call)
        if !placeAddress.isEmpty { stop.address = placeAddress }
        if !placePhone.isEmpty { stop.phone = placePhone }
        if !placeWebsite.isEmpty { stop.website = placeWebsite }

        // Booking fields
        let trimmedCode = confirmationCode.trimmingCharacters(in: .whitespaces)
        if !trimmedCode.isEmpty { stop.confirmationCode = trimmedCode }
        if useCheckOutDate { stop.checkOutDate = checkOutDate }
        if !airlineName.isEmpty { stop.airline = airlineName }
        if !flightNumberText.isEmpty { stop.flightNumber = flightNumberText }
        if !departureAirportText.isEmpty { stop.departureAirport = departureAirportText }
        if !arrivalAirportText.isEmpty { stop.arrivalAirport = arrivalAirportText }

        try? viewContext.save()
        dismiss()
    }
}
