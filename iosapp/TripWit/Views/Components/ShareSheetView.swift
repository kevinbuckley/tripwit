import SwiftUI
import UIKit
import UniformTypeIdentifiers
import LinkPresentation

/// Helper to present UIActivityViewController from SwiftUI.
/// UIActivityViewController cannot be wrapped in UIViewControllerRepresentable inside a .sheet().
/// Instead, we present it directly on the root view controller.
enum ShareSheet {

    @MainActor static func share(pdfData: Data, filename: String) {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
        try? pdfData.write(to: tempURL)
        presentActivity(items: [tempURL])
    }

    @MainActor static func shareText(_ text: String) {
        presentActivity(items: [text])
    }

    @MainActor static func shareTripFile(_ fileURL: URL, tripName: String) {
        let message = "Check out my trip \"\(tripName)\"! Open the attached file in TripWit to view the full itinerary."
        let source = TripFileActivitySource(fileURL: fileURL, tripName: tripName)
        presentActivity(items: [message, source])
    }

    @MainActor private static func presentActivity(items: [Any]) {
        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        // Find the top-most view controller to present from
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else {
            return
        }

        // Walk up to the top presented controller
        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        // iPad requires a popover source
        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: 0, width: 0, height: 0)
            popover.permittedArrowDirections = .up
        }

        topVC.present(activityVC, animated: true)
    }
}

// MARK: - Trip File Activity Source

/// Custom UIActivityItemSource that provides proper UTType metadata for .tripwit files.
/// This ensures iMessage and other apps receive correct file type information,
/// enabling "Open in TripWit" on the receiving device.
private final class TripFileActivitySource: NSObject, UIActivityItemSource {

    let fileURL: URL
    let tripName: String

    init(fileURL: URL, tripName: String) {
        self.fileURL = fileURL
        self.tripName = tripName
        super.init()
    }

    /// Placeholder tells the system what type of data we're sharing.
    func activityViewControllerPlaceholderItem(_ activityViewController: UIActivityViewController) -> Any {
        fileURL
    }

    /// Return the actual item — file URL for most activities, text message for Messages.
    func activityViewController(
        _ activityViewController: UIActivityViewController,
        itemForActivityType activityType: UIActivity.ActivityType?
    ) -> Any? {
        fileURL
    }

    /// Provide a subject line for activities that support it (e.g., Mail, Messages).
    func activityViewController(
        _ activityViewController: UIActivityViewController,
        subjectForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        "TripWit: \(tripName)"
    }

    /// Declare the UTType so the receiving device knows this is a .tripwit file.
    func activityViewController(
        _ activityViewController: UIActivityViewController,
        dataTypeIdentifierForActivityType activityType: UIActivity.ActivityType?
    ) -> String {
        "com.kevinbuckley.travelplanner.trip"
    }

    /// Provide a preview thumbnail title.
    func activityViewControllerLinkMetadata(
        _ activityViewController: UIActivityViewController
    ) -> LPLinkMetadata? {
        let metadata = LPLinkMetadata()
        metadata.title = tripName
        metadata.originalURL = fileURL
        return metadata
    }
}
