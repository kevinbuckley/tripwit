import SwiftUI
import CloudKit
import CoreData
import MessageUI
import os.log

private let shareLog = Logger(subsystem: "com.kevinbuckley.travelplanner", category: "Sharing")

// MARK: - Sharing Presenter

/// Handles CloudKit sharing for trips.
///
/// For NEW shares: Pre-creates the CKShare, then shows a custom share sheet
/// that uses MFMessageComposeViewController for Messages (bypassing UICloudSharingController
/// which has a documented iOS spinner bug when used with Messages).
///
/// For EXISTING shares: Uses UICloudSharingController for managing
/// participants, permissions, and stopping sharing.
enum CloudSharingPresenter {

    static func present(
        trip: TripEntity,
        persistence: PersistenceController,
        sharingService: CloudKitSharingService
    ) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            shareLog.error("[SHARE] No window scene or root VC found")
            return
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        if let existingShare = sharingService.existingShare(for: trip) {
            shareLog.info("[SHARE] Presenting UICloudSharingController for EXISTING share")
            presentSharingController(
                share: existingShare,
                container: persistence.cloudContainer,
                persistence: persistence,
                from: topVC
            )
        } else {
            shareLog.info("[SHARE] Creating NEW share, then presenting custom share sheet")
            createAndPresentCustomSheet(
                trip: trip,
                persistence: persistence,
                from: topVC
            )
        }
    }

    // MARK: - New Share: Pre-create then show custom share sheet

    /// Pre-creates the CKShare, wraps the URL in the tripwit:// scheme,
    /// then shows a custom UIAlertController action sheet with:
    ///   • Message  — opens MFMessageComposeViewController directly (no spinner)
    ///   • Copy Link — copies wrapped URL to clipboard
    ///   • More...  — UIActivityViewController for AirDrop, Mail, etc.
    private static func createAndPresentCustomSheet(
        trip: TripEntity,
        persistence: PersistenceController,
        from presenter: UIViewController
    ) {
        let tripName = trip.wrappedName

        if let ctx = trip.managedObjectContext, ctx.hasChanges {
            try? ctx.save()
        }

        // Loading indicator
        let loadingAlert = UIAlertController(
            title: nil,
            message: "Preparing collaboration...",
            preferredStyle: .alert
        )
        let spinner = UIActivityIndicatorView(style: .medium)
        spinner.translatesAutoresizingMaskIntoConstraints = false
        spinner.startAnimating()
        loadingAlert.view.addSubview(spinner)
        NSLayoutConstraint.activate([
            spinner.centerYAnchor.constraint(equalTo: loadingAlert.view.centerYAnchor),
            spinner.leadingAnchor.constraint(equalTo: loadingAlert.view.leadingAnchor, constant: 20),
            loadingAlert.view.heightAnchor.constraint(greaterThanOrEqualToConstant: 80)
        ])
        presenter.present(loadingAlert, animated: true)

        Task { @MainActor in
            var lastError: Error?

            for attempt in 0..<3 {
                if attempt > 0 {
                    let delay = 2 * attempt
                    loadingAlert.message = "Waiting for sync... (attempt \(attempt + 1)/3)"
                    try? await Task.sleep(for: .seconds(delay))
                }

                do {
                    let (_, share, _) = try await persistence.container.share([trip], to: nil)
                    shareLog.info("[SHARE] container.share() succeeded (attempt \(attempt + 1))")

                    share[CKShare.SystemFieldKey.title] = tripName
                    share.publicPermission = .readWrite

                    if let store = persistence.privatePersistentStore {
                        try await persistence.container.persistUpdatedShare(share, in: store)
                    }

                    guard let shareURL = share.url else {
                        loadingAlert.dismiss(animated: true) {
                            showError(NSError(domain: "TripWit", code: -2,
                                userInfo: [NSLocalizedDescriptionKey: "Share created but has no link. Please try again."]),
                                from: presenter)
                        }
                        return
                    }

                    shareLog.info("[SHARE] Share URL: \(shareURL.absoluteString)")

                    // Wrap in tripwit:// scheme — prevents Messages from detecting
                    // it as a CloudKit collaboration URL (which causes the spinner)
                    let encoded = shareURL.absoluteString
                        .addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? shareURL.absoluteString
                    let wrappedURLString = "tripwit://share?url=\(encoded)"
                    let shareText = "Join my trip \"\(tripName)\" on TripWit!\n\(wrappedURLString)"

                    loadingAlert.dismiss(animated: true) {
                        presentCustomShareSheet(
                            tripName: tripName,
                            shareText: shareText,
                            wrappedURLString: wrappedURLString,
                            from: presenter
                        )
                    }
                    return

                } catch {
                    lastError = error
                    let nsError = error as NSError
                    shareLog.error("[SHARE] Attempt \(attempt + 1) failed: \(nsError.domain) \(nsError.code) — \(error.localizedDescription)")
                    let isRetryable = nsError.domain == "CKErrorDomain" &&
                        (nsError.code == 10 || nsError.code == 1 || nsError.code == 7)
                    if !isRetryable { break }
                }
            }

            loadingAlert.dismiss(animated: true) {
                showError(lastError ?? NSError(domain: "TripWit", code: -1,
                    userInfo: [NSLocalizedDescriptionKey: "Failed to create share. Please try again in a moment."]),
                    from: presenter)
            }
        }
    }

    /// Shows a custom action sheet with Message, Copy Link, and More options.
    @MainActor
    private static func presentCustomShareSheet(
        tripName: String,
        shareText: String,
        wrappedURLString: String,
        from presenter: UIViewController
    ) {
        let sheet = UIAlertController(
            title: "Invite to \"\(tripName)\"",
            message: "Collaborators can view and edit this trip in real time.",
            preferredStyle: .actionSheet
        )

        // Message — uses MFMessageComposeViewController directly, no UICloudSharingController
        if MFMessageComposeViewController.canSendText() {
            sheet.addAction(UIAlertAction(title: "Message", style: .default) { _ in
                let composer = MFMessageComposeViewController()
                composer.body = shareText
                let delegate = MessageDelegate()
                composer.messageComposeDelegate = delegate
                objc_setAssociatedObject(composer, &MessageDelegate.key, delegate, .OBJC_ASSOCIATION_RETAIN)
                presenter.present(composer, animated: true)
            })
        }

        // Copy Link
        sheet.addAction(UIAlertAction(title: "Copy Link", style: .default) { _ in
            UIPasteboard.general.string = wrappedURLString
            // Brief confirmation toast
            let toast = UIAlertController(title: nil, message: "Link copied!", preferredStyle: .alert)
            presenter.present(toast, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                toast.dismiss(animated: true)
            }
        })

        // More... — standard share sheet for AirDrop, Mail, etc.
        sheet.addAction(UIAlertAction(title: "More...", style: .default) { _ in
            let activityVC = UIActivityViewController(
                activityItems: [shareText as NSString],
                applicationActivities: nil
            )
            // Exclude Messages from the generic share sheet — it spinners
            activityVC.excludedActivityTypes = [.message]
            activityVC.modalPresentationStyle = .formSheet
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                           y: presenter.view.bounds.midY, width: 0, height: 0)
            }
            presenter.present(activityVC, animated: true)
        })

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                       y: presenter.view.bounds.midY, width: 0, height: 0)
        }

        presenter.present(sheet, animated: true)
    }

    // MARK: - Existing Share: UICloudSharingController for management

    static func presentSharingController(
        share: CKShare,
        container: CKContainer,
        persistence: PersistenceController,
        from presenter: UIViewController
    ) {
        let delegate = SharingDelegate(persistence: persistence)
        let controller = UICloudSharingController(share: share, container: container)
        controller.delegate = delegate
        controller.availablePermissions = [.allowPublic, .allowPrivate, .allowReadOnly, .allowReadWrite]
        controller.modalPresentationStyle = .formSheet
        objc_setAssociatedObject(controller, &SharingDelegate.associatedKey, delegate, .OBJC_ASSOCIATION_RETAIN)
        shareLog.info("[SHARE] Presenting UICloudSharingController for share management")
        presenter.present(controller, animated: true)
    }

    @MainActor private static func showError(_ error: Error, from presenter: UIViewController) {
        let alert = UIAlertController(title: "Sharing Failed", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(alert, animated: true)
    }
}

