import SwiftUI
import CloudKit
import CoreData

/// Wraps `UICloudSharingController` for SwiftUI presentation.
/// Uses a transparent hosting controller to present the sharing UI
/// directly from UIKit, avoiding the empty-sheet SwiftUI issue.
struct CloudSharingView: UIViewControllerRepresentable {

    let trip: TripEntity
    let persistence: PersistenceController
    let sharingService: CloudKitSharingService

    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> CloudSharingHostController {
        let host = CloudSharingHostController()
        host.trip = trip
        host.persistence = persistence
        host.sharingService = sharingService
        host.coordinator = context.coordinator
        host.onDismiss = { dismiss() }
        return host
    }

    func updateUIViewController(_ uiViewController: CloudSharingHostController, context: Context) {}

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
            parent.dismiss()
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
            parent.dismiss()
        }

        func itemTitle(for csc: UICloudSharingController) -> String? {
            parent.trip.wrappedName
        }

        func itemThumbnailData(for csc: UICloudSharingController) -> Data? {
            nil
        }
    }
}

// MARK: - Clear Background

/// Removes the default opaque background from a fullScreenCover
/// so the UICloudSharingController appears without a blank backdrop.
struct ClearBackgroundView: UIViewRepresentable {
    func makeUIView(context: Context) -> UIView {
        let view = UIView()
        DispatchQueue.main.async {
            view.superview?.superview?.backgroundColor = .clear
        }
        return view
    }
    func updateUIView(_ uiView: UIView, context: Context) {}
}

// MARK: - Host Controller

/// A transparent view controller that presents UICloudSharingController
/// directly via UIKit to avoid SwiftUI sheet rendering issues.
class CloudSharingHostController: UIViewController, UIAdaptivePresentationControllerDelegate {

    var trip: TripEntity!
    var persistence: PersistenceController!
    var sharingService: CloudKitSharingService!
    var coordinator: CloudSharingView.Coordinator!
    var onDismiss: (() -> Void)?

    private var didPresent = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        guard !didPresent else { return }
        didPresent = true
        presentSharingController()
    }

    private func presentSharingController() {
        let controller: UICloudSharingController

        if let existingShare = sharingService.existingShare(for: trip) {
            controller = UICloudSharingController(share: existingShare, container: persistence.cloudContainer)
        } else {
            controller = UICloudSharingController { [weak self] _, prepareHandler in
                guard let self else { return }
                Task {
                    do {
                        let share = try await self.sharingService.shareTrip(self.trip)
                        share[CKShare.SystemFieldKey.title] = self.trip.wrappedName
                        prepareHandler(share, self.persistence.cloudContainer, nil)
                    } catch {
                        prepareHandler(nil, nil, error)
                    }
                }
            }
        }

        controller.delegate = coordinator
        controller.availablePermissions = [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
        controller.modalPresentationStyle = .formSheet
        controller.presentationController?.delegate = self

        present(controller, animated: true)
    }

    // Called when user swipes down or taps Cancel on the UICloudSharingController
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        onDismiss?()
    }
}
