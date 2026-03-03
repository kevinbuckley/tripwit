import SwiftUI

/// A compact row showing estimated travel time between two consecutive stops.
struct TravelTimeRow: View {

    let estimate: TravelTimeService.TravelEstimate?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: "arrow.down")
                .font(.caption2)
                .foregroundStyle(.tertiary)

            if let estimate {
                if estimate.isLoading {
                    ProgressView()
                        .controlSize(.mini)
                    Text("Calculating...")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                } else {
                    travelInfo(estimate)
                }
            }

            Spacer()
        }
        .padding(.vertical, 2)
        .listRowInsets(EdgeInsets(top: 0, leading: 52, bottom: 0, trailing: 16))
    }

    @ViewBuilder
    private func travelInfo(_ est: TravelTimeService.TravelEstimate) -> some View {
        if est.drivingMinutes == nil && est.walkingMinutes == nil {
            Text("Route unavailable")
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }

        if let drivingMins = est.drivingMinutes {
            Label {
                Text(formatDuration(drivingMins))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "car.fill")
                    .font(.caption2)
                    .foregroundStyle(.blue)
            }
        }

        if let walkingMins = est.walkingMinutes {
            Label {
                Text(formatDuration(walkingMins))
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            } icon: {
                Image(systemName: "figure.walk")
                    .font(.caption2)
                    .foregroundStyle(.green)
            }
        }

        if let distance = est.distanceMeters {
            Text(formatDistance(distance))
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private func formatDuration(_ minutes: Int) -> String {
        if minutes < 60 {
            return "\(minutes) min"
        } else {
            let hrs = minutes / 60
            let mins = minutes % 60
            return mins > 0 ? "\(hrs)h \(mins)m" : "\(hrs)h"
        }
    }

    private func formatDistance(_ meters: Double) -> String {
        if Locale.current.measurementSystem == .us {
            let miles = meters / 1609.34
            if miles < 0.1 {
                let feet = Int(meters * 3.28084)
                return "\(feet) ft"
            }
            return String(format: "%.1f mi", miles)
        } else {
            if meters < 1000 {
                return "\(Int(meters)) m"
            }
            return String(format: "%.1f km", meters / 1000)
        }
    }
}