// MARK: - Message Delegate

private class MessageDelegate: NSObject, MFMessageComposeViewControllerDelegate {
    static var key: UInt8 = 0

    func messageComposeViewController(
        _ controller: MFMessageComposeViewController,
        didFinishWith result: MessageComposeResult
    ) {
        controller.dismiss(animated: true)
    }
}

// MARK: - Sharing Delegate

private class SharingDelegate: NSObject, UICloudSharingControllerDelegate {

    static var associatedKey: UInt8 = 0
    let persistence: PersistenceController

    init(persistence: PersistenceController) {
        self.persistence = persistence
    }

    func cloudSharingController(_ csc: UICloudSharingController, failedToSaveShareWithError error: Error) {
        shareLog.error("[SHARE] failedToSaveShareWithError: \(error.localizedDescription)")
    }

    func cloudSharingControllerDidSaveShare(_ csc: UICloudSharingController) {
        shareLog.info("[SHARE] didSaveShare")
        if let share = csc.share, let store = persistence.privatePersistentStore {
            persistence.container.persistUpdatedShare(share, in: store)
        }
    }

    func cloudSharingControllerDidStopSharing(_ csc: UICloudSharingController) {
        shareLog.info("[SHARE] didStopSharing")
        if let share = csc.share, let store = persistence.privatePersistentStore {
            persistence.container.purgeObjectsAndRecordsInZone(
                with: share.recordID.zoneID, in: store
            ) { _, error in
                if let error { shareLog.error("[SHARE] purge error: \(error.localizedDescription)") }
            }
        }
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        csc.share?.value(forKey: CKShare.SystemFieldKey.title) as? String
    }

    func itemThumbnailData(for csc: UICloudSharingController) -> Data? { nil }
}
