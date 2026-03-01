import SwiftUI
import MapKit
import CoreLocation
import TripCore

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

    /// Optional region hint — biases results toward this area (e.g. trip destination)
    var searchRegion: MKCoordinateRegion?

    /// Stop category — filters results to relevant place types and powers auto-suggestions
    var category: StopCategory? = nil

    /// Country name for query enrichment (e.g. "Japan") — reduces wrong-country results
    var tripCountry: String? = nil

    @State private var searchText = ""
    @State private var searchResults: [LocationSearchResult] = []
    @State private var isSearching = false
    @State private var cameraPosition: MapCameraPosition = .automatic
    @State private var searchTask: Task<Void, Never>?
    @State private var hasSelected = false
    @State private var searchError: String?
    @State private var showingFullscreenMap = false

    // MARK: - POI Filter

    /// Maps StopCategory to MapKit POI categories for smarter results.
    private var pointOfInterestFilter: MKPointOfInterestFilter? {
        guard let cat = category else { return nil }
        let cats: [MKPointOfInterestCategory]
        switch cat {
        case .accommodation:
            cats = [.hotel]
        case .restaurant:
            cats = [.restaurant, .cafe, .bakery, .brewery, .foodMarket]
        case .attraction:
            cats = [.museum, .nationalPark, .amusementPark, .aquarium, .zoo,
                    .stadium, .theater, .university, .library]
        case .transport:
            cats = [.airport, .publicTransport]
        case .activity:
            cats = [.beach, .nationalPark, .park, .fitnessCenter, .campground, .marina]
        case .other:
            return nil
        }
        return MKPointOfInterestFilter(including: cats)
    }

    /// Generic search term used when showing auto-suggestions (empty query).
    private var autoSuggestionQuery: String {
        switch category {
        case .accommodation: return "hotel"
        case .restaurant: return "restaurant"
        case .attraction: return "sightseeing attraction"
        case .transport: return "airport transit"
        case .activity: return "park outdoor"
        case .other, .none: return "place"
        }
    }

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
        // Trigger auto-suggestions when region first becomes available (after async geocoding)
        .task(id: searchRegion.map { "\($0.center.latitude)" } ?? "none") {
            if searchRegion != nil && !hasSelected && searchText.isEmpty {
                await performAutoSuggestions()
            }
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
            if searchText.isEmpty {
                HStack {
                    Label("Nearby", systemImage: "location.fill")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                        .padding(.bottom, 2)
                    Spacer()
                }
            }
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

    // MARK: - Search Dispatch

    private func debounceSearch(query: String) {
        searchTask?.cancel()
        searchError = nil
        let trimmed = query.trimmingCharacters(in: .whitespaces)

        if trimmed.isEmpty {
            searchResults = []
            // Show nearby auto-suggestions when query is cleared
            if searchRegion != nil {
                searchTask = Task {
                    await performAutoSuggestions()
                }
            }
            return
        }

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

    // MARK: - Auto-Suggestions (empty query)

    /// Fires when the search field is empty but a region is available.
    /// Shows nearby places matching the stop's category.
    @MainActor
    private func performAutoSuggestions() async {
        guard let region = searchRegion else { return }
        isSearching = true
        searchError = nil

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = autoSuggestionQuery
        request.region = region
        request.resultTypes = .pointOfInterest
        if let filter = pointOfInterestFilter {
            request.pointOfInterestFilter = filter
        }

        do {
            let response = try await MKLocalSearch(request: request).start()
            guard !Task.isCancelled else { return }
            searchResults = distanceSorted(items: Array(response.mapItems.prefix(8)), from: region.center)
        } catch {
            searchResults = []
        }
        isSearching = false
    }

    // MARK: - Typed Search

    @MainActor
    private func performSearch(query: String) async {
        isSearching = true
        searchError = nil

        // Enrich short queries with the trip country to anchor results geographically.
        // "Senso-ji" → "Senso-ji, Japan" prevents matching a lookalike in the wrong country.
        let enriched: String
        if let country = tripCountry, !country.isEmpty,
           query.split(separator: " ").count <= 4,
           !query.localizedCaseInsensitiveContains(country) {
            enriched = "\(query), \(country)"
        } else {
            enriched = query
        }

        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = enriched
        if let region = searchRegion { request.region = region }
        if let filter = pointOfInterestFilter { request.pointOfInterestFilter = filter }

        var items: [MKMapItem] = []
        do {
            let response = try await MKLocalSearch(request: request).start()
            items = response.mapItems
        } catch let error as MKError where error.code == .placemarkNotFound {
            // handled below — items stays empty
        } catch let urlError as URLError
            where urlError.code == .notConnectedToInternet || urlError.code == .networkConnectionLost {
            searchResults = []
            searchError = "No internet connection"
            isSearching = false
            return
        } catch {
            searchResults = []
            searchError = "Search failed — try again"
            isSearching = false
            return
        }

        // If the category filter was too strict, retry without it
        if items.isEmpty, pointOfInterestFilter != nil {
            let fallback = MKLocalSearch.Request()
            fallback.naturalLanguageQuery = enriched
            if let region = searchRegion { fallback.region = region }
            if let resp = try? await MKLocalSearch(request: fallback).start() {
                items = resp.mapItems
            }
        }

        guard !Task.isCancelled else { return }

        let limited = Array(items.prefix(8))
        if let center = searchRegion?.center {
            searchResults = distanceSorted(items: limited, from: center)
        } else {
            searchResults = buildResults(from: limited)
        }

        if searchResults.isEmpty {
            searchError = "No results found for \"\(query)\""
        }
        isSearching = false
    }

    // MARK: - Result Builders

    private func buildResults(from items: [MKMapItem]) -> [LocationSearchResult] {
        items.map { item in
            let placemark = item.placemark
            let city = placemark.locality ?? placemark.administrativeArea ?? ""
            let parts = [placemark.subThoroughfare, placemark.thoroughfare,
                         placemark.locality, placemark.administrativeArea,
                         placemark.postalCode].compactMap { $0 }
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
    }

    /// Returns results sorted by distance from `center` (closest first).
    private func distanceSorted(items: [MKMapItem], from center: CLLocationCoordinate2D) -> [LocationSearchResult] {
        let anchor = CLLocation(latitude: center.latitude, longitude: center.longitude)
        return buildResults(from: items).sorted { a, b in
            let da = CLLocation(latitude: a.latitude, longitude: a.longitude).distance(from: anchor)
            let db = CLLocation(latitude: b.latitude, longitude: b.longitude).distance(from: anchor)
            return da < db
        }
    }

    // MARK: - Selection / Clear

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
