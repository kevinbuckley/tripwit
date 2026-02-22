import SwiftUI
import CoreData
import TripCore

struct ImportBookingSheet: View {
    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let trip: TripEntity

    @State private var inputText = ""
    @State private var parsedBookings: [ParsedBooking] = []
    @State private var phase: Phase = .input
    @State private var addedCount = 0

    enum Phase { case input, preview }

    var body: some View {
        NavigationStack {
            content
                .navigationTitle("Import Booking")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                    ToolbarItem(placement: .confirmationAction) { confirmButton }
                }
        }
    }

    @ViewBuilder
    private var confirmButton: some View {
        switch phase {
        case .input:
            Button("Parse") { parseEmail() }
                .disabled(inputText.trimmingCharacters(in: .whitespacesAndNewlines).count < 20)
        case .preview:
            if !parsedBookings.isEmpty {
                Button("Import \(parsedBookings.count)") { importBookings() }
                    .fontWeight(.semibold)
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch phase {
        case .input: inputView
        case .preview: previewView
        }
    }

    private var inputView: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "envelope.open")
                    .foregroundStyle(.blue)
                Text("Paste a booking confirmation email")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity)
            .background(Color.blue.opacity(0.08))

            TextEditor(text: $inputText)
                .frame(maxHeight: .infinity)
                .padding(.horizontal, 4)
                .overlay(
                    Group {
                        if inputText.isEmpty {
                            VStack(spacing: 8) {
                                Image(systemName: "envelope.open")
                                    .font(.system(size: 36))
                                    .foregroundStyle(.tertiary)
                                Text("Paste confirmation email text")
                                    .font(.headline)
                                    .foregroundStyle(.secondary)
                                Text("Flight, hotel, or rental car\nconfirmation emails")
                                    .font(.subheadline)
                                    .foregroundStyle(.tertiary)
                                    .multilineTextAlignment(.center)
                            }
                            .allowsHitTesting(false)
                        }
                    }
                )

            Button {
                if let clip = UIPasteboard.general.string, !clip.isEmpty { inputText = clip }
            } label: {
                Label("Paste from Clipboard", systemImage: "doc.on.clipboard")
                    .font(.subheadline).fontWeight(.medium)
                    .frame(maxWidth: .infinity).padding(.vertical, 12)
            }
            .buttonStyle(.borderedProminent)
            .tint(.blue)
            .padding(.horizontal).padding(.bottom, 12)
        }
    }

    private var previewView: some View {
        List {
            if addedCount > 0 {
                Section {
                    HStack {
                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                        Text("\(addedCount) booking(s) imported!")
                    }
                }
            }

            ForEach(parsedBookings) { booking in
                Section {
                    LabeledContent("Type", value: booking.type.label)
                    LabeledContent("Title", value: booking.title)
                    if !booking.confirmationCode.isEmpty {
                        LabeledContent("Confirmation", value: booking.confirmationCode)
                    }
                    if !booking.details.isEmpty {
                        ForEach(booking.details, id: \.key) { detail in
                            LabeledContent(detail.key, value: detail.value)
                        }
                    }
                }
            }

            Section {
                Button { phase = .input } label: {
                    Label("Edit Text", systemImage: "pencil")
                }
            }
        }
    }

    private func parseEmail() {
        parsedBookings = BookingEmailParser.parse(text: inputText)
        if parsedBookings.isEmpty {
            // Create a generic "Other" booking with the text as notes
            parsedBookings = [ParsedBooking(
                type: .other,
                title: "Imported Booking",
                confirmationCode: BookingEmailParser.extractConfirmationCode(from: inputText) ?? "",
                details: [],
                notes: String(inputText.prefix(500))
            )]
        }
        phase = .preview
    }

    private func importBookings() {
        for parsed in parsedBookings {
            let booking = BookingEntity.create(
                in: viewContext,
                type: parsed.type,
                title: parsed.title,
                confirmationCode: parsed.confirmationCode,
                notes: parsed.notes,
                sortOrder: trip.bookingsArray.count
            )

            // Apply type-specific fields from details
            for detail in parsed.details {
                switch detail.key.lowercased() {
                case "airline": booking.airline = detail.value
                case "flight number", "flight": booking.flightNumber = detail.value
                case "from", "departure": booking.departureAirport = detail.value
                case "to", "arrival": booking.arrivalAirport = detail.value
                case "hotel", "hotel name": booking.hotelName = detail.value
                case "address", "hotel address": booking.hotelAddress = detail.value
                default: break
                }
            }

            booking.trip = trip
        }
        trip.updatedAt = Date()
        try? viewContext.save()
        addedCount = parsedBookings.count
        parsedBookings = []

        // Auto-dismiss after a brief moment so user sees success
        Task {
            try? await Task.sleep(for: .seconds(1))
            await MainActor.run { dismiss() }
        }
    }
}

