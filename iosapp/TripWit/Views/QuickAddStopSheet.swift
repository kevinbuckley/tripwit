import SwiftUI
import CoreData
import CoreLocation
import TripCore

struct QuickAddStopSheet: View {

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss
    @Environment(LocationManager.self) private var locationManager

    let day: DayEntity

    @State private var resolvedName: String?
    @State private var isGeocoding = false
    @State private var didAdd = false

    private var hasLocation: Bool {
        locationManager.currentLocation != nil
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                Spacer()
                locationStatusSection
                Spacer()
            }
            .padding(16)
            .navigationTitle("I'm Here")
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
            }
            .onChange(of: locationManager.currentLocation) { _, newLocation in
                if let loc = newLocation {
                    reverseGeocodeAndAdd(loc)
                }
            }
        }
    }

    // MARK: - Location Status

    private var locationStatusSection: some View {
        VStack(spacing: 12) {
            if didAdd, let name = resolvedName {
                // Success state
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.green)
                Text(name)
                    .font(.title3)
                    .fontWeight(.semibold)
                    .multilineTextAlignment(.center)
                Text("Added to today's itinerary")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            } else if locationManager.isDenied {
                // Permission denied state
                Image(systemName: "location.slash.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.red)
                Text("Location Access Denied")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("Enable location access in Settings to use this feature.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Open Settings") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            } else if let error = locationManager.locationError {
                // Error state
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(.orange)
                Text(error)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                Button("Try Again") {
                    locationManager.requestLocation()
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
            } else {
                // Loading state
                ProgressView()
                    .controlSize(.large)
                Text(isGeocoding ? "Finding place name..." : "Getting your location...")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    // MARK: - Helpers

    private func requestLocationIfNeeded() {
        if locationManager.isDenied {
            // Already denied — UI will show settings prompt
            return
        }
        if !locationManager.isAuthorized {
            locationManager.requestPermission()
        } else {
            locationManager.requestLocation()
        }
    }

    private func reverseGeocodeAndAdd(_ location: CLLocation) {
        guard !didAdd else { return }
        isGeocoding = true
        let geocoder = CLGeocoder()
        Task {
            let placemarks = try? await geocoder.reverseGeocodeLocation(location)
            await MainActor.run {
                isGeocoding = false
                let placemark = placemarks?.first
                // Use the place name (e.g. "Starbucks", "Central Park") or fall back to address
                let placeName = placemark?.name
                    ?? placemark?.locality
                    ?? "Current Location"

                resolvedName = placeName
                addStop(name: placeName, location: location)
            }
        }
    }

    private func addStop(name: String, location: CLLocation) {
        let manager = DataManager(context: viewContext)
        let stop = manager.addStop(
            to: day,
            name: name,
            latitude: location.coordinate.latitude,
            longitude: location.coordinate.longitude,
            category: .other
        )
        stop.arrivalTime = Date()
        try? viewContext.save()
        didAdd = true

        // Haptic feedback on success
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        // Auto-dismiss after a short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            dismiss()
        }
    }
}
