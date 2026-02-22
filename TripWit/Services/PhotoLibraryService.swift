import Foundation
import Photos
import UIKit
import TripCore

/// Fetches photos from the user's photo library and matches them to stops using TripCore's PhotoMatcher.
@MainActor
@Observable
final class PhotoLibraryService {

    private(set) var matchedPhotos: [PhotoMatchResult] = []
    private(set) var isLoading = false
    private(set) var permissionStatus: PHAuthorizationStatus = .notDetermined
    private(set) var errorMessage: String?

    private let imageManager = PHCachingImageManager()

    // MARK: - Permission

    func requestPermission() async {
        // .readWrite is required to read photo metadata; .addOnly only allows writing
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        await MainActor.run {
            permissionStatus = status
        }
    }

    var hasPermission: Bool {
        permissionStatus == .authorized || permissionStatus == .limited
    }

    func checkCurrentPermission() {
        permissionStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
    }

    // MARK: - Fetch & Match

    /// Fetch photos from the library taken during the trip date range and match them to stops.
    func matchPhotos(for stop: StopEntity, allStops: [StopEntity], tripStartDate: Date, tripEndDate: Date) async {
        if !hasPermission {
            await requestPermission()
        }
        guard hasPermission else {
            await MainActor.run {
                errorMessage = "Photo library access is required to match photos."
            }
            return
        }

        await MainActor.run {
            isLoading = true
            errorMessage = nil
            matchedPhotos = []
        }

        // Build date range with 1-day buffer
        let calendar = Calendar.current
        let startDate = calendar.date(byAdding: .day, value: -1, to: tripStartDate) ?? tripStartDate
        let endDate = calendar.date(byAdding: .day, value: 2, to: tripEndDate) ?? tripEndDate

        // Fetch assets from library
        let fetchOptions = PHFetchOptions()
        fetchOptions.predicate = NSPredicate(
            format: "creationDate >= %@ AND creationDate <= %@",
            startDate as NSDate,
            endDate as NSDate
        )
        fetchOptions.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: true)]

        let assets = PHAsset.fetchAssets(with: .image, options: fetchOptions)

        // Convert to PhotoMetadata
        var photoMetadataList: [PhotoMetadata] = []
        assets.enumerateObjects { asset, _, _ in
            guard let location = asset.location else { return }
            let metadata = PhotoMetadata(
                assetIdentifier: asset.localIdentifier,
                latitude: location.coordinate.latitude,
                longitude: location.coordinate.longitude,
                captureDate: asset.creationDate ?? Date()
            )
            photoMetadataList.append(metadata)
        }

        // Convert StopEntities to TripCore Stop models for the matcher
        let coreStops = allStops.compactMap { stopEntity -> Stop? in
            guard stopEntity.latitude != 0 || stopEntity.longitude != 0 else { return nil }
            return Stop(
                id: stopEntity.id ?? UUID(),
                dayId: stopEntity.day?.id ?? UUID(),
                name: stopEntity.wrappedName,
                latitude: stopEntity.latitude,
                longitude: stopEntity.longitude,
                arrivalTime: stopEntity.arrivalTime,
                departureTime: stopEntity.departureTime,
                category: stopEntity.category,
                notes: stopEntity.wrappedNotes,
                sortOrder: Int(stopEntity.sortOrder)
            )
        }

        // Read user's preferred radius (stored in miles, default 1.0)
        let radiusMiles = UserDefaults.standard.double(forKey: "photoMatchRadiusMiles")
        let radiusMeters = (radiusMiles > 0 ? radiusMiles : 1.0) * 1609.34

        // Use TripCore's PhotoMatcher
        let matcher = PhotoMatcher(maxDistanceMeters: radiusMeters, maxTimeWindowSeconds: 7200)
        let allResults = matcher.matchPhotos(photoMetadataList, to: coreStops)

        // Filter to photos matched to THIS stop (high or medium confidence)
        let stopID = stop.id ?? UUID()
        let stopResults = allResults.filter { result in
            result.matchedStop?.id == stopID && result.confidence >= .medium
        }.sorted { $0.confidence > $1.confidence }

        await MainActor.run {
            matchedPhotos = stopResults
            isLoading = false
        }
    }

    // MARK: - Image Loading

    /// Load a thumbnail UIImage for a PHAsset identifier.
    func loadThumbnail(assetIdentifier: String, targetSize: CGSize, completion: @escaping (UIImage?) -> Void) {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = result.firstObject else {
            completion(nil)
            return
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .opportunistic

        imageManager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { image, _ in
            completion(image)
        }
    }

    /// Load a full-size UIImage for a PHAsset identifier.
    func loadFullImage(assetIdentifier: String, completion: @escaping (UIImage?) -> Void) {
        let result = PHAsset.fetchAssets(withLocalIdentifiers: [assetIdentifier], options: nil)
        guard let asset = result.firstObject else {
            completion(nil)
            return
        }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat

        imageManager.requestImage(
            for: asset,
            targetSize: PHImageManagerMaximumSize,
            contentMode: .aspectFit,
            options: options
        ) { image, _ in
            completion(image)
        }
    }
}
