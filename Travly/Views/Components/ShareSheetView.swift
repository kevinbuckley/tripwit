import SwiftUI
import UIKit

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

    @MainActor static func shareTripFile(_ fileURL: URL) {
        presentActivity(items: [fileURL])
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
