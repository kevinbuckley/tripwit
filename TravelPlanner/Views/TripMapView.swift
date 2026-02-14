import SwiftUI
import SwiftData
import MapKit
import TripCore

struct TripMapView: View {

    @Query(sort: \TripEntity.startDate, order: .reverse) private var allTrips: [TripEntity]

    @State private var selectedTripID: UUID?
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var navigateToTripID: UUID?

    private var activeTrip: TripEntity? {
        allTrips.first { $0.status == .active }
    }

    private var selectedTrip: TripEntity? {
        if let id = selectedTripID {
            return allTrips.first { $0.id == id }
        }
        return allTrips.first
    }

    private var allStops: [StopEntity] {
        guard let trip = selectedTrip else { return [] }
        return trip.days.flatMap { $0.stops }
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
        .onAppear {
            if selectedTripID == nil {
                selectedTripID = activeTrip?.id ?? allTrips.first?.id
            }
        }
        .onChange(of: selectedTripID) { _, _ in
            fitAllStops()
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        VStack(spacing: 0) {
            if let active = activeTrip {
                ActiveTripDashboard(trip: active)
            }

            if allTrips.count > 1 {
                tripPicker
            }

            mapContent
        }
    }

    // MARK: - Empty State

    private var emptyMapState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "map")
                .font(.system(size: 56))
                .foregroundStyle(.blue.opacity(0.5))
            Text("No Trips to Display")
                .font(.title3)
                .fontWeight(.medium)
            Text("Create a trip with stops to see them on the map.")
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Spacer()
        }
        .padding()
    }

    // MARK: - Trip Picker

    private var tripPicker: some View {
        VStack(spacing: 0) {
            pickerHeader
            pickerScrollView
        }
        .background(.ultraThinMaterial)
    }

    private var pickerHeader: some View {
        HStack {
            Text("SELECT A TRIP")
                .font(.caption)
                .fontWeight(.bold)
                .foregroundStyle(.secondary)
                .tracking(0.5)
            Spacer()
            Text("\(allTrips.count) trips")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }

    private var pickerScrollView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 10) {
                ForEach(allTrips) { trip in
                    tripCard(trip)
                }
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 12)
        }
    }

    // MARK: - Trip Card

    private func tripCard(_ trip: TripEntity) -> some View {
        let isSelected = trip.id == (selectedTripID ?? allTrips.first?.id)
        let stopCount = trip.days.flatMap { $0.stops }.count

        return Button {
            withAnimation(.easeInOut(duration: 0.2)) {
                selectedTripID = trip.id
            }
        } label: {
            tripCardLabel(trip: trip, isSelected: isSelected, stopCount: stopCount)
        }
        .buttonStyle(.plain)
    }

    private func tripCardLabel(trip: TripEntity, isSelected: Bool, stopCount: Int) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(trip.name)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .lineLimit(1)
                Spacer(minLength: 4)
                StatusBadge(status: trip.status)
            }

            tripCardDestination(trip: trip, isSelected: isSelected)

            tripCardStats(trip: trip, isSelected: isSelected, stopCount: stopCount)

            if isSelected {
                viewTripButton(trip: trip)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(width: 220)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(isSelected ? Color.blue : Color(.systemGray6))
        )
        .foregroundStyle(isSelected ? .white : .primary)
    }

    private func viewTripButton(trip: TripEntity) -> some View {
        Button {
            navigateToTripID = trip.id
        } label: {
            HStack(spacing: 4) {
                Text("View Trip")
                    .font(.caption)
                    .fontWeight(.semibold)
                Image(systemName: "chevron.right")
                    .font(.caption2)
                    .fontWeight(.bold)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.25))
            .clipShape(Capsule())
        }
        .buttonStyle(.plain)
        .frame(maxWidth: .infinity, alignment: .trailing)
    }

    private func tripCardDestination(trip: TripEntity, isSelected: Bool) -> some View {
        HStack(spacing: 4) {
            Image(systemName: "mappin")
                .font(.caption2)
            Text(trip.destination)
                .font(.caption)
                .lineLimit(1)
        }
        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
    }

    private func tripCardStats(trip: TripEntity, isSelected: Bool, stopCount: Int) -> some View {
        HStack(spacing: 8) {
            Label("\(trip.durationInDays)d", systemImage: "calendar")
                .font(.caption2)
            Label("\(stopCount) stops", systemImage: "mappin.circle")
                .font(.caption2)
        }
        .foregroundColor(isSelected ? .white.opacity(0.7) : .gray)
    }

    // MARK: - Map

    private var mapContent: some View {
        ZStack(alignment: .bottomTrailing) {
            Map(position: $cameraPosition) {
                ForEach(allStops) { stop in
                    Marker(
                        stop.name,
                        coordinate: CLLocationCoordinate2D(
                            latitude: stop.latitude,
                            longitude: stop.longitude
                        )
                    )
                    .tint(markerColor(for: stop.category))
                }
            }
            .onAppear {
                fitAllStops()
            }

            if !allStops.isEmpty {
                fitButton
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
        .padding()
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

    private func statusColor(_ status: TripStatus) -> Color {
        switch status {
        case .planning: .blue
        case .active: .green
        case .completed: .gray
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
