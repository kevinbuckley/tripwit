import SwiftUI
import CoreData
import MapKit
import TripCore

struct StopDetailView: View {

    @Environment(\.managedObjectContext) private var viewContext
    let stop: StopEntity
    var canEdit: Bool = true

    @State private var showingEditStop = false
    @State private var showingNearbyAI = false
    @State private var showingLocateAI = false
    @State private var showingRatingSheet = false
    @State private var pendingRating: Int = 0
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
                        Marker(stop.wrappedName, coordinate: coordinate)
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

                if let address = stop.address, !address.isEmpty {
                    LabeledContent("Address", value: address)
                }
                if let phone = stop.phone, !phone.isEmpty,
                   let phoneURL = URL(string: "tel:\(phone.filter { $0.isNumber || $0 == "+" })") {
                    HStack {
                        Text("Phone")
                        Spacer()
                        Link(phone, destination: phoneURL)
                            .font(.subheadline)
                    }
                }
                if let website = stop.website, !website.isEmpty,
                   let websiteURL = URL(string: website) {
                    HStack {
                        Text("Website")
                        Spacer()
                        Link("Open", destination: websiteURL)
                            .font(.subheadline)
                    }
                }
            } header: {
                Text("Details")
            }

            if !stop.wrappedNotes.isEmpty {
                Section {
                    Text(stop.wrappedNotes)
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
                .accessibilityLabel("Get directions to \(stop.wrappedName)")
            }

            // AI Nearby Suggestions
            nearbyAISection

            // Photos
            if hasLocation, stop.day?.trip != nil {
                StopPhotosView(stop: stop)
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(stop.wrappedName)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            if canEdit {
                ToolbarItem(placement: .primaryAction) {
                    Button("Edit") {
                        showingEditStop = true
                    }
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
        } else if canEdit {
            markAsVisitedButton
        }
    }

    private var visitedStatusRow: some View {
        VStack(alignment: .leading, spacing: 8) {
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
                    }
                }
                Spacer()
                if canEdit {
                    Button("Undo") {
                        stop.isVisited = false
                        stop.visitedAt = nil
                        stop.rating = 0
                        try? viewContext.save()
                    }
                    .font(.subheadline)
                    .foregroundColor(.red)
                }
            }

            // Star rating display / editor
            HStack(spacing: 4) {
                ForEach(1...5, id: \.self) { star in
                    Button {
                        if canEdit {
                            stop.rating = Int32(star)
                            try? viewContext.save()
                        }
                    } label: {
                        Image(systemName: star <= Int(stop.rating) ? "star.fill" : "star")
                            .font(.title3)
                            .foregroundStyle(star <= stop.rating ? .yellow : Color(.systemGray4))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canEdit)
                }
                if stop.rating > 0 {
                    Text("\(stop.rating)/5")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 4)
                }
            }
        }
    }

    private var markAsVisitedButton: some View {
        Button {
            showingRatingSheet = true
            pendingRating = 0
        } label: {
            HStack {
                Image(systemName: "checkmark.circle")
                Text("Mark as Visited")
                    .fontWeight(.medium)
            }
            .foregroundColor(.green)
        }
        .accessibilityLabel("Mark \(stop.wrappedName) as visited")
        .alert("Rate Your Visit", isPresented: $showingRatingSheet) {
            ForEach([1, 2, 3, 4, 5], id: \.self) { stars in
                Button(String(repeating: "★", count: stars) + String(repeating: "☆", count: 5 - stars)) {
                    stop.isVisited = true
                    stop.visitedAt = Date()
                    stop.rating = Int32(stars)
                    try? viewContext.save()
                }
            }
            Button("Skip Rating") {
                stop.isVisited = true
                stop.visitedAt = Date()
                stop.rating = 0
                try? viewContext.save()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("How was \(stop.wrappedName)?")
        }
    }

    // MARK: - Comments

    private var sortedComments: [CommentEntity] {
        stop.commentsArray.sorted { $0.wrappedCreatedAt > $1.wrappedCreatedAt }
    }

    private var commentsSection: some View {
        Section {
            if canEdit {
                addCommentRow
            }
            ForEach(sortedComments) { comment in
                commentRow(comment)
            }
            .onDelete { offsets in
                if canEdit {
                    deleteComments(at: offsets)
                }
            }
            .deleteDisabled(!canEdit)
        } header: {
            HStack {
                Text("Comments")
                Spacer()
                Text("\(stop.commentsArray.count)")
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
            .accessibilityLabel("Send comment")
        }
    }

    private func commentRow(_ comment: CommentEntity) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(comment.wrappedText)
                .font(.body)
            Text(comment.wrappedCreatedAt, style: .relative)
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
        let comment = CommentEntity.create(in: viewContext, text: trimmed)
        comment.stop = stop
        try? viewContext.save()
        newCommentText = ""
    }

    private func deleteComments(at offsets: IndexSet) {
        let comments = sortedComments
        for index in offsets {
            let comment = comments[index]
            viewContext.delete(comment)
        }
        try? viewContext.save()
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
        #if canImport(FoundationModels)
        if #available(iOS 26, *), AITripPlanner.isDeviceSupported {
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
        #endif
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
        #if canImport(FoundationModels)
        if #available(iOS 26, *), AITripPlanner.isDeviceSupported, hasLocation, stop.day != nil {
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
        #endif
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
        mapItem.name = stop.wrappedName
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
