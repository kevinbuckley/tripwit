import SwiftUI
import MapKit

struct LocationSearchResult: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let latitude: Double
    let longitude: Double
}

struct LocationSearchView: View {

    @Binding var selectedName: String
    @Binding var selectedLatitude: Double
    @Binding var selectedLongitude: Double

    @State private var searchText = ""
    @State private var searchResults: [LocationSearchResult] = []
    @State private var isSearching = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var searchTask: Task<Void, Never>?
    @State private var hasSelected = false
    @State private var searchError: String?

    private var hasLocation: Bool {
        selectedLatitude != 0 || selectedLongitude != 0
    }

    var body: some View {
        VStack(spacing: 0) {
            searchBar
            if hasSelected && hasLocation {
                selectedLocationBanner
            }
            if let error = searchError, !hasSelected {
                searchErrorBanner(error)
            }
            if !searchResults.isEmpty && !hasSelected {
                resultsList
            }
            mapPreview
        }
    }

    private func searchErrorBanner(_ message: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: "exclamationmark.triangle.fill")
                .foregroundColor(.orange)
                .font(.caption)
            Text(message)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .padding(.horizontal)
        .padding(.vertical, 6)
    }

    // MARK: - Search Bar

    private var searchBar: some View {
        HStack {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Type a place name...", text: $searchText)
                .textFieldStyle(.plain)
                .autocorrectionDisabled()
                .onChange(of: searchText) { _, newValue in
                    hasSelected = false
                    debounceSearch(query: newValue)
                }
            searchBarTrailing
        }
        .padding(10)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .padding(.horizontal)
        .padding(.top, 8)
    }

    @ViewBuilder
    private var searchBarTrailing: some View {
        if isSearching {
            ProgressView()
                .controlSize(.small)
        } else if !searchText.isEmpty {
            Button {
                clearSearch()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Selected Location Banner

    private var selectedLocationBanner: some View {
        HStack(spacing: 8) {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 1) {
                Text(selectedName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(String(format: "%.4f, %.4f", selectedLatitude, selectedLongitude))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button {
                clearSearch()
            } label: {
                Text("Change")
                    .font(.caption)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color.green.opacity(0.08))
    }

    // MARK: - Results List

    private var resultsList: some View {
        VStack(spacing: 0) {
            ForEach(searchResults) { result in
                resultRow(result)
            }
        }
        .padding(.horizontal)
        .padding(.top, 4)
    }

    private func resultRow(_ result: LocationSearchResult) -> some View {
        Button {
            selectResult(result)
        } label: {
            resultRowLabel(result)
        }
        .buttonStyle(.plain)
    }

    private func resultRowLabel(_ result: LocationSearchResult) -> some View {
        HStack(spacing: 10) {
            Image(systemName: "mappin.circle.fill")
                .foregroundColor(.red)
                .font(.title3)
            VStack(alignment: .leading, spacing: 1) {
                Text(result.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }
            Spacer()
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .contentShape(Rectangle())
    }

    // MARK: - Map Preview

    private var mapPreview: some View {
        Map(position: $cameraPosition) {
            if hasLocation {
                Marker(
                    selectedName.isEmpty ? "Selected" : selectedName,
                    coordinate: CLLocationCoordinate2D(
                        latitude: selectedLatitude,
                        longitude: selectedLongitude
                    )
                )
            }
        }
        .frame(height: 160)
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    // MARK: - Search Logic

    private func debounceSearch(query: String) {
        searchTask?.cancel()
        searchError = nil
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard trimmed.count >= 2 else {
            searchResults = []
            return
        }
        searchTask = Task {
            try? await Task.sleep(for: .milliseconds(400))
            guard !Task.isCancelled else { return }
            await performSearch(query: trimmed)
        }
    }

    @MainActor
    private func performSearch(query: String) async {
        isSearching = true
        searchError = nil
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = query

        let search = MKLocalSearch(request: request)
        do {
            let response = try await search.start()
            guard !Task.isCancelled else { return }
            searchResults = response.mapItems.prefix(6).map { item in
                LocationSearchResult(
                    name: item.name ?? "Unknown",
                    subtitle: item.placemark.title ?? "",
                    latitude: item.placemark.coordinate.latitude,
                    longitude: item.placemark.coordinate.longitude
                )
            }
            if searchResults.isEmpty {
                searchError = "No results found for \"\(query)\""
            }
        } catch let error as MKError where error.code == .placemarkNotFound {
            searchResults = []
            searchError = "No places found for \"\(query)\""
        } catch let urlError as URLError where urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
            searchResults = []
            searchError = "No internet connection"
        } catch {
            searchResults = []
            searchError = "Search failed — try again"
        }
        isSearching = false
    }

    private func selectResult(_ result: LocationSearchResult) {
        selectedName = result.name
        selectedLatitude = result.latitude
        selectedLongitude = result.longitude
        searchText = result.name
        searchResults = []
        hasSelected = true

        let coordinate = CLLocationCoordinate2D(latitude: result.latitude, longitude: result.longitude)
        cameraPosition = .region(MKCoordinateRegion(
            center: coordinate,
            span: MKCoordinateSpan(latitudeDelta: 0.01, longitudeDelta: 0.01)
        ))
    }

    private func clearSearch() {
        searchText = ""
        searchResults = []
        searchError = nil
        selectedName = ""
        selectedLatitude = 0
        selectedLongitude = 0
        hasSelected = false
        cameraPosition = .automatic
    }
}
