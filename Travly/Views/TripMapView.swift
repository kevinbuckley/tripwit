import SwiftUI
import CoreData
import MapKit
import TripCore

struct TripMapView: View {

    var onGoToTrips: (() -> Void)? = nil

    @FetchRequest(sortDescriptors: [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)]) private var allTrips: FetchedResults<TripEntity>

    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var navigateToTripID: UUID?
    @State private var selectedStopID: UUID?
    @State private var navigateToStopID: UUID?
    @State private var showNearbyPOIs = false
    @State private var nearbyPOIs: [MKMapItem] = []

    /// The trip to display: active trip first, then the nearest upcoming, then most recent.
    private var displayTrip: TripEntity? {
        // Active trip takes priority
        if let active = allTrips.first(where: { $0.status == .active }) {
            return active
        }
        // Next upcoming trip (earliest future start date)
        let upcoming = allTrips
            .filter { $0.status == .planning && $0.wrappedStartDate > Date() }
            .sorted { $0.wrappedStartDate < $1.wrappedStartDate }
        if let next = upcoming.first {
            return next
        }
        // Fall back to most recent trip
        return allTrips.first
    }

    private var allStops: [StopEntity] {
        guard let trip = displayTrip else { return [] }
        return trip.daysArray.flatMap { $0.stopsArray }.filter { $0.latitude != 0 || $0.longitude != 0 }
    }

    var body: some View {
        VStack(spacing: 0) {
            if allTrips.isEmpty {
                emptyMapState
            } else {
                mainContent
            }
        }
        .navigationTitle("Map")
        .navigationBarTitleDisplayMode(.inline)
        .navigationDestination(item: $navigateToTripID) { tripID in
            if let trip = allTrips.first(where: { $0.id == tripID }) {
                TripDetailView(trip: trip)
            }
        }
        .navigationDestination(item: $navigateToStopID) { stopID in
            if let stop = allStops.first(where: { $0.id == stopID }) {
                StopDetailView(stop: stop)
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            if let trip = displayTrip, trip.status == .active {
                ActiveTripDashboard(trip: trip)
            }

            if let trip = displayTrip {
                tripBanner(trip)
            }

            mapContent
        }
    }

    // MARK: - Trip Banner (replaces picker)

    private func tripBanner(_ trip: TripEntity) -> some View {
        Button {
            navigateToTripID = trip.id
        } label: {
            HStack(spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(trip.wrappedName)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    HStack(spacing: 4) {
                        Image(systemName: "mappin")
                            .font(.caption2)
                        Text(trip.wrappedDestination)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundStyle(.secondary)
                }
                Spacer()
                let stopCount = trip.daysArray.flatMap(\.stopsArray).count
                Text("\(stopCount) stop\(stopCount == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(.ultraThinMaterial)
        }
        .buttonStyle(.plain)
    }

    // MARK: - Empty State

    private var emptyMapState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "map")
                .font(.system(size: 56))
                .foregroundStyle(.blue.opacity(0.4))
            Text("No Trips to Display")
                .font(.title3)
                .fontWeight(.medium)
            Text("Create a trip with stops to see them here.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            if let goToTrips = onGoToTrips {
                Button {
                    goToTrips()
                } label: {
                    Label("Go to My Trips", systemImage: "list.bullet")
                        .font(.headline)
                        .padding(.horizontal, 24)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
            }
            Spacer()
        }
        .padding()
    }

    // MARK: - Map

    private var mapContent: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $cameraPosition, selection: $selectedStopID) {
                ForEach(allStops) { stop in
                    Marker(
                        stop.wrappedName,
                        coordinate: CLLocationCoordinate2D(
                            latitude: stop.latitude,
                            longitude: stop.longitude
                        )
                    )
                    .tint(markerColor(for: stop.category))
                    .tag(stop.id)
                }

                // Route lines between stops
                if let trip = displayTrip {
                    ForEach(trip.daysArray.sorted(by: { $0.dayNumber < $1.dayNumber }), id: \.id) { day in
                        let dayStops = day.stopsArray.sorted { $0.sortOrder < $1.sortOrder }
                            .filter { $0.latitude != 0 || $0.longitude != 0 }
                        if dayStops.count >= 2 {
                            let coords = dayStops.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
                            MapPolyline(coordinates: coords)
                                .stroke(dayColor(day.dayNumber), lineWidth: 3)
                        }
                    }
                }

                // Nearby POI markers
                ForEach(nearbyPOIs, id: \.self) { poi in
                    if let name = poi.name {
                        Marker(name, systemImage: "fork.knife", coordinate: poi.placemark.coordinate)
                            .tint(.red)
                    }
                }
            }
            .onAppear {
                fitAllStops()
            }
            .onChange(of: selectedStopID) { _, newValue in
                if let stopID = newValue {
                    navigateToStopID = stopID
                    selectedStopID = nil
                }
            }

            if !allStops.isEmpty {
                VStack(spacing: 8) {
                    fitButton
                    nearbyToggleButton
                }
                .padding(.trailing, 12)
                .padding(.bottom, 24)
            }
        }
    }

    private var fitButton: some View {
        Button {
            fitAllStops()
        } label: {
            Image(systemName: "arrow.up.left.and.arrow.down.right")
                .font(.body)
                .fontWeight(.medium)
                .padding(10)
                .background(.ultraThickMaterial)
                .clipShape(Circle())
                .shadow(radius: 2)
        }
        .accessibilityLabel("Fit all stops on map")
    }

    private var nearbyToggleButton: some View {
        Button {
            showNearbyPOIs.toggle()
            if showNearbyPOIs {
                searchNearby()
            } else {
                nearbyPOIs = []
            }
        } label: {
            Image(systemName: showNearbyPOIs ? "fork.knife.circle.fill" : "fork.knife.circle")
                .font(.body)
                .fontWeight(.medium)
                .padding(10)
                .background(.ultraThickMaterial)
                .clipShape(Circle())
                .shadow(radius: 2)
        }
        .accessibilityLabel(showNearbyPOIs ? "Hide nearby places" : "Show nearby restaurants")
    }

    private func searchNearby() {
        guard !allStops.isEmpty else { return }
        let lats = allStops.map(\.latitude)
        let lons = allStops.map(\.longitude)
        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else { return }
        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = "restaurant"
        request.region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: 0.05, longitudeDelta: 0.05)
        )
        let search = MKLocalSearch(request: request)
        Task {
            if let response = try? await search.start() {
                nearbyPOIs = Array(response.mapItems.prefix(15))
            }
        }
    }

    private func dayColor(_ dayNumber: Int32) -> Color {
        let colors: [Color] = [.blue, .green, .orange, .purple, .pink, .red, .teal, .indigo, .mint, .cyan]
        return colors[Int(dayNumber - 1) % colors.count]
    }

    // MARK: - Helpers

    private func fitAllStops() {
        guard !allStops.isEmpty else {
            cameraPosition = .automatic
            return
        }

        let lats = allStops.map(\.latitude)
        let lons = allStops.map(\.longitude)

        guard let minLat = lats.min(), let maxLat = lats.max(),
              let minLon = lons.min(), let maxLon = lons.max() else {
            return
        }

        let centerLat = (minLat + maxLat) / 2
        let centerLon = (minLon + maxLon) / 2
        let spanLat = max((maxLat - minLat) * 1.4, 0.01)
        let spanLon = max((maxLon - minLon) * 1.4, 0.01)

        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: centerLat, longitude: centerLon),
            span: MKCoordinateSpan(latitudeDelta: spanLat, longitudeDelta: spanLon)
        )
        withAnimation {
            cameraPosition = .region(region)
        }
    }

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
