import SwiftUI
import MapKit
import CoreData
import TripCore

/// A reusable fullscreen interactive map sheet.
/// Present from any embedded map to give users full pan/zoom/satellite capabilities.
struct FullscreenMapSheet: View {

    @Environment(\.dismiss) private var dismiss

    let coordinate: CLLocationCoordinate2D
    let markerTitle: String
    var markerTint: Color = .red
    var additionalStops: [StopEntity] = []

    @State private var cameraPosition: MapCameraPosition
    @State private var mapStyle: MapStyleOption = .standard

    enum MapStyleOption: String, CaseIterable {
        case standard = "Standard"
        case satellite = "Satellite"
        case hybrid = "Hybrid"

        var style: MapStyle {
            switch self {
            case .standard: .standard
            case .satellite: .imagery
            case .hybrid: .hybrid
            }
        }
    }

    init(
        coordinate: CLLocationCoordinate2D,
        markerTitle: String,
        markerTint: Color = .red,
        additionalStops: [StopEntity] = []
    ) {
        self.coordinate = coordinate
        self.markerTitle = markerTitle
        self.markerTint = markerTint
        self.additionalStops = additionalStops
        _cameraPosition = State(initialValue: .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        )))
    }

    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottomTrailing) {
                Map(position: $cameraPosition) {
                    // Primary marker
                    Marker(markerTitle, coordinate: coordinate)
                        .tint(markerTint)

                    // Additional stops from the same day (for context)
                    ForEach(additionalStops) { stop in
                        let stopCoord = CLLocationCoordinate2D(
                            latitude: stop.latitude,
                            longitude: stop.longitude
                        )
                        Marker(stop.wrappedName, coordinate: stopCoord)
                            .tint(markerColor(for: stop.category).opacity(0.6))
                    }
                }
                .mapStyle(mapStyle.style)

                // Map controls
                VStack(spacing: 8) {
                    recenterButton
                    openInMapsButton
                }
                .padding(.trailing, 12)
                .padding(.bottom, 24)
            }
            .navigationTitle(markerTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .principal) {
                    Picker("Map Style", selection: $mapStyle) {
                        ForEach(MapStyleOption.allCases, id: \.self) { option in
                            Text(option.rawValue).tag(option)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(maxWidth: 220)
                }
            }
        }
    }

    // MARK: - Controls

    private var recenterButton: some View {
        Button {
            withAnimation {
                cameraPosition = .region(MKCoordinateRegion(
                    center: coordinate,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
            }
        } label: {
            Image(systemName: "location.fill")
                .font(.body)
                .fontWeight(.medium)
                .padding(10)
                .background(.ultraThickMaterial)
                .clipShape(Circle())
                .shadow(radius: 2)
        }
        .accessibilityLabel("Recenter on location")
    }

    private var openInMapsButton: some View {
        Button {
            let mapItem = MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
            mapItem.name = markerTitle
            mapItem.openInMaps(launchOptions: [
                MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDefault
            ])
        } label: {
            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                .font(.body)
                .fontWeight(.medium)
                .padding(10)
                .background(.ultraThickMaterial)
                .clipShape(Circle())
                .shadow(radius: 2)
        }
        .accessibilityLabel("Open in Apple Maps")
    }

    // MARK: - Helpers

    private func markerColor(for category: StopCategory) -> Color {
        switch category {
        case .accommodation: .purple
        case .restaurant: .orange
        case .attraction: .yellow
        case .transport: .blue
        case .activity: .green
        case .other: .gray
        }
    }
}
