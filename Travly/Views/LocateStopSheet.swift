import SwiftUI
import CoreData
import MapKit
import TripCore

#if canImport(FoundationModels)
import FoundationModels

@available(iOS 26, *)
struct LocateStopSheet: View {

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let stop: StopEntity

    @State private var planner = AITripPlanner()
    @State private var hasApplied = false
    @State private var showingFullscreenMap = false

    private var destination: String {
        stop.day?.trip?.wrappedDestination ?? ""
    }

    var body: some View {
        NavigationStack {
            contentBody
                .navigationTitle("Locate")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") { dismiss() }
                    }
                }
                .task { await locate() }
        }
    }

    @ViewBuilder
    private var contentBody: some View {
        if planner.isLocating {
            locatingView
        } else if let error = planner.errorMessage {
            errorView(error)
        } else if let place = planner.locatedPlace {
            resultView(place)
        } else {
            ProgressView()
        }
    }

    private var locatingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .controlSize(.large)
            Text("Finding \(stop.wrappedName)...")
                .font(.headline)
            if !destination.isEmpty {
                Text("Searching in \(destination)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding()
    }

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 44))
                .foregroundStyle(.orange)
            Text(message)
                .font(.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await locate() }
            }
            .buttonStyle(.borderedProminent)
            Spacer()
        }
        .padding()
    }

    private func resultView(_ place: LocatedPlace) -> some View {
        let coord = CLLocationCoordinate2D(latitude: place.latitude, longitude: place.longitude)
        return List {
            Section {
                let position = MapCameraPosition.region(MKCoordinateRegion(
                    center: coord,
                    span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
                ))
                Map(initialPosition: position) {
                    Marker(place.name, coordinate: coord)
                }
                .frame(height: 200)
                .listRowInsets(EdgeInsets())
                .overlay(alignment: .topTrailing) {
                    Image(systemName: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .padding(6)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 6))
                        .padding(8)
                }
                .onTapGesture {
                    showingFullscreenMap = true
                }
            }

            Section {
                LabeledContent("Name", value: place.name)
                LabeledContent("Address", value: place.address)
            } header: {
                Text("Found Location")
            } footer: {
                Text("Powered by Apple Intelligence · Verify the pin is correct before applying.")
                    .font(.caption2)
            }

            Section {
                if hasApplied {
                    appliedRow
                } else {
                    applyButton(place)
                }
            }

            Section {
                Button {
                    Task { await locate() }
                } label: {
                    Label("Try Again", systemImage: "arrow.clockwise")
                }
            }
        }
        .listStyle(.insetGrouped)
        .fullScreenCover(isPresented: $showingFullscreenMap) {
            FullscreenMapSheet(
                coordinate: coord,
                markerTitle: place.name
            )
        }
    }

    private var appliedRow: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
            Text("Location applied!")
                .fontWeight(.medium)
            Spacer()
            Button("Done") { dismiss() }
                .fontWeight(.semibold)
        }
    }

    private func applyButton(_ place: LocatedPlace) -> some View {
        Button {
            applyLocation(place)
        } label: {
            HStack {
                Spacer()
                Label("Use This Location", systemImage: "mappin.circle.fill")
                    .font(.headline)
                Spacer()
            }
            .padding(.vertical, 4)
        }
        .buttonStyle(.borderedProminent)
        .tint(.purple)
        .listRowBackground(Color.clear)
    }

    // MARK: - Actions

    private func locate() async {
        hasApplied = false
        await planner.locatePlace(name: stop.wrappedName, destination: destination)
    }

    private func applyLocation(_ place: LocatedPlace) {
        stop.latitude = place.latitude
        stop.longitude = place.longitude
        stop.day?.trip?.updatedAt = Date()
        try? viewContext.save()
        hasApplied = true
    }
}
#endif
