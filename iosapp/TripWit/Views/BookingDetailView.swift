import SwiftUI

struct BookingDetailView: View {

    @ObservedObject var booking: BookingEntity
    @State private var showingEditBooking = false

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }

    private var dateOnlyFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }

    var body: some View {
        if booking.isDeleted || booking.managedObjectContext == nil {
            VStack(spacing: 16) {
                Image(systemName: "trash.circle")
                    .font(.system(size: 48))
                    .foregroundStyle(.secondary)
                Text("Booking No Longer Available")
                    .font(.title3)
                    .fontWeight(.semibold)
                Text("This booking may have been deleted.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding()
            .navigationTitle("Removed")
        } else {
            bookingContent
        }
    }

    private var bookingContent: some View {
        List {
            // Header
            Section {
                HStack(spacing: 12) {
                    Image(systemName: booking.bookingType.icon)
                        .font(.title2)
                        .foregroundStyle(iconColor)
                        .frame(width: 44, height: 44)
                        .background(iconColor.opacity(0.15))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                    VStack(alignment: .leading, spacing: 2) {
                        Text(booking.wrappedTitle)
                            .font(.headline)
                        Text(booking.bookingType.label)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 4)

                if !booking.wrappedConfirmationCode.isEmpty {
                    HStack {
                        Text("Confirmation")
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text(booking.wrappedConfirmationCode)
                            .font(.body.monospaced())
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                            .textSelection(.enabled)
                    }
                }
            }

            // Type-specific details
            switch booking.bookingType {
            case .flight:
                flightSection
            case .hotel:
                hotelSection
            case .carRental:
                carRentalSection
            case .other:
                EmptyView()
            }

            // Notes
            if !booking.wrappedNotes.isEmpty {
                Section {
                    Text(booking.wrappedNotes)
                        .font(.body)
                        .foregroundStyle(.secondary)
                } header: {
                    Text("Notes")
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle(booking.wrappedTitle)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button("Edit") {
                    showingEditBooking = true
                }
            }
        }
        .sheet(isPresented: $showingEditBooking) {
            EditBookingSheet(booking: booking)
        }
    }

    // MARK: - Flight

    private var flightSection: some View {
        Section {
            if let airline = booking.airline, !airline.isEmpty {
                LabeledContent("Airline", value: airline)
            }
            if let flightNum = booking.flightNumber, !flightNum.isEmpty {
                LabeledContent("Flight", value: flightNum)
            }

            if let dep = booking.departureAirport, let arr = booking.arrivalAirport,
               !dep.isEmpty, !arr.isEmpty {
                HStack {
                    VStack(spacing: 4) {
                        Text(dep)
                            .font(.title2.bold())
                        if let time = booking.departureTime {
                            Text(dateFormatter.string(from: time))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Image(systemName: "airplane")
                        .font(.title3)
                        .foregroundStyle(.blue)

                    VStack(spacing: 4) {
                        Text(arr)
                            .font(.title2.bold())
                        if let time = booking.arrivalTime {
                            Text(dateFormatter.string(from: time))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .frame(maxWidth: .infinity)
                }
                .padding(.vertical, 8)
            } else {
                if let dep = booking.departureAirport, !dep.isEmpty {
                    LabeledContent("From", value: dep)
                }
                if let arr = booking.arrivalAirport, !arr.isEmpty {
                    LabeledContent("To", value: arr)
                }
                if let time = booking.departureTime {
                    LabeledContent("Departure", value: dateFormatter.string(from: time))
                }
                if let time = booking.arrivalTime {
                    LabeledContent("Arrival", value: dateFormatter.string(from: time))
                }
            }
        } header: {
            Text("Flight Details")
        }
    }

    // MARK: - Hotel

    private var hotelSection: some View {
        Section {
            if let name = booking.hotelName, !name.isEmpty {
                LabeledContent("Hotel", value: name)
            }
            if let address = booking.hotelAddress, !address.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Address")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(address)
                }
            }
            if let checkIn = booking.checkInDate {
                LabeledContent("Check-in", value: dateOnlyFormatter.string(from: checkIn))
            }
            if let checkOut = booking.checkOutDate {
                LabeledContent("Check-out", value: dateOnlyFormatter.string(from: checkOut))
            }
            if let checkIn = booking.checkInDate, let checkOut = booking.checkOutDate {
                let nights = Calendar.current.dateComponents([.day], from: checkIn, to: checkOut).day ?? 0
                LabeledContent("Duration", value: "\(nights) night\(nights == 1 ? "" : "s")")
            }
        } header: {
            Text("Hotel Details")
        }
    }

    // MARK: - Car Rental

    private var carRentalSection: some View {
        Section {
            if let pickup = booking.departureTime {
                LabeledContent("Pickup", value: dateFormatter.string(from: pickup))
            }
            if let returnTime = booking.arrivalTime {
                LabeledContent("Return", value: dateFormatter.string(from: returnTime))
            }
        } header: {
            Text("Rental Details")
        }
    }

    private var iconColor: Color {
        switch booking.bookingType {
        case .flight: .blue
        case .hotel: .purple
        case .carRental: .orange
        case .other: .gray
        }
    }
}
