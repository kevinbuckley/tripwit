import SwiftUI
import TripCore

struct TripRowView: View {

    let trip: TripEntity

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: trip.startDate)) - \(formatter.string(from: trip.endDate))"
    }

    private var stopCount: Int {
        trip.days.reduce(0) { $0 + $1.stops.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(trip.name)
                    .font(.headline)
                Spacer()
                StatusBadge(status: trip.status)
            }

            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(trip.destination)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }

            if trip.hasCustomDates {
                HStack {
                    Text(dateRangeText)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("\(trip.durationInDays) days")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    if stopCount > 0 {
                        Text("  \(stopCount) stops")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            } else {
                HStack {
                    Text("Dates not set")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    if stopCount > 0 {
                        Text("\(stopCount) stops")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}
