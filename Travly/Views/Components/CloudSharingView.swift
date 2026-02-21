import SwiftUI
import CloudKit
import CoreData

/// Wraps `UICloudSharingController` for SwiftUI presentation.
struct CloudSharingView: UIViewControllerRepresentable {

    let trip: TripEntity
    let persistence: PersistenceController
    let sharingService: CloudKitSharingService

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UICloudSharingController {
        let controller: UICloudSharingController

        if let existingShare = sharingService.existingShare(for: trip) {
            // Already shared — manage participants
            controller = UICloudSharingController(share: existingShare, container: persistence.cloudContainer)
        } else {
            // New share — create one
            controller = UICloudSharingController { _, prepareHandler in
                Task {
                    do {
                        let share = try await sharingService.shareTrip(trip)
                        share[CKShare.SystemFieldKey.title] = trip.wrappedName
                        prepareHandler(share, persistence.cloudContainer, nil)
                    } catch {
                        prepareHandler(nil, nil, error)
                    }
                }
            }
        }

        controller.delegate = context.coordinator
        controller.availablePermissions = [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
        return controller
    }

    func updateUIViewController(_ uiViewController: UICloudSharingController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    // MARK: - Coordinator

    class Coordinator: NSObject, UICloudSharingControllerDelegate {

        let parent: CloudSharingView

        init(_ parent: CloudSharingView) {
            self.parent = parent
        }

        func cloudSharingController(
            _ csc: UICloudSharingController,
            failedToSaveShareWithError error: Error
        ) {
            print("CloudKit sharing error: \(error)")
        }

        func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
            if let share = csc.share,
               let store = parent.persistence.privatePersistentStore {
                parent.persistence.container.persistUpdatedShare(share, in: store)
            }
        }

        func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
            if let share = csc.share,
               let store = parent.persistence.privatePersistentStore {
                parent.persistence.container.purgeObjectsAndRecordsInZone(
                    with: share.recordID.zoneID,
                    in: store
                ) { _, error in
                    if let error {
                        print("Failed to purge shared data: \(error)")
                    }
                }
            }
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            parent.trip.wrappedName
        }

        func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
            nil
        }
    }
}
