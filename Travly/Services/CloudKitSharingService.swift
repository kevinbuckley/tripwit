import CoreData
import CloudKit

/// Manages CloudKit sharing operations for trips.
final class CloudKitSharingService {

    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
    }

    // MARK: - Query

    /// Whether this trip is in the shared CloudKit database.
    func isShared(_ trip: TripEntity) -> Bool {
        persistence.isShared(trip)
    }

    /// Whether the current user is a participant (not the owner).
    func isParticipant(_ trip: TripEntity) -> Bool {
        persistence.isParticipant(trip)
    }

    /// Whether the current user can edit this trip.
    func canEdit(_ trip: TripEntity) -> Bool {
        persistence.canEdit(trip)
    }

    /// Get the existing CKShare for a trip, if any.
    func existingShare(for trip: TripEntity) -> CKShare? {
        persistence.existingShare(for: trip)
    }

    /// The owner's display name for a shared trip.
    func ownerName(for trip: TripEntity) -> String? {
        guard let share = existingShare(for: trip) else { return nil }
        return share.owner.userIdentity.nameComponents.flatMap {
            PersonNameComponentsFormatter.localizedString(from: $0, style: .default)
        }
    }

    /// Participant count for a shared trip (including owner).
    func participantCount(for trip: TripEntity) -> Int {
        guard let share = existingShare(for: trip) else { return 1 }
        return share.participants.count
    }

    // MARK: - Share

    /// Create or get existing CKShare for a trip (used by UICloudSharingController).
    func shareTrip(_ trip: TripEntity) async throws -> CKShare {
        if let existing = existingShare(for: trip) {
            return existing
        }

        // Use NSPersistentCloudKitContainer's built-in share method
        let (_, share, _) = try await persistence.container.share(
            [trip],
            to: nil
        )
        return share
    }

    /// Persist an updated share after UICloudSharingController changes.
    // FIX #5: Safe unwrap instead of force-unwrap
    func persistUpdatedShare(_ share: CKShare) {
        guard let store = persistence.privatePersistentStore else {
            print("Warning: Private store not available to persist share")
            return
        }
        persistence.container.persistUpdatedShare(share, in: store)
    }

    // MARK: - Accept

    /// Accept a CloudKit share metadata (called when user opens a share link).
    // FIX #5: Safe unwrap instead of force-unwrap
    func acceptShare(_ metadata: CKShare.Metadata) async throws {
        guard let store = persistence.sharedPersistentStore else {
            print("Warning: Shared store not available to accept share")
            return
        }
        try await persistence.container.acceptShareInvitations(
            from: [metadata],
            into: store
        )
    }
}
