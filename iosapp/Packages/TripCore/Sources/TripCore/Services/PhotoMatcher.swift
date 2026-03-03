import Foundation

// MARK: - PhotoMetadata

public struct PhotoMetadata: Sendable {
    public let assetIdentifier: String
    public let latitude: Double
    public let longitude: Double
    public let captureDate: Date

    public init(
        assetIdentifier: String,
        latitude: Double,
        longitude: Double,
        captureDate: Date
    ) {
        self.assetIdentifier = assetIdentifier
        self.latitude = latitude
        self.longitude = longitude
        self.captureDate = captureDate
    }
}

// MARK: - PhotoMatchResult

public struct PhotoMatchResult: Sendable {
    public let photo: PhotoMetadata
    public let matchedStop: Stop?
    public let confidence: MatchConfidence
    public let distanceMeters: Double

    public init(
        photo: PhotoMetadata,
        matchedStop: Stop?,
        confidence: MatchConfidence,
        distanceMeters: Double
    ) {
        self.photo = photo
        self.matchedStop = matchedStop
        self.confidence = confidence
        self.distanceMeters = distanceMeters
    }
}

// MARK: - PhotoMatcher

public struct PhotoMatcher: Sendable {

    /// Maximum distance in meters for a high or medium confidence match.
    public let maxDistanceMeters: Double

    /// Maximum time window in seconds (applied to arrival/departure) for a high confidence match.
    public let maxTimeWindowSeconds: TimeInterval

    public init(
        maxDistanceMeters: Double = 200,
        maxTimeWindowSeconds: TimeInterval = 7200
    ) {
        self.maxDistanceMeters = maxDistanceMeters
        self.maxTimeWindowSeconds = maxTimeWindowSeconds
    }

    /// Match an array of photo metadata to the nearest stops using GPS distance and time windows.
    ///
    /// Matching logic per photo:
    /// 1. Find the nearest stop by Haversine distance.
    /// 2. If within `maxDistanceMeters` AND the photo capture time is within
    ///    `maxTimeWindowSeconds` of the stop's arrival or departure time, confidence is **high**.
    /// 3. If within `maxDistanceMeters` but outside the time window, confidence is **medium**.
    /// 4. If within `2 * maxDistanceMeters`, confidence is **low**.
    /// 5. Beyond that, the photo is unmatched (`matchedStop` is `nil`).
    public func matchPhotos(_ photos: [PhotoMetadata], to stops: [Stop]) -> [PhotoMatchResult] {
        photos.map { photo in
            matchSinglePhoto(photo, to: stops)
        }
    }

    // MARK: - Private

    private func matchSinglePhoto(_ photo: PhotoMetadata, to stops: [Stop]) -> PhotoMatchResult {
        guard !stops.isEmpty else {
            return PhotoMatchResult(
                photo: photo,
                matchedStop: nil,
                confidence: .low,
                distanceMeters: .infinity
            )
        }

        var nearestStop: Stop?
        var nearestDistance: Double = .infinity

        for stop in stops {
            let d = GeoUtils.distance(
                lat1: photo.latitude,
                lon1: photo.longitude,
                lat2: stop.latitude,
                lon2: stop.longitude
            )
            if d < nearestDistance {
                nearestDistance = d
                nearestStop = stop
            }
        }

        guard let matchedStop = nearestStop else {
            return PhotoMatchResult(
                photo: photo,
                matchedStop: nil,
                confidence: .low,
                distanceMeters: nearestDistance
            )
        }

        // Determine confidence based on distance and time window.
        if nearestDistance <= maxDistanceMeters {
            if isWithinTimeWindow(photo: photo, stop: matchedStop) {
                return PhotoMatchResult(
                    photo: photo,
                    matchedStop: matchedStop,
                    confidence: .high,
                    distanceMeters: nearestDistance
                )
            } else {
                return PhotoMatchResult(
                    photo: photo,
                    matchedStop: matchedStop,
                    confidence: .medium,
                    distanceMeters: nearestDistance
                )
            }
        } else if nearestDistance <= maxDistanceMeters * 2 {
            return PhotoMatchResult(
                photo: photo,
                matchedStop: matchedStop,
                confidence: .low,
                distanceMeters: nearestDistance
            )
        } else {
            return PhotoMatchResult(
                photo: photo,
                matchedStop: nil,
                confidence: .low,
                distanceMeters: nearestDistance
            )
        }
    }

    /// Returns `true` if the photo's capture date is within `maxTimeWindowSeconds` of the stop's
    /// arrival or departure time. If the stop has neither arrival nor departure time, returns
    /// `false` (we have no time information to compare against).
    private func isWithinTimeWindow(photo: PhotoMetadata, stop: Stop) -> Bool {
        let captureDate = photo.captureDate

        if let arrival = stop.arrivalTime {
            if abs(captureDate.timeIntervalSince(arrival)) <= maxTimeWindowSeconds {
                return true
            }
        }

        if let departure = stop.departureTime {
            if abs(captureDate.timeIntervalSince(departure)) <= maxTimeWindowSeconds {
                return true
            }
        }

        // If the stop has at least one time set but neither matched, it's outside the window.
        // If neither time is set, we cannot determine a time window, so we return false.
        return false
    }
}
