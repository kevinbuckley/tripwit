import SwiftUI
import CloudKit
import CoreData
import MessageUI
import os.log
import UIKit

private let diagLog = Logger(subsystem: "com.kevinbuckley.travelplanner", category: "SharingDiag")

// MARK: - Diagnostic View

struct SharingDiagnosticView: View {
    let trip: TripEntity

    @State private var shareURL: URL?
    @State private var wrappedURLString: String = ""
    @State private var isCreatingShare = false
    @State private var logLines: [String] = []
    @State private var showMessageCompose = false

    private let persistence = PersistenceController.shared
    private let sharingService = CloudKitSharingService()

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    shareStatusSection
                    Divider()
                    testButtonsSection
                    Divider()
                    logSection
                }
            }
            .navigationTitle("Share Diagnostic")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showMessageCompose) {
                MessageComposeView(body: wrappedURLString) { result in
                    switch result {
                    case .cancelled:
                        log("MFMessageCompose: cancelled")
                    case .sent:
                        log("MFMessageCompose: sent")
                    case .failed:
                        log("MFMessageCompose: failed")
                    @unknown default:
                        log("MFMessageCompose: unknown result")
                    }
                }
            }
        }
    }

    // MARK: - Share Status

    private var shareStatusSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Trip: \(trip.wrappedName)")
                .font(.headline)

            if isCreatingShare {
                HStack(spacing: 8) {
                    ProgressView()
                    Text("Creating CKShare...")
                        .foregroundStyle(.secondary)
                }
            } else if let url = shareURL {
                VStack(alignment: .leading, spacing: 4) {
                    Label("CKShare ready", systemImage: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                    Text(url.absoluteString)
                        .font(.caption2)
                        .monospaced()
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                    Text("Wrapped:")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text(wrappedURLString)
                        .font(.caption2)
                        .monospaced()
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
            } else {
                Label("No CKShare yet", systemImage: "xmark.circle")
                    .foregroundStyle(.orange)
            }

            HStack(spacing: 12) {
                Button {
                    Task { await createOrFetchShare() }
                } label: {
                    Label(
                        shareURL == nil ? "Create CKShare" : "Refresh CKShare",
                        systemImage: "arrow.triangle.2.circlepath"
                    )
                }
                .buttonStyle(.borderedProminent)
                .disabled(isCreatingShare)

                Button {
                    useFakeShareURL()
                } label: {
                    Label("Use Fake URL", systemImage: "link.badge.plus")
                }
                .buttonStyle(.bordered)
                .tint(.orange)
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    // MARK: - Test Buttons

    private var testButtonsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sharing Tests")
                .font(.headline)
                .padding(.bottom, 4)

            Text("Fake URL = no spinner. Now test with REAL CKShare to see if creating the share poisons the share sheet.")
                .font(.caption)
                .foregroundStyle(.secondary)

            // --- PHASE A: Before CKShare exists ---
            Text("PHASE A — Before CKShare")
                .font(.caption.bold())
                .foregroundStyle(.purple)
                .padding(.top, 4)

            // A1. Plain text BEFORE creating share
            DiagButton(
                number: 1,
                title: "Plain text (pre-share)",
                subtitle: "Share \"Hello\" BEFORE creating any CKShare",
                color: .green
            ) {
                log("TEST A1: Plain text BEFORE CKShare creation")
                log("  hasExistingShare: \(sharingService.existingShare(for: trip) != nil)")
                presentActivity(items: ["Hello from Travly — pre-share test!" as NSString])
            }

            // --- PHASE B: Create the CKShare ---
            Text("PHASE B — Create CKShare")
                .font(.caption.bold())
                .foregroundStyle(.purple)
                .padding(.top, 4)

            // B1. Create share and show URL
            DiagButton(
                number: 2,
                title: "Create Real CKShare",
                subtitle: "Creates share via container.share(), stores URL",
                color: .red
            ) {
                log("TEST B1: Creating REAL CKShare...")
                Task { await createOrFetchShare() }
            }

            // --- PHASE C: After CKShare exists — test different payloads ---
            Text("PHASE C — After CKShare exists")
                .font(.caption.bold())
                .foregroundStyle(.purple)
                .padding(.top, 4)

            // C1. Plain text AFTER creating share (key test!)
            DiagButton(
                number: 3,
                title: "Plain text (post-share)",
                subtitle: "⭐ KEY: Share \"Hello\" AFTER CKShare exists. Spinners = share poisoned it",
                color: .orange,
                requiresShare: true,
                shareReady: shareURL != nil
            ) {
                log("TEST C1: Plain text AFTER CKShare creation")
                log("  hasExistingShare: \(sharingService.existingShare(for: trip) != nil)")
                presentActivity(items: ["Hello from Travly — post-share test!" as NSString])
            }

            // C2. Real iCloud URL as string
            DiagButton(
                number: 4,
                title: "Real iCloud URL as text",
                subtitle: "Real share.icloud.com URL in a string",
                color: .orange,
                requiresShare: true,
                shareReady: shareURL != nil
            ) {
                guard let url = shareURL else { return }
                let text = "Join my trip: \(url.absoluteString)"
                log("TEST C2: Real iCloud URL as NSString")
                log("  payload: \"\(text)\"")
                presentActivity(items: [text as NSString])
            }

            // C3. Wrapped travly:// with real URL
            DiagButton(
                number: 5,
                title: "Wrapped travly:// (real URL)",
                subtitle: "travly://share?url=<real_encoded_url> as string",
                color: .orange,
                requiresShare: true,
                shareReady: shareURL != nil
            ) {
                guard !wrappedURLString.isEmpty else { return }
                let text = "Join my trip!\n\(wrappedURLString)"
                log("TEST C3: Wrapped travly:// with real URL as NSString")
                log("  payload: \"\(text)\"")
                presentActivity(items: [text as NSString])
            }

            // C4. MFMessageCompose with real wrapped URL
            DiagButton(
                number: 6,
                title: "MFMessageCompose (real URL)",
                subtitle: "Bypass UIActivityVC — send wrapped URL directly via Messages",
                color: .blue,
                requiresShare: true,
                shareReady: shareURL != nil
            ) {
                guard !wrappedURLString.isEmpty else { return }
                if MFMessageComposeViewController.canSendText() {
                    log("TEST C4: MFMessageComposeViewController with real wrapped URL")
                    log("  body: \"\(wrappedURLString)\"")
                    showMessageCompose = true
                } else {
                    log("TEST C4: FAILED — canSendText() == false")
                }
            }

            // C5. Copy to clipboard
            DiagButton(
                number: 7,
                title: "Copy real URL to clipboard",
                subtitle: "Copy wrapped URL, paste manually into Messages",
                color: .blue,
                requiresShare: true,
                shareReady: shareURL != nil
            ) {
                guard !wrappedURLString.isEmpty else { return }
                UIPasteboard.general.string = wrappedURLString
                log("TEST C5: Copied real wrapped URL to clipboard")
                log("  value: \"\(wrappedURLString)\"")
                log("  → Open Messages, paste, and send to test")
            }
        }
        .padding()
    }

    // MARK: - Log Section

    private var logSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("Log")
                    .font(.headline)
                Spacer()
                Button("Clear") {
                    logLines.removeAll()
                }
                .font(.caption)
            }

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 2) {
                    ForEach(Array(logLines.enumerated()), id: \.offset) { _, line in
                        Text(line)
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.primary)
                            .textSelection(.enabled)
                    }
                }
            }
            .frame(minHeight: 200, maxHeight: 300)
            .padding(8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
    }

    // MARK: - Actions

    /// Use a fake share.icloud.com URL to test URL pattern detection
    /// without needing a real CKShare. This lets us isolate the
    /// "does Messages detect iCloud URLs?" question from "can we create a share?".
    private func useFakeShareURL() {
        let fakeURL = URL(string: "https://share.icloud.com/share/fakeTEST12345abcde")!
        shareURL = fakeURL
        wrappedURLString = buildWrappedURL(from: fakeURL)
        log("--- Using FAKE share.icloud.com URL ---")
        log("  URL: \(fakeURL.absoluteString)")
        log("  Wrapped: \(wrappedURLString)")
        log("  (This won't actually work for accepting, but tests Messages behavior)")
    }

    private func createOrFetchShare() async {
        isCreatingShare = true
        defer { isCreatingShare = false }

        log("--- Creating/Fetching CKShare ---")

        // Check for existing share first
        if let existing = sharingService.existingShare(for: trip) {
            log("Found existing CKShare")
            if let url = existing.url {
                log("  URL: \(url.absoluteString)")
                shareURL = url
                wrappedURLString = buildWrappedURL(from: url)
                log("  Wrapped: \(wrappedURLString)")
            } else {
                log("  WARNING: existing share has NO URL")
            }
            return
        }

        log("No existing share — calling container.share()...")
        let startTime = CFAbsoluteTimeGetCurrent()

        do {
            let share = try await sharingService.shareTrip(trip)
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            log("container.share() succeeded in \(String(format: "%.2f", elapsed))s")

            // Configure share
            share[CKShare.SystemFieldKey.title] = trip.wrappedName
            share.publicPermission = .readWrite

            // Persist
            if let store = persistence.privatePersistentStore {
                try await persistence.container.persistUpdatedShare(share, in: store)
                log("persistUpdatedShare completed")
            }

            if let url = share.url {
                shareURL = url
                wrappedURLString = buildWrappedURL(from: url)
                log("Share URL: \(url.absoluteString)")
                log("Wrapped URL: \(wrappedURLString)")
            } else {
                log("ERROR: share created but has no URL")
            }
        } catch {
            let elapsed = CFAbsoluteTimeGetCurrent() - startTime
            let nsError = error as NSError
            log("ERROR after \(String(format: "%.2f", elapsed))s: \(nsError.domain) code=\(nsError.code)")
            log("  \(error.localizedDescription)")
        }
    }

    private func buildWrappedURL(from shareURL: URL) -> String {
        let encoded = shareURL.absoluteString.addingPercentEncoding(
            withAllowedCharacters: .urlQueryAllowed
        ) ?? shareURL.absoluteString
        return "travly://share?url=\(encoded)"
    }

    @MainActor
    private func presentActivity(items: [Any]) {
        guard let windowScene = UIApplication.shared.connectedScenes
            .compactMap({ $0 as? UIWindowScene }).first,
              let rootVC = windowScene.windows.first(where: { $0.isKeyWindow })?.rootViewController
        else {
            log("ERROR: No window scene or root VC")
            return
        }

        var topVC = rootVC
        while let presented = topVC.presentedViewController {
            topVC = presented
        }

        let activityVC = UIActivityViewController(
            activityItems: items,
            applicationActivities: nil
        )

        // Log what types we're passing
        for (i, item) in items.enumerated() {
            log("  activityItems[\(i)] type: \(type(of: item))")
        }

        activityVC.completionWithItemsHandler = { activityType, completed, returnedItems, error in
            if let activityType {
                log("Activity completed: type=\(activityType.rawValue), completed=\(completed)")
            } else {
                log("Activity dismissed (no type selected)")
            }
            if let error {
                log("Activity error: \(error.localizedDescription)")
            }
        }

        if let popover = activityVC.popoverPresentationController {
            popover.sourceView = topVC.view
            popover.sourceRect = CGRect(x: topVC.view.bounds.midX, y: topVC.view.bounds.midY, width: 0, height: 0)
            popover.permittedArrowDirections = []
        }

        topVC.present(activityVC, animated: true) {
            log("UIActivityViewController presented")
        }
    }

    private func log(_ message: String) {
        let timestamp = Self.timeFormatter.string(from: Date())
        let line = "[\(timestamp)] \(message)"
        diagLog.info("\(line)")
        DispatchQueue.main.async {
            logLines.append(line)
        }
    }

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "HH:mm:ss.SSS"
        return f
    }()
}

