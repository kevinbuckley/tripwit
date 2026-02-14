import SwiftUI
import SwiftData
import CoreLocation
import TripCore

struct QuickAddStopSheet: View {

    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationManager.self) private var locationManager

    let day: DayEntity

    @State private var name = ""
    @State private var category: StopCategory = .other
    @State private var resolvedAddress: String?
    @State private var isGeocoding = false

    @FocusState private var nameFieldFocused: Bool

    private var hasLocation: Bool {
        locationManager.currentLocation != nil
    }

    private var isValid: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && hasLocation
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {
                locationStatusSection
                nameField
                categoryRow
                Spacer()
                addButton
            }
            .padding(16)
            .navigationTitle("Quick Add Stop")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
            .onAppear {
                requestLocationIfNeeded()
                nameFieldFocused = true
            }
            .onChange(of: locationManager.currentLocation) { _, newLocation in
                if let loc = newLocation {
                    reverseGeocode(loc)
                }
            }
        }
    }

    // MARK: - Location Status

    private var locationStatusSection: some View {
        VStack(spacing: 6) {
            locationIcon
            locationCoordinateText
            locationAddressText
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var locationIcon: some View {
        Group {
            if hasLocation {
                Image(systemName: "location.fill")
                    .font(.title2)
                    .foregroundColor(.green)
            } else {
                ProgressView()
            }
        }
    }

    private var locationCoordinateText: some View {
        Group {
            if let loc = locationManager.currentLocation {
                Text(coordinateString(loc))
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Text("Finding your location...")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var locationAddressText: some View {
        Group {
            if let address = resolvedAddress {
                Text(address)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .multilineTextAlignment(.center)
            } else if isGeocoding {
                Text("Resolving address...")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Name Field

    private var nameField: some View {
        TextField("What are you doing?", text: $name)
            .font(.title3)
            .padding(12)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .focused($nameFieldFocused)
    }

    // MARK: - Category Row

    private var categoryRow: some View {
        HStack(spacing: 12) {
            ForEach(StopCategory.allCases, id: \.self) { cat in
                categoryButton(cat)
            }
        }
    }

    private func categoryButton(_ cat: StopCategory) -> some View {
        let isSelected = category == cat
        return Button {
            category = cat
        } label: {
            Image(systemName: categoryIconName(cat))
                .font(.title3)
                .frame(width: 44, height: 44)
                .foregroundColor(isSelected ? .white : categoryColor(cat))
                .background(isSelected ? categoryColor(cat) : categoryColor(cat).opacity(0.15))
                .clipShape(Circle())
        }
        .buttonStyle(.plain)
    }

    // MARK: - Add Button

    private var addButton: some View {
        Button {
            addStop()
        } label: {
            Text("Add Stop")
                .font(.headline)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
                .foregroundColor(.white)
                .background(isValid ? Color.green : Color.gray)
                .clipShape(RoundedRectangle(cornerRadius: 14))
        }
        .disabled(!isValid)
    }

    // MARK: - Helpers

    private func requestLocationIfNeeded() {
        if !locationManager.isAuthorized {
            locationManager.requestPermission()
        } else {
            locationManager.requestLocation()
        }
    }

    private func reverseGeocode(_ location: CLLocation) {
        isGeocoding = true
        let geocoder = CLGeocoder()
        Task {
            let placemarks = try? await geocoder.reverseGeocodeLocation(location)
            await MainActor.run {
                isGeocoding = false
                if let placemark = placemarks?.first {
                    resolvedAddress = Self.formatPlacemark(placemark)
                }
            }
        }
    }

    private static func formatPlacemark(_ placemark: CLPlacemark) -> String {
        var parts: [String] = []
        if let name = placemark.name { parts.append(name) }
        if let locality = placemark.locality { parts.append(locality) }
        if let admin = placemark.administrativeArea { parts.append(admin) }
        return parts.joined(separator: ", ")
    }

    private func coordinateString(_ location: CLLocation) -> String {
        let lat = String(format: "%.4f", location.coordinate.latitude)
        let lon = String(format: "%.4f", location.coordinate.longitude)
        return "(\(lat), \(lon))"
    }

    private func addStop() {
        guard let location = locationManager.currentLocation else { return }
        let manager = DataManager(modelContext: modelContext)
        let stop = manager.addStop(
            to: day,
            name: name.trimmingCharacters(in: .whitespaces),
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            category: category
        )
        stop.arrivalTime = Date()
        try? modelContext.save()
        dismiss()
    }

    private func categoryIconName(_ cat: StopCategory) -> String {
        switch cat {
        case .accommodation: return "bed.double.fill"
        case .restaurant: return "fork.knife"
        case .attraction: return "star.fill"
        case .transport: return "airplane"
        case .activity: return "figure.run"
        case .other: return "mappin"
        }
    }

    private func categoryColor(_ cat: StopCategory) -> Color {
        switch cat {
        case .accommodation: return .purple
        case .restaurant: return .orange
        case .attraction: return .yellow
        case .transport: return .blue
        case .activity: return .green
        case .other: return .gray
        }
    }
}
