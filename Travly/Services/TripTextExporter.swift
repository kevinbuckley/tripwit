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
        lines.append(trip.wrappedName.uppercased())
        lines.append("\(trip.wrappedDestination)")
        lines.append("\(dateFmt.string(from: trip.wrappedStartDate)) - \(dateFmt.string(from: trip.wrappedEndDate)) (\(trip.durationInDays) days)")
        lines.append("")

        // Bookings
        let bookings = trip.bookingsArray
        if !bookings.isEmpty {
            lines.append("FLIGHTS & HOTELS")
            for bk in bookings {
                var desc = "\(bk.bookingType.label): \(bk.wrappedTitle)"
                if !bk.wrappedConfirmationCode.isEmpty {
                    desc += " (\(bk.wrappedConfirmationCode))"
                }
                lines.append("  \(desc)")
            }
            lines.append("")
        }

        // Itinerary
        let days = trip.daysArray
        for day in days {
            var header = "DAY \(day.dayNumber) — \(dateFmt.string(from: day.wrappedDate))"
            if !day.wrappedLocation.isEmpty {
                header += " — \(day.wrappedLocation)"
            }
            lines.append(header)

            if !day.wrappedNotes.isEmpty {
                lines.append("  \(day.wrappedNotes)")
            }

            let stops = day.stopsArray
            if stops.isEmpty {
                lines.append("  No stops planned")
            } else {
                for stop in stops {
                    var stopLine = "  \u{2022} \(stop.wrappedName)"
                    if let arrival = stop.arrivalTime {
                        stopLine += " (\(timeFmt.string(from: arrival))"
                        if let departure = stop.departureTime {
                            stopLine += " - \(timeFmt.string(from: departure))"
                        }
                        stopLine += ")"
                    }
                    lines.append(stopLine)
                    if !stop.wrappedNotes.isEmpty {
                        lines.append("    \(stop.wrappedNotes)")
                    }
                }
            }
            lines.append("")
        }

        lines.append("Shared from Travly")

        return lines.joined(separator: "\n")
    }
}
