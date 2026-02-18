import Foundation

/// Generates a plain-text itinerary suitable for sharing via Messages, email, or copying.
struct TripTextExporter {

    static func generateText(for trip: TripEntity) -> String {
        var lines: [String] = []

        let dateFmt = DateFormatter()
        dateFmt.dateStyle = .medium
        dateFmt.timeStyle = .none
        let timeFmt = DateFormatter()
        timeFmt.dateStyle = .none
        timeFmt.timeStyle = .short

        // Header
        lines.append(trip.name.uppercased())
        lines.append("\(trip.destination)")
        lines.append("\(dateFmt.string(from: trip.startDate)) - \(dateFmt.string(from: trip.endDate)) (\(trip.durationInDays) days)")
        lines.append("")

        // Bookings
        let bookings = trip.bookings.sorted { $0.sortOrder < $1.sortOrder }
        if !bookings.isEmpty {
            lines.append("FLIGHTS & HOTELS")
            for bk in bookings {
                var desc = "\(bk.bookingType.label): \(bk.title)"
                if !bk.confirmationCode.isEmpty {
                    desc += " (\(bk.confirmationCode))"
                }
                lines.append("  \(desc)")
            }
            lines.append("")
        }

        // Itinerary
        let days = trip.days.sorted { $0.dayNumber < $1.dayNumber }
        for day in days {
            var header = "DAY \(day.dayNumber) — \(dateFmt.string(from: day.date))"
            if !day.location.isEmpty {
                header += " — \(day.location)"
            }
            lines.append(header)

            if !day.notes.isEmpty {
                lines.append("  \(day.notes)")
            }

            let stops = day.stops.sorted { $0.sortOrder < $1.sortOrder }
            if stops.isEmpty {
                lines.append("  No stops planned")
            } else {
                for stop in stops {
                    var stopLine = "  \u{2022} \(stop.name)"
                    if let arrival = stop.arrivalTime {
                        stopLine += " (\(timeFmt.string(from: arrival))"
                        if let departure = stop.departureTime {
                            stopLine += " - \(timeFmt.string(from: departure))"
                        }
                        stopLine += ")"
                    }
                    lines.append(stopLine)
                    if !stop.notes.isEmpty {
                        lines.append("    \(stop.notes)")
                    }
                }
            }
            lines.append("")
        }

        lines.append("Shared from Travly")

        return lines.joined(separator: "\n")
    }
}
