import EventKit
import Foundation

/// Exports trip days as all-day calendar events to Apple Calendar.
@Observable
final class CalendarService {

    private let store = EKEventStore()

    enum CalendarError: LocalizedError {
        case accessDenied
        case noCalendar
        case saveFailed(String)

        var errorDescription: String? {
            switch self {
            case .accessDenied: "Calendar access was denied. Enable it in Settings > Privacy > Calendars."
            case .noCalendar: "No default calendar found."
            case .saveFailed(let msg): "Failed to save events: \(msg)"
            }
        }
    }

    /// Request full calendar access (iOS 17+).
    func requestAccess() async -> Bool {
        do {
            return try await store.requestFullAccessToEvents()
        } catch {
            return false
        }
    }

    /// Export a trip's days as all-day calendar events.
    /// Returns the number of events created.
    @discardableResult
    func exportTrip(
        name: String,
        destination: String,
        days: [(dayNumber: Int, date: Date, notes: String, stopNames: [String])]
    ) async throws -> Int {
        let granted = await requestAccess()
        guard granted else { throw CalendarError.accessDenied }
        guard let calendar = store.defaultCalendarForNewEvents else { throw CalendarError.noCalendar }

        var count = 0
        for day in days {
            let event = EKEvent(eventStore: store)
            event.title = "\(name) — Day \(day.dayNumber)"
            event.isAllDay = true
            event.startDate = day.date
            event.endDate = day.date
            event.calendar = calendar
            event.location = destination

            var noteLines: [String] = []
            if !day.notes.isEmpty {
                noteLines.append(day.notes)
            }
            if !day.stopNames.isEmpty {
                noteLines.append("")
                noteLines.append("Stops:")
                for stopName in day.stopNames {
                    noteLines.append("  \u{2022} \(stopName)")
                }
            }
            if !noteLines.isEmpty {
                event.notes = noteLines.joined(separator: "\n")
            }

            do {
                try store.save(event, span: .thisEvent)
                count += 1
            } catch {
                throw CalendarError.saveFailed(error.localizedDescription)
            }
        }

        return count
    }
}
