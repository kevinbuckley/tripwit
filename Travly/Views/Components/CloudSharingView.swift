import SwiftUI
import CloudKit
import CoreData

/// Wraps `UICloudSharingController` for SwiftUI presentation.
/// Uses a UIKit host controller to present the sharing UI directly,
/// avoiding the SwiftUI UIViewControllerRepresentable issues with the
/// preparationHandler-based initializer.
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

    // MARK: - Coordinator (UICloudSharingControllerDelegate)

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
            // Persist the share locally so Core Data stays in sync.
            if let share = csc.share,
               let store = parent.persistence.privatePersistentStore {
                parent.persistence.container.persistUpdatedShare(share, in: store)
            }
            // Do NOT dismiss here — UICloudSharingController may still be
            // presenting sub-sheets (iMessage, Mail). The host controller's
            // viewDidAppear catches the final dismissal.
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

/// A UIKit view controller that presents UICloudSharingController.
///
/// KEY DESIGN DECISIONS:
///
/// 1. For NEW shares: Uses UICloudSharingController(preparationHandler:)
///    The preparationHandler init tells the controller to coordinate the
///    CloudKit server upload itself. Inside the handler, we call
///    container.share(_:to:completion:) — the COMPLETION HANDLER version
///    (not async/await) to avoid main-thread deadlock. The controller
///    waits for the completion block before showing iMessage/Mail.
///
/// 2. For EXISTING shares: Uses UICloudSharingController(share:container:)
///    The share is already on the server, so no preparation needed.
///
/// 3. Dismissal: Uses viewDidAppear (for programmatic dismiss) and
///    presentationControllerDidDismiss (for interactive swipe), both
///    funneling through idempotent dismissIfNeeded().
class CloudSharingHostController: UIViewController, UIAdaptivePresentationControllerDelegate {

    var trip: TripEntity!
    var persistence: PersistenceController!
    var sharingService: CloudKitSharingService!
    var coordinator: CloudSharingView.Coordinator!
    var onDismiss: (() -> Void)?

    private var didPresent = false
    private var isDismissing = false

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !didPresent {
            didPresent = true
            presentSharingController()
        } else {
            // The sharing controller was dismissed (programmatically or by user).
            dismissIfNeeded()
        }
    }

    private func presentSharingController() {
        let controller: UICloudSharingController

        if let existingShare = sharingService.existingShare(for: trip) {
            // EXISTING SHARE: Already on the CloudKit server.
            controller = UICloudSharingController(
                share: existingShare,
                container: persistence.cloudContainer
            )
        } else {
            // NEW SHARE: Use the preparationHandler initializer.
            // This is critical — the preparationHandler version coordinates
            // the server-side share creation. The init(share:container:)
            // version assumes the share URL already exists on the server,
            // which causes iMessage to spin forever waiting for it.
            let container = persistence.container
            let cloudContainer = persistence.cloudContainer
            let tripToShare = trip!

            controller = UICloudSharingController { sharingController, preparationCompletionHandler in
                // Use the COMPLETION HANDLER version of container.share()
                // (NOT async/await) to avoid main-thread deadlock.
                // This runs the actual CloudKit upload on a background queue
                // and calls our completion when the server-side share is ready.
                container.share([tripToShare], to: nil) { _, share, ckContainer, error in
                    if let share {
                        share[CKShare.SystemFieldKey.title] = tripToShare.wrappedName
                    }
                    // Tell UICloudSharingController the share is ready.
                    // It will now show iMessage/Mail with the share URL.
                    preparationCompletionHandler(share, ckContainer, error)
                }
            }
        }

        controller.delegate = coordinator
        controller.availablePermissions = [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
        controller.modalPresentationStyle = .formSheet
        controller.presentationController?.delegate = self

        present(controller, animated: true)
    }

    /// Idempotent: dismiss the SwiftUI fullScreenCover exactly once.
    private func dismissIfNeeded() {
        guard !isDismissing else { return }
        isDismissing = true
        onDismiss?()
    }

    // MARK: - UIAdaptivePresentationControllerDelegate

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        dismissIfNeeded()
    }
}
