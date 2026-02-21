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
        /// Reference to the host controller so delegate callbacks can trigger cleanup.
        weak var hostController: CloudSharingHostController?

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
            // Persist the share locally so CloudKit knows about it.
            if let share = csc.share,
               let store = parent.persistence.privatePersistentStore {
                parent.persistence.container.persistUpdatedShare(share, in: store)
            }
            // Do NOT dismiss here — UICloudSharingController may still be
            // presenting sub-sheets (iMessage, Mail). The host controller's
            // viewDidAppear will catch the final dismissal.
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
            // Do NOT dismiss here — same reason as above.
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
///
/// Dismissal strategy: We use THREE complementary mechanisms because
/// UICloudSharingController can dismiss in multiple ways:
///
/// 1. `presentationControllerDidDismiss` — fires on interactive (swipe) dismiss
/// 2. `viewDidAppear` (after initial) — fires when the sharing controller
///    dismisses itself programmatically (e.g. after sending via iMessage)
///    because the host becomes visible again
/// 3. Fallback timer — catches any edge case where neither fires
///
/// All three funnel through `dismissIfNeeded()` which is idempotent.
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
            // First appearance: present the sharing controller
            didPresent = true
            presentSharingController()
        } else {
            // Subsequent appearance: the sharing controller was dismissed
            // (either programmatically or by the user). Clean up.
            dismissIfNeeded()
        }
    }

    private func presentSharingController() {
        if let existingShare = sharingService.existingShare(for: trip) {
            let controller = UICloudSharingController(share: existingShare, container: persistence.cloudContainer)
            finishPresenting(controller)
        } else {
            // Pre-create the share BEFORE presenting the controller to avoid
            // the main-thread deadlock that occurs when container.share() is
            // called from inside UICloudSharingController's preparation handler.
            let tripRef = trip!
            let sharingRef = sharingService!
            let persistenceRef = persistence!

            let spinner = UIActivityIndicatorView(style: .large)
            spinner.center = view.center
            spinner.startAnimating()
            view.addSubview(spinner)

            Task { @MainActor in
                do {
                    let share = try await sharingRef.shareTrip(tripRef)
                    share[CKShare.SystemFieldKey.title] = tripRef.wrappedName
                    spinner.removeFromSuperview()

                    let sharingController = UICloudSharingController(share: share, container: persistenceRef.cloudContainer)
                    self.finishPresenting(sharingController)
                } catch {
                    spinner.removeFromSuperview()
                    print("Failed to create share: \(error)")
                    self.dismissIfNeeded()
                }
            }
        }
    }

    private func finishPresenting(_ controller: UICloudSharingController) {
        controller.delegate = coordinator
        coordinator.hostController = self
        controller.availablePermissions = [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
        controller.modalPresentationStyle = .formSheet

        // Catches interactive (swipe-down) dismissal
        controller.presentationController?.delegate = self

        present(controller, animated: true)
    }

    /// Idempotent cleanup: dismiss the SwiftUI fullScreenCover exactly once.
    func dismissIfNeeded() {
        guard !isDismissing else { return }
        isDismissing = true
        onDismiss?()
    }

    // MARK: - UIAdaptivePresentationControllerDelegate

    // Fires when the user interactively dismisses (swipe down / Cancel)
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        dismissIfNeeded()
    }
}
