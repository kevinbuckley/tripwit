import SwiftUI
import CoreData

struct AddBookingSheet: View {

    @Environment(\.managedObjectContext) private var viewContext
    @Environment(\.dismiss) private var dismiss

    let trip: TripEntity

    @State private var bookingType: BookingType = .flight
    @State private var title = ""
    @State private var confirmationCode = ""
    @State private var notes = ""

    // Flight fields
    @State private var airline = ""
    @State private var flightNumber = ""
    @State private var departureAirport = ""
    @State private var arrivalAirport = ""
    @State private var departureTime = Date()
    @State private var arrivalTime = Date()
    @State private var hasDepartureTime = false
    @State private var hasArrivalTime = false

    // Hotel fields
    @State private var hotelName = ""
    @State private var hotelAddress = ""
    @State private var checkInDate = Date()
    @State private var checkOutDate = Date()

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
            .navigationTitle("Add Booking")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") { save() }
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
        let booking = BookingEntity.create(
            in: viewContext,
            type: bookingType,
            title: title.trimmingCharacters(in: .whitespaces),
            confirmationCode: confirmationCode.trimmingCharacters(in: .whitespaces),
            notes: notes.trimmingCharacters(in: .whitespaces),
            sortOrder: trip.bookingsArray.count
        )

        switch bookingType {
        case .flight:
            booking.airline = airline.isEmpty ? nil : airline
            booking.flightNumber = flightNumber.isEmpty ? nil : flightNumber
            booking.departureAirport = departureAirport.isEmpty ? nil : departureAirport
            booking.arrivalAirport = arrivalAirport.isEmpty ? nil : arrivalAirport
            booking.departureTime = hasDepartureTime ? departureTime : nil
            booking.arrivalTime = hasArrivalTime ? arrivalTime : nil
        case .hotel:
            booking.hotelName = hotelName.isEmpty ? nil : hotelName
            booking.hotelAddress = hotelAddress.isEmpty ? nil : hotelAddress
            booking.checkInDate = checkInDate
            booking.checkOutDate = checkOutDate
        case .carRental:
            booking.departureTime = hasDepartureTime ? departureTime : nil
            booking.arrivalTime = hasArrivalTime ? arrivalTime : nil
        case .other:
            break
        }

        booking.trip = trip
        trip.updatedAt = Date()
        try? viewContext.save()
        dismiss()
    }
}
