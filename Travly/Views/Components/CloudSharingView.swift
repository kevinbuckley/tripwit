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
            // Persist the share locally so CloudKit knows about it.
            if let share = csc.share,
               let store = parent.persistence.privatePersistentStore {
                parent.persistence.container.persistUpdatedShare(share, in: store)
            }
            // Do NOT dismiss here. UICloudSharingController manages its own
            // presentation lifecycle (e.g. showing iMessage/Mail compose sheet).
            // Dismissing the SwiftUI wrapper now would rip away the presenter
            // while the share sheet is still on screen, causing an infinite spinner.
            // The host controller's presentationControllerDidDismiss or
            // viewWillDisappear handles the final SwiftUI cleanup.
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
            // Same as above — do NOT dismiss here.
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
    private var sharingControllerPresented = false

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
            finishPresenting(controller)
        } else {
            // Pre-create the share BEFORE presenting the controller so the
            // preparation handler never needs to await on the main thread.
            let tripRef = trip!
            let sharingRef = sharingService!
            let persistenceRef = persistence!

            // Show a temporary spinner while the share is being created
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
                    self.onDismiss?()
                }
            }
        }
    }

    private func finishPresenting(_ controller: UICloudSharingController) {
        controller.delegate = coordinator
        controller.availablePermissions = [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
        controller.modalPresentationStyle = .formSheet

        // Use ourselves as the presentation delegate so we know when the
        // UICloudSharingController is fully dismissed (including any
        // sub-sheets like iMessage or Mail it presents).
        controller.presentationController?.delegate = self

        sharingControllerPresented = true
        present(controller, animated: true)
    }

    // Called when UICloudSharingController is dismissed by the user
    // (swipe down, Cancel, or after sending the share via iMessage/Mail).
    // This is the ONLY place we dismiss the SwiftUI fullScreenCover.
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        sharingControllerPresented = false
        onDismiss?()
    }
}
