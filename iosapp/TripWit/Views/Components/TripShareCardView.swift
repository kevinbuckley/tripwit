import SwiftUI
import TripCore

// MARK: - Card Data Model

/// A pure-value snapshot of trip info for the shareable card.
/// Initialised from a `TripEntity`; all fields are pre-formatted strings.
struct TripCardData {

    let name:         String   // e.g. "My Paris Adventure"
    let destination:  String   // uppercased, e.g. "PARIS, FRANCE"
    let dateRange:    String?  // e.g. "Jan 10 – Jan 17", nil when dates not set
    let durationText: String?  // e.g. "7 days", nil when dates not set
    let stopCount:    Int
    let status:       TripStatus

    init(from trip: TripEntity) {
        name        = trip.wrappedName
        destination = trip.wrappedDestination.uppercased()
        status      = trip.displayStatus
        stopCount   = trip.daysArray.reduce(0) { $0 + $1.stopsArray.count }

        if trip.hasCustomDates {
            let fmt = DateFormatter()
            fmt.dateStyle = .medium
            fmt.timeStyle = .none
            dateRange    = "\(fmt.string(from: trip.wrappedStartDate)) – \(fmt.string(from: trip.wrappedEndDate))"
            let d        = trip.durationInDays
            durationText = "\(d) day\(d == 1 ? "" : "s")"
        } else {
            dateRange    = nil
            durationText = nil
        }
    }

    /// Direct memberwise init — used by previews and tests (bypasses TripEntity).
    init(name: String, destination: String, dateRange: String?,
         durationText: String?, stopCount: Int, status: TripStatus) {
        self.name         = name
        self.destination  = destination.uppercased()
        self.dateRange    = dateRange
        self.durationText = durationText
        self.stopCount    = stopCount
        self.status       = status
    }

    /// e.g. "12 stops planned" or "1 stop planned"
    var stopCountText: String {
        "\(stopCount) stop\(stopCount == 1 ? "" : "s") planned"
    }
}

// MARK: - Share Card View

/// A branded 360 × 216 pt card designed to be rendered to a UIImage via ImageRenderer.
///
/// The top half is a rich gradient (keyed by trip status); the bottom half is white
/// with the trip name, dates, and a discreet TripWit attribution.
struct TripShareCardView: View {

    let data: TripCardData

    // Dark, rich gradients that look great with white text and work as social images
    private var cardGradient: LinearGradient {
        switch data.status {
        case .active:
            return LinearGradient(
                colors: [Color(red: 0.00, green: 0.40, blue: 0.22),
                         Color(red: 0.00, green: 0.46, blue: 0.44)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .planning:
            return LinearGradient(
                colors: [Color(red: 0.10, green: 0.14, blue: 0.50),
                         Color(red: 0.27, green: 0.14, blue: 0.62)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        case .completed:
            return LinearGradient(
                colors: [Color(red: 0.14, green: 0.14, blue: 0.20),
                         Color(red: 0.22, green: 0.22, blue: 0.30)],
                startPoint: .topLeading, endPoint: .bottomTrailing
            )
        }
    }

    var body: some View {
        VStack(spacing: 0) {

            // ── Gradient header ──────────────────────────────────────────
            ZStack(alignment: .bottomLeading) {
                cardGradient

                VStack(alignment: .leading, spacing: 5) {
                    HStack(spacing: 8) {
                        Image("TripWitIcon")
                            .resizable()
                            .scaledToFit()
                            .frame(width: 26, height: 26)
                            .clipShape(RoundedRectangle(cornerRadius: 6, style: .continuous))
                        Text(data.destination)
                            .font(.system(size: 21, weight: .bold, design: .rounded))
                            .foregroundStyle(.white)
                            .lineLimit(1)
                    }
                    if let duration = data.durationText {
                        Text(duration)
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.70))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 18)
            }
            .frame(height: 108)

            // ── Details section ──────────────────────────────────────────
            ZStack(alignment: .bottomTrailing) {
                Color(.systemBackground)

                VStack(alignment: .leading, spacing: 6) {
                    Text(data.name)
                        .font(.system(size: 19, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    if let dateRange = data.dateRange {
                        Label(dateRange, systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Label(data.stopCountText, systemImage: "mappin")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    Spacer(minLength: 0)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)
                .padding(.top, 16)

                // Branding watermark
                HStack(spacing: 4) {
                    Image("TripWitIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 12, height: 12)
                        .clipShape(RoundedRectangle(cornerRadius: 2, style: .continuous))
                        .opacity(0.4)
                    Text("TripWit")
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .foregroundStyle(.tertiary)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 14)
            }
            .frame(height: 108)
        }
        .frame(width: 360, height: 216)
        .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
        .shadow(color: .black.opacity(0.14), radius: 14, x: 0, y: 5)
    }
}

// MARK: - Renderer

/// Renders a `TripShareCardView` to a `UIImage` at 3× scale for crisp social sharing.
enum TripCardRenderer {

    @MainActor
    static func render(from data: TripCardData) -> UIImage? {
        let view = TripShareCardView(data: data)
            .environment(\.colorScheme, .light)   // always light mode for share images
        let renderer = ImageRenderer(content: view)
        renderer.scale = 3.0                       // → 1080 × 648 px at @3x
        return renderer.uiImage
    }
}

// MARK: - Previews

private func previewData(status: TripStatus) -> TripCardData {
    TripCardData(
        name:         "My Paris Adventure",
        destination:  "Paris, France",
        dateRange:    "Jun 10, 2026 – Jun 17, 2026",
        durationText: "7 days",
        stopCount:    12,
        status:       status
    )
}

#Preview("Planning") {
    TripShareCardView(data: previewData(status: .planning))
        .padding()
}

#Preview("Active") {
    TripShareCardView(data: previewData(status: .active))
        .padding()
}

#Preview("Completed") {
    TripShareCardView(data: previewData(status: .completed))
        .padding()
}
