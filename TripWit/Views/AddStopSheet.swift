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

    // Only require a name — location is optional for planning
    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasLocation: Bool {
        latitude != 0 || longitude != 0
    }

    /// Best available region for biasing location search results
    private var searchRegion: MKCoordinateRegion? {
        // Prefer day's geocoded location (most specific)
        if day.locationLatitude != 0 || day.locationLongitude != 0 {
            return MKCoordinateRegion(
                center: CLLocationCoordinate2D(latitude: day.locationLatitude, longitude: day.locationLongitude),
                span: MKCoordinateSpan(latitudeDelta: 0.1, longitudeDelta: 0.1)
            )
        }
        // Fall back to geocoded trip destination
        return destinationRegion
    }

    var body: some View {
        NavigationStack {
            Form {
                aiSuggestSection
                detailsSection
                locationSection
                timesSection
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
                searchRegion: searchRegion
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

    private func geocodeDestination() async {
        // Skip if day already has coordinates (searchRegion will use those instead)
        guard day.locationLatitude == 0 && day.locationLongitude == 0 else { return }
        guard let destination = day.trip?.destination, !destination.isEmpty else { return }
        let geocoder = CLGeocoder()
        if let placemarks = try? await geocoder.geocodeAddressString(destination),
           let location = placemarks.first?.location {
            destinationRegion = MKCoordinateRegion(
                center: location.coordinate,
                span: MKCoordinateSpan(latitudeDelta: 0.5, longitudeDelta: 0.5)
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

        try? viewContext.save()
        dismiss()
    }
}
