import SwiftUI
import MapKit

struct LocationSearchResult: Identifiable {
    let id = UUID()
    let name: String
    let subtitle: String
    let city: String
    let latitude: Double
    let longitude: Double
    let address: String
    let phone: String
    let website: String
}

struct LocationSearchView: View {

    @Binding var selectedName: String
    @Binding var selectedLatitude: Double
    @Binding var selectedLongitude: Double
    @Binding var selectedCity: String

    /// Optional bindings for place details auto-fill
    var selectedAddress: Binding<String>?
    var selectedPhone: Binding<String>?
    var selectedWebsite: Binding<String>?

    @State private var searchText = ""
    @State private var searchResults: [LocationSearchResult] = []
    @State private var isSearching = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var searchTask: Task<Void, Never>?
    @State private var hasSelected = false
    @State private var searchError: String?
    @State private var showingFullscreenMap = false

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
                .foregroundStyle(.orange)
                .font(.caption)
            Text(message)
                .font(.caption)
                .foregroundStyle(.secondary)
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
                .foregroundStyle(.green)
            VStack(alignment: .leading, spacing: 1) {
                Text(selectedName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(String(format: "%.4f, %.4f", selectedLatitude, selectedLongitude))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Button {
                clearSearch()
            } label: {
                Text("Change")
                    .font(.caption)
                    .foregroundStyle(.blue)
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
                .foregroundStyle(.red)
                .font(.title3)
            VStack(alignment: .leading, spacing: 1) {
                Text(result.name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
                if !result.subtitle.isEmpty {
                    Text(result.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
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
        .overlay(alignment: .topTrailing) {
            if hasLocation {
                Image(systemName: "arrow.up.left.and.arrow.down.right")
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .padding(5)
                    .background(.ultraThinMaterial)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .padding(6)
            }
        }
        .onTapGesture {
            if hasLocation {
                showingFullscreenMap = true
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .fullScreenCover(isPresented: $showingFullscreenMap) {
            FullscreenMapSheet(
                coordinate: CLLocationCoordinate2D(
                    latitude: selectedLatitude,
                    longitude: selectedLongitude
                ),
                markerTitle: selectedName.isEmpty ? "Selected Location" : selectedName
            )
        }
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
                let placemark = item.placemark
                let city = placemark.locality ?? placemark.administrativeArea ?? ""
                let parts = [placemark.subThoroughfare, placemark.thoroughfare, placemark.locality, placemark.administrativeArea, placemark.postalCode].compactMap { $0 }
                return LocationSearchResult(
                    name: item.name ?? "Unknown",
                    subtitle: placemark.title ?? "",
                    city: city,
                    latitude: placemark.coordinate.latitude,
                    longitude: placemark.coordinate.longitude,
                    address: parts.joined(separator: ", "),
                    phone: item.phoneNumber ?? "",
                    website: item.url?.absoluteString ?? ""
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
        selectedCity = result.city
        searchText = result.name
        searchResults = []
        hasSelected = true

        // Auto-fill place details if bindings are provided
        if !result.address.isEmpty { selectedAddress?.wrappedValue = result.address }
        if !result.phone.isEmpty { selectedPhone?.wrappedValue = result.phone }
        if !result.website.isEmpty { selectedWebsite?.wrappedValue = result.website }

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
        selectedCity = ""
        hasSelected = false
        cameraPosition = .automatic
    }
}
