import Foundation

// MARK: - MatchConfidence

public enum MatchConfidence: String, Codable, Hashable, Sendable, CaseIterable, Comparable {
    case high
    case medium
    case low

    private var sortIndex: Int {
        switch self {
        case .high: return 2
        case .medium: return 1
        case .low: return 0
        }
    }

    public static func < (lhs: MatchConfidence, rhs: MatchConfidence) -> Bool {
        lhs.sortIndex < rhs.sortIndex
    }
}

// MARK: - MatchedPhoto

public struct MatchedPhoto: Codable, Identifiable, Hashable, Sendable {

    // MARK: Stored Properties

    public var id: UUID
    public var assetIdentifier: String
    public var latitude: Double
    public var longitude: Double
    public var captureDate: Date
    public var matchConfidence: MatchConfidence
    public var matchedStopId: UUID?
    public var isManuallyAssigned: Bool

    // MARK: Initializer

    public init(
        id: UUID = UUID(),
        assetIdentifier: String,
        latitude: Double,
        longitude: Double,
        captureDate: Date,
        matchConfidence: MatchConfidence,
        matchedStopId: UUID? = nil,
        isManuallyAssigned: Bool = false
    ) {
        self.id = id
        self.assetIdentifier = assetIdentifier
        self.latitude = latitude
        self.longitude = longitude
        self.captureDate = captureDate
        self.matchConfidence = matchConfidence
        self.matchedStopId = matchedStopId
        self.isManuallyAssigned = isManuallyAssigned
    }
}
