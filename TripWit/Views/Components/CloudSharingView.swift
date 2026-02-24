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
/// For EXISTING shares: Shows a custom action sheet for inviting new people
/// (using the same wrapped tripwit:// URL to avoid the iMessage spinner),
/// plus a "Manage Sharing" option that opens UICloudSharingController
/// only for permissions and stop-sharing (not for adding people).
enum CloudSharingPresenter {

    @MainActor static func present(
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
            if existingShare.url != nil {
                shareLog.info("[SHARE] Presenting custom sheet for EXISTING share (avoids iMessage spinner)")
                presentExistingShareSheet(
                    trip: trip,
                    share: existingShare,
                    persistence: persistence,
                    from: topVC
                )
            } else {
                // Share exists but has no URL — stale or failed to sync.
                // Purge it and create a fresh one.
                shareLog.warning("[SHARE] Existing share has no URL — purging stale share and recreating")
                purgeStaleShareAndRecreate(
                    trip: trip,
                    share: existingShare,
                    persistence: persistence,
                    from: topVC
                )
            }
        } else {
            shareLog.info("[SHARE] Creating NEW share, then presenting custom share sheet")
            createAndPresentCustomSheet(
                trip: trip,
                persistence: persistence,
                from: topVC
            )
        }
    }

    // MARK: - Stale Share Recovery

    /// The existing CKShare has no URL (server never assigned one). This happens when:
    ///   • A share was created before the CloudKit schema was deployed to production
    ///   • A transient network failure prevented the server from finalizing the share
    /// Fix: purge the stale share zone and start fresh.
    @MainActor private static func purgeStaleShareAndRecreate(
        trip: TripEntity,
        share: CKShare,
        persistence: PersistenceController,
        from presenter: UIViewController
    ) {
        Task { @MainActor in
            do {
                // Remove the broken share from the persistent store
                if let store = persistence.privatePersistentStore {
                    try await persistence.container.purgeObjectsAndRecordsInZone(
                        with: share.recordID.zoneID,
                        in: store
                    )
                    shareLog.info("[SHARE] Purged stale share zone \(share.recordID.zoneID.zoneName)")
                    // Refresh so Core Data sees the share is gone
                    persistence.viewContext.refreshAllObjects()
                }
            } catch {
                shareLog.error("[SHARE] Failed to purge stale share: \(error.localizedDescription)")
            }

            // Now create a fresh share
            createAndPresentCustomSheet(
                trip: trip,
                persistence: persistence,
                from: presenter
            )
        }
    }

    // MARK: - New Share: Pre-create then show custom share sheet

    /// Pre-creates the CKShare, wraps the URL in the tripwit:// scheme,
    /// then shows a custom UIAlertController action sheet with:
    ///   • Message  — opens MFMessageComposeViewController directly (no spinner)
    ///   • Copy Link — copies wrapped URL to clipboard
    ///   • More...  — UIActivityViewController for AirDrop, Mail, etc.
    @MainActor private static func createAndPresentCustomSheet(
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

                    // The share URL may not be available immediately — wait briefly for
                    // CloudKit to assign it, then check again from the persistent store.
                    var shareURL = share.url
                    if shareURL == nil {
                        shareLog.info("[SHARE] Share URL nil after create, waiting for server...")
                        try? await Task.sleep(for: .seconds(2))
                        // Re-fetch the share from the store in case the URL arrived
                        if let store = persistence.privatePersistentStore {
                            let shares = try? persistence.container.fetchShares(in: store)
                            shareURL = shares?.last?.url
                        }
                    }

                    guard let finalURL = shareURL else {
                        shareLog.error("[SHARE] Share still has no URL after waiting")
                        // Treat as retryable — don't return, let the retry loop continue
                        lastError = NSError(domain: "TripWit", code: -2,
                            userInfo: [NSLocalizedDescriptionKey: "Share created but has no link. Please try again in a moment."])
                        continue
                    }

                    shareLog.info("[SHARE] Share URL: \(finalURL.absoluteString)")

                    // Verify the share is actually on CloudKit servers before
                    // presenting the link. The local store has the URL but the
                    // CKShare record may not have been exported yet.
                    loadingAlert.message = "Syncing share to iCloud..."
                    var shareIsLive = false
                    for verifyAttempt in 1...8 {
                        do {
                            try await verifyShareOnServer(url: finalURL, container: persistence.cloudContainer)
                            shareLog.info("[SHARE] Share verified on server (attempt \(verifyAttempt))")
                            shareIsLive = true
                            break
                        } catch {
                            shareLog.info("[SHARE] Share not yet on server (attempt \(verifyAttempt)/8): \(error.localizedDescription)")
                            if verifyAttempt < 8 {
                                loadingAlert.message = "Waiting for iCloud sync... (\(verifyAttempt)/8)"
                                try? await Task.sleep(for: .seconds(3))
                            }
                        }
                    }

                    guard shareIsLive else {
                        shareLog.error("[SHARE] Share never appeared on server after 24s")
                        loadingAlert.dismiss(animated: true) {
                            showError(NSError(domain: "TripWit", code: -4,
                                userInfo: [NSLocalizedDescriptionKey: "The share was created but couldn't sync to iCloud. Check your internet connection and try again."]),
                                from: presenter)
                        }
                        return
                    }

                    // Wrap in tripwit:// scheme — prevents Messages from detecting
                    // it as a CloudKit collaboration URL (which causes the spinner).
                    // Use strict encoding: urlQueryAllowed minus '#' and '&' which would
                    // break the wrapper URL (# starts a fragment, & starts next param).
                    var allowedChars = CharacterSet.urlQueryAllowed
                    allowedChars.remove(charactersIn: "#&")
                    let encoded = finalURL.absoluteString
                        .addingPercentEncoding(withAllowedCharacters: allowedChars) ?? finalURL.absoluteString
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

    // MARK: - Existing Share: Custom sheet to invite + manage

    /// For trips that are already shared, show our own action sheet for inviting
    /// new people (using the wrapped tripwit:// URL to avoid the iMessage spinner),
    /// plus a "Manage Sharing" option for permissions/stop sharing via UICloudSharingController.
    @MainActor
    private static func presentExistingShareSheet(
        trip: TripEntity,
        share: CKShare,
        persistence: PersistenceController,
        from presenter: UIViewController
    ) {
        let tripName = trip.wrappedName
        let participantCount = share.participants.count

        guard let shareURL = share.url else {
            shareLog.error("[SHARE] Existing share has no URL")
            showError(NSError(domain: "TripWit", code: -3,
                userInfo: [NSLocalizedDescriptionKey: "Share link not available. Try again later."]),
                from: presenter)
            return
        }

        var allowedChars = CharacterSet.urlQueryAllowed
        allowedChars.remove(charactersIn: "#&")
        let encoded = shareURL.absoluteString
            .addingPercentEncoding(withAllowedCharacters: allowedChars) ?? shareURL.absoluteString
        let wrappedURLString = "tripwit://share?url=\(encoded)"
        let shareText = "Join my trip \"\(tripName)\" on TripWit!\n\(wrappedURLString)"

        let sheet = UIAlertController(
            title: "Sharing \"\(tripName)\"",
            message: "\(participantCount) participant\(participantCount == 1 ? "" : "s") · Tap Invite to add more people.",
            preferredStyle: .actionSheet
        )

        // Invite via Message
        if MFMessageComposeViewController.canSendText() {
            sheet.addAction(UIAlertAction(title: "Invite via Message", style: .default) { _ in
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
            let toast = UIAlertController(title: nil, message: "Link copied!", preferredStyle: .alert)
            presenter.present(toast, animated: true)
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.2) {
                toast.dismiss(animated: true)
            }
        })

        // More invite options (AirDrop, Mail, etc.)
        sheet.addAction(UIAlertAction(title: "Invite via Other...", style: .default) { _ in
            let activityVC = UIActivityViewController(
                activityItems: [shareText as NSString],
                applicationActivities: nil
            )
            activityVC.excludedActivityTypes = [.message]
            activityVC.modalPresentationStyle = .formSheet
            if let popover = activityVC.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                           y: presenter.view.bounds.midY, width: 0, height: 0)
            }
            presenter.present(activityVC, animated: true)
        })

        // Manage Sharing — UICloudSharingController for permissions and stop sharing
        sheet.addAction(UIAlertAction(title: "Manage Sharing...", style: .default) { _ in
            presentSharingController(
                share: share,
                container: persistence.cloudContainer,
                persistence: persistence,
                from: presenter
            )
        })

        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popover = sheet.popoverPresentationController {
            popover.sourceView = presenter.view
            popover.sourceRect = CGRect(x: presenter.view.bounds.midX,
                                       y: presenter.view.bounds.midY, width: 0, height: 0)
        }

        presenter.present(sheet, animated: true)
    }

    // MARK: - UICloudSharingController (permissions & stop sharing only)

    @MainActor static func presentSharingController(
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

    /// Verify a share URL is resolvable on CloudKit servers.
    /// Throws if the share can't be found (not yet exported).
    private static func verifyShareOnServer(url: URL, container: CKContainer) async throws {
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let operation = CKFetchShareMetadataOperation(shareURLs: [url])
            operation.shouldFetchRootRecord = false  // We only need to know it exists

            var perShareError: Error?

            operation.perShareMetadataResultBlock = { _, result in
                switch result {
                case .success:
                    break  // Share exists on server
                case .failure(let error):
                    perShareError = error
                }
            }

            operation.fetchShareMetadataResultBlock = { result in
                switch result {
                case .success:
                    if let error = perShareError {
                        continuation.resume(throwing: error)
                    } else {
                        continuation.resume()
                    }
                case .failure(let error):
                    continuation.resume(throwing: error)
                }
            }

            container.add(operation)
        }
    }

    @MainActor private static func showError(_ error: Error, from presenter: UIViewController) {
        let alert = UIAlertController(title: "Sharing Failed", message: error.localizedDescription, preferredStyle: .alert)
        alert.addAction(UIAlertAction(title: "OK", style: .default))
        presenter.present(alert, animated: true)
    }
}

// MARK: - Message Delegate

private class MessageDelegate: NSObject, @preconcurrency MFMessageComposeViewControllerDelegate {
    nonisolated(unsafe) static var key: UInt8 = 0

    @MainActor func messageComposeViewController(
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
                if let error {
                    shareLog.error("[SHARE] purge error: \(error.localizedDescription)")
                }
                // Refresh the viewContext so views stop referencing deleted objects
                DispatchQueue.main.async {
                    self.persistence.viewContext.refreshAllObjects()
                }
            }
        }
    }

    func itemTitle(for csc: UICloudSharingController) -> String? {
        csc.share?.value(forKey: CKShare.SystemFieldKey.title) as? String
    }

    func itemThumbnailData(for csc: UICloudSharingController) -> Data? { nil }
}
