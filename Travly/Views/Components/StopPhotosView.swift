import SwiftUI
import Photos
import TripCore

/// Displays auto-matched photos from the user's photo library for a stop.
struct StopPhotosView: View {

    let stop: StopEntity
    @State private var photoService = PhotoLibraryService()
    @State private var selectedPhotoID: PhotoID?
    @State private var fullImage: UIImage?

    private var allStopsInTrip: [StopEntity] {
        guard let day = stop.day, let trip = day.trip else { return [] }
        return trip.daysArray.flatMap(\.stopsArray)
    }

    private var tripStartDate: Date {
        stop.day?.trip?.startDate ?? Date()
    }

    private var tripEndDate: Date {
        stop.day?.trip?.endDate ?? Date()
    }

    var body: some View {
        Section {
            if !photoService.hasPermission && photoService.permissionStatus == .notDetermined {
                permissionRequestRow
            } else if !photoService.hasPermission {
                permissionDeniedRow
            } else if photoService.isLoading {
                loadingRow
            } else if photoService.matchedPhotos.isEmpty {
                emptyRow
            } else {
                photoGrid
            }
        } header: {
            HStack {
                Text("Photos")
                Spacer()
                if !photoService.matchedPhotos.isEmpty {
                    Text("\(photoService.matchedPhotos.count)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear {
            photoService.checkCurrentPermission()
        }
        .task {
            if photoService.hasPermission && photoService.matchedPhotos.isEmpty {
                await scanPhotos()
            }
        }
        .fullScreenCover(item: $selectedPhotoID) { photoID in
            PhotoFullScreenView(assetIdentifier: photoID.value, photoService: photoService)
        }
    }

    // MARK: - States

    private var permissionRequestRow: some View {
        Button {
            Task { await scanPhotos() }
        } label: {
            HStack {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.title2)
                        .foregroundStyle(.blue)
                    Text("Scan Photo Library")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Find photos taken at this stop")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(.vertical, 12)
                Spacer()
            }
        }
    }

    private var permissionDeniedRow: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("Photo access not available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text("Enable in Settings → Privacy → Photos")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.vertical, 12)
            Spacer()
        }
    }

    private var loadingRow: some View {
        HStack {
            Spacer()
            VStack(spacing: 8) {
                ProgressView()
                Text("Scanning photos...")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
            Spacer()
        }
    }

    private var emptyRow: some View {
        HStack {
            Spacer()
            VStack(spacing: 6) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.title2)
                    .foregroundStyle(.secondary)
                Text("No matching photos found")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Button {
                    Task { await scanPhotos() }
                } label: {
                    Label("Scan Again", systemImage: "arrow.clockwise")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .padding(.top, 4)
            }
            .padding(.vertical, 12)
            Spacer()
        }
    }

    // MARK: - Photo Grid

    private var photoGrid: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollView(.horizontal, showsIndicators: false) {
                LazyHStack(spacing: 8) {
                    ForEach(photoService.matchedPhotos, id: \.photo.assetIdentifier) { result in
                        PhotoThumbnailView(
                            assetIdentifier: result.photo.assetIdentifier,
                            confidence: result.confidence,
                            photoService: photoService
                        )
                        .onTapGesture {
                            selectedPhotoID = PhotoID(result.photo.assetIdentifier)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
            .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))

            Button {
                Task { await scanPhotos() }
            } label: {
                Label("Rescan", systemImage: "arrow.clockwise")
                    .font(.caption)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
        }
    }

    private func scanPhotos() async {
        await photoService.matchPhotos(
            for: stop,
            allStops: allStopsInTrip,
            tripStartDate: tripStartDate,
            tripEndDate: tripEndDate
        )
    }
}

// MARK: - Thumbnail View

private struct PhotoThumbnailView: View {

    let assetIdentifier: String
    let confidence: MatchConfidence
    let photoService: PhotoLibraryService

    @State private var image: UIImage?

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .frame(width: 80, height: 80)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(.secondarySystemFill))
                    .frame(width: 80, height: 80)
                    .overlay {
                        ProgressView()
                            .controlSize(.mini)
                    }
            }

            // Confidence badge
            Circle()
                .fill(confidenceColor)
                .frame(width: 12, height: 12)
                .overlay {
                    Circle()
                        .stroke(.white, lineWidth: 1.5)
                }
                .offset(x: -4, y: -4)
                .accessibilityHidden(true)
        }
        .accessibilityLabel("Photo, \(confidenceLabel) match confidence")
        .onAppear {
            photoService.loadThumbnail(
                assetIdentifier: assetIdentifier,
                targetSize: CGSize(width: 160, height: 160)
            ) { loaded in
                image = loaded
            }
        }
    }

    private var confidenceColor: Color {
        switch confidence {
        case .high: .green
        case .medium: .yellow
        case .low: .gray
        }
    }

    private var confidenceLabel: String {
        switch confidence {
        case .high: "high"
        case .medium: "medium"
        case .low: "low"
        }
    }
}

// MARK: - Full Screen Photo

private struct PhotoFullScreenView: View {

    let assetIdentifier: String
    let photoService: PhotoLibraryService

    @Environment(\.dismiss) private var dismiss
    @State private var image: UIImage?

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            if let image {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
            } else {
                ProgressView()
                    .tint(.white)
            }
        }
        .overlay(alignment: .topTrailing) {
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundStyle(.white.opacity(0.8))
                    .padding()
            }
            .accessibilityLabel("Close photo")
        }
        .onAppear {
            photoService.loadFullImage(assetIdentifier: assetIdentifier) { loaded in
                image = loaded
            }
        }
    }
}

// MARK: - Identifiable wrapper for photo asset IDs

struct PhotoID: Identifiable {
    let id: String
    var value: String { id }
    init(_ value: String) { self.id = value }
}
