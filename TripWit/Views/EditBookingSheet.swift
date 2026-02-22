import SwiftUI
import CoreData

struct EditBookingSheet: View {

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let booking: BookingEntity

    @State private var bookingType: BookingType
    @State private var title: String
    @State private var confirmationCode: String
    @State private var notes: String

    // Flight fields
    @State private var airline: String
    @State private var flightNumber: String
    @State private var departureAirport: String
    @State private var arrivalAirport: String
    @State private var departureTime: Date
    @State private var arrivalTime: Date
    @State private var hasDepartureTime: Bool
    @State private var hasArrivalTime: Bool

    // Hotel fields
    @State private var hotelName: String
    @State private var hotelAddress: String
    @State private var checkInDate: Date
    @State private var checkOutDate: Date

    init(booking: BookingEntity) {
        self.booking = booking
        _bookingType = State(initialValue: booking.bookingType)
        _title = State(initialValue: booking.title ?? "")
        _confirmationCode = State(initialValue: booking.confirmationCode ?? "")
        _notes = State(initialValue: booking.notes ?? "")

        _airline = State(initialValue: booking.airline ?? "")
        _flightNumber = State(initialValue: booking.flightNumber ?? "")
        _departureAirport = State(initialValue: booking.departureAirport ?? "")
        _arrivalAirport = State(initialValue: booking.arrivalAirport ?? "")
        _departureTime = State(initialValue: booking.departureTime ?? Date())
        _arrivalTime = State(initialValue: booking.arrivalTime ?? Date())
        _hasDepartureTime = State(initialValue: booking.departureTime != nil)
        _hasArrivalTime = State(initialValue: booking.arrivalTime != nil)

        _hotelName = State(initialValue: booking.hotelName ?? "")
        _hotelAddress = State(initialValue: booking.hotelAddress ?? "")
        _checkInDate = State(initialValue: booking.checkInDate ?? Date())
        _checkOutDate = State(initialValue: booking.checkOutDate ?? Date())
    }

    var body: some View {
        NavigationStack {
            Form {
                // Booking Type
                Section {
                    Picker("Type", selection: $bookingType) {
                        ForEach(BookingType.allCases, id: \.self) { type in
                            Label(type.label, systemImage: type.icon)
                                .tag(type)
                        }
                    }
                }

                // Common fields
                Section {
                    TextField("Title (e.g. Outbound Flight)", text: $title)
                    TextField("Confirmation Code", text: $confirmationCode)
                        .textInputAutocapitalization(.characters)
                } header: {
                    Text("Booking Info")
                }

                // Type-specific fields
                switch bookingType {
                case .flight:
                    flightFields
                case .hotel:
                    hotelFields
                case .carRental:
                    carRentalFields
                case .other:
                    EmptyView()
                }

                // Notes
                Section {
                    TextField("Notes", text: $notes, axis: .vertical)
                        .lineLimit(2...6)
                } header: {
                    Text("Notes")
                }
            }
            .navigationTitle("Edit Booking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save() }
                        .fontWeight(.semibold)
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    // MARK: - Flight Fields

    private var flightFields: some View {
        Section {
            TextField("Airline", text: $airline)
            TextField("Flight Number", text: $flightNumber)
                .textInputAutocapitalization(.characters)
            TextField("Departure Airport (e.g. LAX)", text: $departureAirport)
                .textInputAutocapitalization(.characters)
            TextField("Arrival Airport (e.g. NRT)", text: $arrivalAirport)
                .textInputAutocapitalization(.characters)

            Toggle("Departure Time", isOn: $hasDepartureTime)
            if hasDepartureTime {
                DatePicker("Departs", selection: $departureTime)
            }

            Toggle("Arrival Time", isOn: $hasArrivalTime)
            if hasArrivalTime {
                DatePicker("Arrives", selection: $arrivalTime)
            }
        } header: {
            Text("Flight Details")
        }
    }

    // MARK: - Hotel Fields

    private var hotelFields: some View {
        Section {
            TextField("Hotel Name", text: $hotelName)
            TextField("Address", text: $hotelAddress)
            DatePicker("Check-in", selection: $checkInDate, displayedComponents: [.date])
            DatePicker("Check-out", selection: $checkOutDate, in: checkInDate..., displayedComponents: [.date])
        } header: {
            Text("Hotel Details")
        }
    }

    // MARK: - Car Rental Fields

    private var carRentalFields: some View {
        Section {
            Toggle("Pickup Time", isOn: $hasDepartureTime)
            if hasDepartureTime {
                DatePicker("Pickup", selection: $departureTime)
            }
            Toggle("Return Time", isOn: $hasArrivalTime)
            if hasArrivalTime {
                DatePicker("Return", selection: $arrivalTime)
            }
        } header: {
            Text("Rental Details")
        }
    }

    // MARK: - Save

    private func save() {
        booking.bookingType = bookingType
        booking.title = title.trimmingCharacters(in: .whitespaces)
        booking.confirmationCode = confirmationCode.trimmingCharacters(in: .whitespaces)
        booking.notes = notes.trimmingCharacters(in: .whitespaces)

        switch bookingType {
        case .flight:
            booking.airline = airline.isEmpty ? nil : airline
            booking.flightNumber = flightNumber.isEmpty ? nil : flightNumber
            booking.departureAirport = departureAirport.isEmpty ? nil : departureAirport
            booking.arrivalAirport = arrivalAirport.isEmpty ? nil : arrivalAirport
            booking.departureTime = hasDepartureTime ? departureTime : nil
            booking.arrivalTime = hasArrivalTime ? arrivalTime : nil
            // Clear hotel fields
            booking.hotelName = nil
            booking.hotelAddress = nil
            booking.checkInDate = nil
            booking.checkOutDate = nil
        case .hotel:
            booking.hotelName = hotelName.isEmpty ? nil : hotelName
            booking.hotelAddress = hotelAddress.isEmpty ? nil : hotelAddress
            booking.checkInDate = checkInDate
            booking.checkOutDate = checkOutDate
            // Clear flight fields
            booking.airline = nil
            booking.flightNumber = nil
            booking.departureAirport = nil
            booking.arrivalAirport = nil
            booking.departureTime = nil
            booking.arrivalTime = nil
        case .carRental:
            booking.departureTime = hasDepartureTime ? departureTime : nil
            booking.arrivalTime = hasArrivalTime ? arrivalTime : nil
            // Clear other fields
            booking.airline = nil
            booking.flightNumber = nil
            booking.departureAirport = nil
            booking.arrivalAirport = nil
            booking.hotelName = nil
            booking.hotelAddress = nil
            booking.checkInDate = nil
            booking.checkOutDate = nil
        case .other:
            booking.airline = nil
            booking.flightNumber = nil
            booking.departureAirport = nil
            booking.arrivalAirport = nil
            booking.departureTime = nil
            booking.arrivalTime = nil
            booking.hotelName = nil
            booking.hotelAddress = nil
            booking.checkInDate = nil
            booking.checkOutDate = nil
        }

        booking.trip?.updatedAt = Date()
        try? viewContext.save()
        dismiss()
    }
}
