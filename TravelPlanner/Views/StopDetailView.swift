import SwiftUI
import SwiftData
import MapKit
import TripCore

struct StopDetailView: View {

    @Environment(\.modelContext) private var modelContext
    let stop: StopEntity

    @State private var showingEditStop = false
    @State private var showingNearbyAI = false
    @State private var showingLocateAI = false
    @State private var newCommentText = ""

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
            // Map section or Locate button
            if hasLocation {
                Section {
                    Map(initialPosition: cameraPosition) {
                        Marker(stop.name, coordinate: coordinate)
                            .tint(markerColor)
                    }
                    .frame(height: 220)
                    .listRowInsets(EdgeInsets())
                }
            } else {
                locateSection
            }

            // Visited section
            Section {
                visitedContent
            } header: {
                Text("Status")
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

            // Comments
            commentsSection

            // Get Directions
            Section {
                Button {
                    openDirections()
                } label: {
                    HStack {
                        Spacer()
                        Label("Get Directions", systemImage: "arrow.triangle.turn.up.right.diamond.fill")
                            .font(.headline)
                        Spacer()
                    }
                    .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
                .tint(.blue)
                .listRowBackground(Color.clear)
            }

            // AI Nearby Suggestions
            nearbyAISection

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
        .sheet(isPresented: $showingNearbyAI) {
            nearbyAISheet
        }
        .sheet(isPresented: $showingLocateAI) {
            locateAISheet
        }
    }

    // MARK: - Visited Content

    @ViewBuilder
    private var visitedContent: some View {
        if stop.isVisited {
            visitedStatusRow
        } else {
            markAsVisitedButton
        }
    }

    private var visitedStatusRow: some View {
        HStack {
            Image(systemName: "checkmark.circle.fill")
                .foregroundColor(.green)
            VStack(alignment: .leading, spacing: 2) {
                Text("Visited")
                    .fontWeight(.medium)
                if let visitedAt = stop.visitedAt {
                    Text(visitedAt, style: .date)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Text(visitedAt, style: .time)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            Spacer()
            Button("Undo") {
                toggleVisitedStatus()
            }
            .font(.subheadline)
            .foregroundColor(.red)
        }
    }

    private var markAsVisitedButton: some View {
        Button {
            toggleVisitedStatus()
        } label: {
            HStack {
                Image(systemName: "checkmark.circle")
                Text("Mark as Visited")
                    .fontWeight(.medium)
            }
            .foregroundColor(.green)
        }
    }

    private func toggleVisitedStatus() {
        stop.isVisited.toggle()
        stop.visitedAt = stop.isVisited ? Date() : nil
        try? modelContext.save()
    }

    // MARK: - Comments

    private var sortedComments: [CommentEntity] {
        stop.comments.sorted { $0.createdAt > $1.createdAt }
    }

    private var commentsSection: some View {
        Section {
            addCommentRow
            ForEach(sortedComments) { comment in
                commentRow(comment)
            }
            .onDelete { offsets in
                deleteComments(at: offsets)
            }
        } header: {
            HStack {
                Text("Comments")
                Spacer()
                Text("\(stop.comments.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    private var addCommentRow: some View {
        HStack(spacing: 10) {
            TextField("Add a comment...", text: $newCommentText, axis: .vertical)
                .lineLimit(1...4)
            Button {
                addComment()
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.title2)
                    .foregroundColor(newCommentText.trimmingCharacters(in: .whitespaces).isEmpty ? .gray : .blue)
            }
            .disabled(newCommentText.trimmingCharacters(in: .whitespaces).isEmpty)
            .buttonStyle(.plain)
        }
    }

    private func commentRow(_ comment: CommentEntity) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(comment.text)
                .font(.body)
            Text(comment.createdAt, style: .relative)
                .font(.caption2)
                .foregroundColor(.secondary)
            + Text(" ago")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(.vertical, 2)
    }

    private func addComment() {
        let trimmed = newCommentText.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        let comment = CommentEntity(text: trimmed)
        comment.stop = stop
        stop.comments.append(comment)
        modelContext.insert(comment)
        try? modelContext.save()
        newCommentText = ""
    }

    private func deleteComments(at offsets: IndexSet) {
        let comments = sortedComments
        for index in offsets {
            let comment = comments[index]
            modelContext.delete(comment)
        }
        try? modelContext.save()
    }

    // MARK: - Locate AI

    private var hasLocation: Bool {
        stop.latitude != 0 || stop.longitude != 0
    }

    private var locateSection: some View {
        Section {
            VStack(spacing: 12) {
                Image(systemName: "mappin.slash")
                    .font(.title)
                    .foregroundStyle(.secondary)
                Text("No location set")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                locateButton
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
        }
    }

    @ViewBuilder
    private var locateButton: some View {
        if #available(iOS 26, *) {
            Button {
                showingLocateAI = true
            } label: {
                Label("Locate with AI", systemImage: "sparkles")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            .buttonStyle(.borderedProminent)
            .tint(.purple)
        }
    }

    @ViewBuilder
    private var locateAISheet: some View {
        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            LocateStopSheet(stop: stop)
        }
        #else
        Text("Apple Intelligence requires iOS 26")
        #endif
    }

    // MARK: - Nearby AI

    @ViewBuilder
    private var nearbyAISection: some View {
        if #available(iOS 26, *), hasLocation, stop.day != nil {
            Section {
                Button {
                    showingNearbyAI = true
                } label: {
                    nearbyButtonLabel
                }
                .buttonStyle(.borderedProminent)
                .tint(.purple)
                .listRowBackground(Color.clear)
            }
        }
    }

    private var nearbyButtonLabel: some View {
        HStack {
            Spacer()
            Label("Explore Nearby", systemImage: "sparkles")
                .font(.headline)
            Spacer()
        }
        .padding(.vertical, 4)
    }

    @ViewBuilder
    private var nearbyAISheet: some View {
        #if canImport(FoundationModels)
        if #available(iOS 26, *), let day = stop.day {
            NearbyAISuggestSheet(stop: stop, day: day)
        }
        #else
        Text("Apple Intelligence requires iOS 26")
        #endif
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
