import SwiftUI
import SwiftData
import MapKit
import TripCore

struct StopDetailView: View {

    @Environment(\.modelContext) private var modelContext
    let stop: StopEntity

    @State private var showingEditStop = false

    private var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: stop.latitude, longitude: stop.longitude)
    }

    private var cameraPosition: MapCameraPosition {
        .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.005, longitudeDelta: 0.005)
        ))
    }

    private var timeFormatter: DateFormatter {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short
        return formatter
    }

    var body: some View {
        List {
            // Map section
            Section {
                Map(initialPosition: cameraPosition) {
                    Marker(stop.name, coordinate: coordinate)
                        .tint(markerColor)
                }
                .frame(height: 220)
                .listRowInsets(EdgeInsets())
            }

            // Info section
            Section {
                HStack {
                    Text("Category")
                    Spacer()
                    Label(categoryLabel, systemImage: categoryIcon)
                        .font(.subheadline)
                        .foregroundStyle(markerColor)
                }

                if stop.arrivalTime != nil || stop.departureTime != nil {
                    if let arrival = stop.arrivalTime {
                        LabeledContent("Arrival", value: timeFormatter.string(from: arrival))
                    }
                    if let departure = stop.departureTime {
                        LabeledContent("Departure", value: timeFormatter.string(from: departure))
                    }
                }

                LabeledContent("Latitude", value: String(format: "%.4f", stop.latitude))
                LabeledContent("Longitude", value: String(format: "%.4f", stop.longitude))
            } header: {
                Text("Details")
            }

            if !stop.notes.isEmpty {
                Section {
                    Text(stop.notes)
                        .font(.body)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Notes")
                }
            }

            // Get Directions
            Section {
                Button {
                    openDirections()
                } label: {
                    directionsButtonLabel
                }
            }

            // Photos placeholder
            Section {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.title)
                            .foregroundStyle(.secondary)
                        Text("Photos will appear here")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 20)
                    Spacer()
                }
            } header: {
                Text("Photos")
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(stop.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditStop = true
                }
            }
        }
        .sheet(isPresented: $showingEditStop) {
            EditStopSheet(stop: stop)
        }
    }

    private var directionsButtonLabel: some View {
        HStack {
            Spacer()
            Image(systemName: "arrow.triangle.turn.up.right.diamond.fill")
                .font(.body)
            Text("Get Directions")
                .font(.headline)
            Spacer()
        }
        .padding(.vertical, 8)
        .foregroundColor(.white)
        .listRowBackground(Color.blue)
    }

    private func openDirections() {
        let placemark = MKPlacemark(coordinate: coordinate)
        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = stop.name
        mapItem.openInMaps(launchOptions: [
            MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeWalking
        ])
    }

    private var categoryLabel: String {
        switch stop.category {
        case .accommodation: "Accommodation"
        case .restaurant: "Restaurant"
        case .attraction: "Attraction"
        case .transport: "Transport"
        case .activity: "Activity"
        case .other: "Other"
        }
    }

    private var categoryIcon: String {
        switch stop.category {
        case .accommodation: "bed.double.fill"
        case .restaurant: "fork.knife"
        case .attraction: "star.fill"
        case .transport: "airplane"
        case .activity: "figure.run"
        case .other: "mappin"
        }
    }

    private var markerColor: Color {
        switch stop.category {
        case .accommodation: .purple
        case .restaurant: .orange
        case .attraction: .yellow
        case .transport: .blue
        case .activity: .green
        case .other: .gray
        }
    }
}
