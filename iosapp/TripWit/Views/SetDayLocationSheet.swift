import SwiftUI
import CoreData
import MapKit

struct SetDayLocationSheet: View {

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let day: DayEntity
    let trip: TripEntity

    @State private var locationText: String
    @State private var applyTo: ApplyScope = .thisDay
    @State private var searchResults: [MKLocalSearchCompletion] = []
    @State private var completer = LocationCompleter()

    enum ApplyScope: String, CaseIterable {
        case thisDay = "This day only"
        case throughEnd = "This day through end of trip"
        case custom = "Select days..."
    }

    @State private var selectedDays: Set<UUID> = []

    init(day: DayEntity, trip: TripEntity) {
        self.day = day
        self.trip = trip
        _locationText = State(initialValue: day.location ?? "")
        _selectedDays = State(initialValue: day.id.map { [$0] } ?? [])
    }

    private var sortedDays: [DayEntity] {
        trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    HStack {
                        Image(systemName: "magnifyingglass")
                            .foregroundStyle(.secondary)
                        TextField("City or region", text: $locationText)
                            .textContentType(.addressCity)
                            .autocorrectionDisabled()
                    }
                } header: {
                    Text("Location for Day \(day.dayNumber)")
                } footer: {
                    Text("e.g. \"Rome, Italy\" or \"Amalfi Coast\"")
                }

                if !completer.results.isEmpty && locationText.count >= 2 {
                    Section("Suggestions") {
                        ForEach(completer.results.prefix(5), id: \.self) { result in
                            Button {
                                locationText = [result.title, result.subtitle]
                                    .filter { !$0.isEmpty }
                                    .joined(separator: ", ")
                                completer.results = []
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.title)
                                        .font(.subheadline)
                                        .foregroundStyle(.primary)
                                    if !result.subtitle.isEmpty {
                                        Text(result.subtitle)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                        }
                    }
                }

                Section("Apply to") {
                    Picker("Scope", selection: $applyTo) {
                        ForEach(ApplyScope.allCases, id: \.self) { scope in
                            Text(scope.rawValue).tag(scope)
                        }
                    }
                    .pickerStyle(.menu)

                    if applyTo == .custom {
                        ForEach(sortedDays) { d in
                            let isSelected = d.id.map { selectedDays.contains($0) } ?? false
                            Button {
                                if let dayID = d.id {
                                    if isSelected {
                                        selectedDays.remove(dayID)
                                    } else {
                                        selectedDays.insert(dayID)
                                    }
                                }
                            } label: {
                                HStack {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(isSelected ? .blue : .secondary)
                                    Text("Day \(d.dayNumber)")
                                        .foregroundStyle(.primary)
                                    Spacer()
                                    Text(d.formattedDate)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                    if !d.wrappedLocation.isEmpty {
                                        Text(d.wrappedLocation)
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Set Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        applyLocation()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                    .disabled(locationText.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .onChange(of: locationText) { _, newValue in
                completer.search(query: newValue)
            }
        }
    }

    private func applyLocation() {
        let loc = locationText.trimmingCharacters(in: .whitespaces)
        let daysToUpdate: [DayEntity]

        switch applyTo {
        case .thisDay:
            daysToUpdate = [day]
        case .throughEnd:
            daysToUpdate = sortedDays.filter { $0.dayNumber >= day.dayNumber }
        case .custom:
            daysToUpdate = sortedDays.filter { $0.id.map { selectedDays.contains($0) } ?? false }
        }

        for d in daysToUpdate {
            d.location = loc
        }
        trip.updatedAt = Date()
        try? viewContext.save()
    }
}

// MARK: - Location Completer

@Observable
final class LocationCompleter: NSObject, MKLocalSearchCompleterDelegate {

    var results: [MKLocalSearchCompletion] = []
    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func search(query: String) {
        guard query.count >= 2 else {
            results = []
            return
        }
        completer.queryFragment = query
    }

    func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        results = completer.results
    }

    func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        results = []
    }
}
