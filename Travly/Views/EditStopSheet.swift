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
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private var hasLocation: Bool {
        latitude != 0 || longitude != 0
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
                        selectedCity: $locationCity
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

                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...4)
                } header: {
                    Text("Notes")
                }
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

    private func saveChanges() {
        let locationChanged = (latitude != stop.latitude || longitude != stop.longitude)

        stop.name = name.trimmingCharacters(in: .whitespaces)
        stop.category = category
        stop.notes = notes.trimmingCharacters(in: .whitespaces)
        stop.arrivalTime = useArrivalTime ? arrivalTime : nil
        stop.departureTime = useDepartureTime ? departureTime : nil
        stop.latitude = latitude
        stop.longitude = longitude
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
