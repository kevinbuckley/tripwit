import SwiftUI
import UIKit

/// A UIActivityViewController wrapper for sharing items (PDF data, text, etc.)
struct ShareSheetView: UIViewControllerRepresentable {

    let items: [Any]
    var filename: String = "document.pdf"

    func makeUIViewController(context: Context) -> UIActivityViewController {
        // If the first item is Data, write to a temp file so it shares as a named PDF
        var shareItems: [Any] = []

        for item in items {
            if let data = item as? Data {
                let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
                try? data.write(to: tempURL)
                shareItems.append(tempURL)
            } else {
                shareItems.append(item)
            }
        }

        let controller = UIActivityViewController(
            activityItems: shareItems,
            applicationActivities: nil
        )
        return controller
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
