import SwiftUI
import TripCore

struct TripRowView: View {

    let trip: TripEntity

    private var dateRangeText: String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return "\(formatter.string(from: trip.wrappedStartDate)) - \(formatter.string(from: trip.wrappedEndDate))"
    }

    private var stopCount: Int {
        trip.daysArray.reduce(0) { $0 + $1.stopsArray.count }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(trip.wrappedName)
                    .font(.headline)
                Spacer()
                StatusBadge(status: trip.status)
            }

            HStack(spacing: 4) {
                Image(systemName: "mappin.and.ellipse")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(trip.wrappedDestination)
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
