import SwiftUI
import TripCore

// MARK: - Countdown State (pure, testable)

/// Describes a trip's temporal relationship to today.
enum TripCountdownState: Equatable {
    case noDates
    case countdown(days: Int)                    // future: "in N days"
    case activeDay(current: Int, total: Int)     // on-trip: "Day M of N"
    case completed(endDate: Date)                // past: "Completed Jun 17"

    /// Pure factory — takes raw dates, safe to unit test without a `TripEntity`.
    static func compute(startDate: Date, endDate: Date, now: Date = Date()) -> TripCountdownState {
        let cal   = Calendar.current
        let today = cal.startOfDay(for: now)
        let start = cal.startOfDay(for: startDate)
        let end   = cal.startOfDay(for: endDate)

        if today < start {
            let days = cal.dateComponents([.day], from: today, to: start).day ?? 0
            return .countdown(days: max(1, days))
        } else if today > end {
            return .completed(endDate: endDate)
        } else {
            let current = (cal.dateComponents([.day], from: start, to: today).day ?? 0) + 1
            let total   = (cal.dateComponents([.day], from: start, to: end).day ?? 0) + 1
            return .activeDay(current: current, total: total)
        }
    }
}

// MARK: - Badge View

/// A compact capsule badge that shows how far away (or into) a trip is.
///
/// • Planning + future dates  → blue "in N days" capsule
/// • Planning/active, on-trip → green pulsing "Day M of N" capsule
/// • Completed / past         → subtle gray "Completed Jun 17" capsule
/// • No dates set             → nothing rendered
struct TripCountdownBadge: View {

    let trip: TripEntity

    private var state: TripCountdownState {
        guard trip.hasCustomDates else { return .noDates }
        return TripCountdownState.compute(
            startDate: trip.wrappedStartDate,
            endDate:   trip.wrappedEndDate
        )
    }

    var body: some View {
        Group {
            switch state {
            case .noDates:
                EmptyView()

            case .countdown(let days):
                Label {
                    Text("in \(days) day\(days == 1 ? "" : "s")")
                } icon: {
                    Image("TripWitIcon")
                        .resizable()
                        .scaledToFit()
                        .frame(width: 14, height: 14)
                        .clipShape(RoundedRectangle(cornerRadius: 3, style: .continuous))
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.blue)
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.blue.opacity(0.10), in: Capsule())

            case .activeDay(let current, let total):
                HStack(spacing: 5) {
                    // Soft pulsing live dot
                    Circle()
                        .fill(.green)
                        .frame(width: 6, height: 6)
                        .phaseAnimator([false, true]) { circle, phase in
                            circle.opacity(phase ? 0.3 : 1.0)
                        } animation: { _ in .easeInOut(duration: 0.9) }
                    Text("Day \(current) of \(total)")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.green)
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 3)
                .background(.green.opacity(0.10), in: Capsule())

            case .completed(let endDate):
                Label(completedLabel(endDate), systemImage: "checkmark.circle.fill")
                    .font(.caption.weight(.medium))
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 3)
                    .background(Color(.tertiarySystemFill), in: Capsule())
            }
        }
        .animation(.easeInOut(duration: 0.3), value: trip.statusRaw)
    }

    private func completedLabel(_ date: Date) -> String {
        let fmt = DateFormatter()
        fmt.dateFormat = "MMM d"
        return "Completed \(fmt.string(from: date))"
    }
}
