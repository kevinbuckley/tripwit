import SwiftUI
import TripCore

struct StopRowView: View {

    @ObservedObject var stop: StopEntity

    private var timeRangeText: String? {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .short

        if let arrival = stop.arrivalTime, let departure = stop.departureTime {
            return "\(formatter.string(from: arrival)) - \(formatter.string(from: departure))"
        } else if let arrival = stop.arrivalTime {
            return "Arrives \(formatter.string(from: arrival))"
        } else if let departure = stop.departureTime {
            return "Departs \(formatter.string(from: departure))"
        }
        return nil
    }

    var body: some View {
        if stop.isDeleted || stop.managedObjectContext == nil {
            Text("Stop removed")
                .font(.subheadline)
                .foregroundStyle(.secondary)
        } else {
            HStack(spacing: 10) {
                stopIcon
                stopLabels
                Spacer()
                visitedIndicator
            }
            .padding(.vertical, 2)
            .opacity(stop.isVisited ? 0.6 : 1.0)
        }
    }

    private var stopIcon: some View {
        Image(systemName: iconName(for: stop.category))
            .font(.body)
            .foregroundStyle(color(for: stop.category))
            .frame(width: 28, height: 28)
            .background(color(for: stop.category).opacity(0.12))
            .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var bookingSubtitle: String? {
        if stop.category == .accommodation, let nights = stop.nightCount {
            return "\(nights) night\(nights == 1 ? "" : "s")"
        }
        if stop.category == .transport,
           let dep = stop.departureAirport, !dep.isEmpty,
           let arr = stop.arrivalAirport, !arr.isEmpty {
            return "\(dep) → \(arr)"
        }
        return nil
    }

    private var stopLabels: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 4) {
                Text(stop.wrappedName)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if stop.isVisited {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundStyle(.green)
                }
                if !stop.wrappedConfirmationCode.isEmpty {
                    Text(stop.wrappedConfirmationCode)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 5)
                        .padding(.vertical, 1)
                        .background(Color(.systemGray5))
                        .clipShape(Capsule())
                }
            }
            if let subtitle = bookingSubtitle {
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(stop.category == .accommodation ? .purple : .blue)
            } else if let timeText = timeRangeText {
                Text(timeText)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    @ViewBuilder
    private var visitedIndicator: some View {
        EmptyView()
    }

    private func iconName(for category: StopCategory) -> String {
        switch category {
        case .accommodation: "bed.double.fill"
        case .restaurant: "fork.knife"
        case .attraction: "star.fill"
        case .transport: "airplane"
        case .activity: "figure.run"
        case .other: "mappin"
        }
    }

    private func color(for category: StopCategory) -> Color {
        switch category {
        case .accommodation: .purple
        case .restaurant: .orange
        case .attraction: .yellow
        case .transport: .blue
        case .activity: .green
        case .other: .gray
        }
    }
}