// MARK: - Diagnostic Button

private struct DiagButton: View {
    let number: Int
    let title: String
    let subtitle: String
    let color: Color
    var requiresShare: Bool = false
    var shareReady: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(alignment: .top, spacing: 12) {
                Text("\(number)")
                    .font(.system(size: 14, weight: .bold, design: .monospaced))
                    .foregroundStyle(.white)
                    .frame(width: 28, height: 28)
                    .background(color)
                    .clipShape(Circle())

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                }

                Spacer()

                Image(systemName: "arrow.up.forward.square")
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .disabled(requiresShare && !shareReady)
        .opacity(requiresShare && !shareReady ? 0.4 : 1.0)
    }
}

// MARK: - MFMessageComposeViewController wrapper

private struct MessageComposeView: UIViewControllerRepresentable {
    let body: String
    let onResult: (MessageComposeResult) -> Void

    func makeUIViewController(context: Context) -> MFMessageComposeViewController {
        let vc = MFMessageComposeViewController()
        vc.body = body
        vc.messageComposeDelegate = context.coordinator
        return vc
    }

    func updateUIViewController(_ uiViewController: MFMessageComposeViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onResult: onResult)
    }

    class Coordinator: NSObject, MFMessageComposeViewControllerDelegate {
        let onResult: (MessageComposeResult) -> Void

        init(onResult: @escaping (MessageComposeResult) -> Void) {
            self.onResult = onResult
        }

        func messageComposeViewController(
            _ controller: MFMessageComposeViewController,
            didFinishWith result: MessageComposeResult
        ) {
            onResult(result)
            controller.dismiss(animated: true)
        }
    }
}

// MARK: - Preview

#Preview {
    let context = PersistenceController(inMemory: true).viewContext
    let trip = TripEntity.create(
        in: context,
        name: "Test Trip",
        destination: "Hawaii",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 7)
    )
    return SharingDiagnosticView(trip: trip)
}