// MARK: - Booking Email Parser

struct ParsedBooking: Identifiable {
    let id = UUID()
    var type: BookingType
    var title: String
    var confirmationCode: String
    var details: [BookingDetail]
    var notes: String = ""
}

struct BookingDetail: Hashable {
    let key: String
    let value: String
}

struct BookingEmailParser {
    static func parse(text: String) -> [ParsedBooking] {
        let lower = text.lowercased()
        var bookings: [ParsedBooking] = []

        let confirmCode = extractConfirmationCode(from: text) ?? ""

        // Detect flight
        let flightKeywords = ["flight", "boarding pass", "airline", "departure gate", "terminal", "itinerary"]
        let isFlightEmail = flightKeywords.contains { lower.contains($0) }

        // Detect hotel
        let hotelKeywords = ["check-in", "check in", "checkout", "check out", "reservation", "hotel", "room", "guest"]
        let isHotelEmail = hotelKeywords.contains { lower.contains($0) }

        // Detect car rental
        let carKeywords = ["rental", "pickup", "car rental", "vehicle", "return location"]
        let isCarEmail = carKeywords.contains { lower.contains($0) }

        if isFlightEmail {
            var details: [BookingDetail] = []
            if let airline = extractPattern(#"(?:airline|carrier)[:\s]+(.+)"#, from: text) { details.append(BookingDetail(key: "Airline", value: airline)) }
            if let flightNum = extractPattern(#"(?:flight\s*(?:number|#|no\.?)?)[:\s]*([A-Z]{2}\s?\d{1,4})"#, from: text) { details.append(BookingDetail(key: "Flight Number", value: flightNum)) }
            if let from = extractPattern(#"(?:from|depart(?:ing|ure)?)[:\s]+([A-Z]{3}(?:\s*[-\u{2013}]\s*[A-Za-z\s]+)?)"#, from: text) { details.append(BookingDetail(key: "From", value: from)) }
            if let to = extractPattern(#"(?:to|arriv(?:ing|al)?)[:\s]+([A-Z]{3}(?:\s*[-\u{2013}]\s*[A-Za-z\s]+)?)"#, from: text) { details.append(BookingDetail(key: "To", value: to)) }

            bookings.append(ParsedBooking(
                type: .flight,
                title: details.first(where: { $0.key == "Airline" })?.value.appending(" Flight") ?? "Flight",
                confirmationCode: confirmCode,
                details: details
            ))
        }

        if isHotelEmail {
            var details: [BookingDetail] = []
            if let hotel = extractPattern(#"(?:hotel|property|accommodation)[:\s]+(.+)"#, from: text) { details.append(BookingDetail(key: "Hotel", value: hotel)) }
            if let addr = extractPattern(#"(?:address)[:\s]+(.+)"#, from: text) { details.append(BookingDetail(key: "Address", value: addr)) }

            bookings.append(ParsedBooking(
                type: .hotel,
                title: details.first(where: { $0.key == "Hotel" })?.value ?? "Hotel Reservation",
                confirmationCode: confirmCode,
                details: details
            ))
        }

        if isCarEmail {
            bookings.append(ParsedBooking(
                type: .carRental,
                title: "Car Rental",
                confirmationCode: confirmCode,
                details: []
            ))
        }

        return bookings
    }

    static func extractConfirmationCode(from text: String) -> String? {
        let patterns = [
            #"(?:confirmation|booking|reservation|reference)\s*(?:code|number|#|no\.?)[:\s]*([A-Z0-9]{4,12})"#,
            #"(?:PNR|record locator)[:\s]*([A-Z0-9]{5,8})"#,
        ]
        for pattern in patterns {
            if let match = extractPattern(pattern, from: text) {
                return match
            }
        }
        return nil
    }

    private static func extractPattern(_ pattern: String, from text: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: text) else {
            return nil
        }
        return String(text[range]).trimmingCharacters(in: .whitespacesAndNewlines)
    }
}
