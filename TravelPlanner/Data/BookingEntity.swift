import SwiftData
import Foundation

/// Represents a flight, hotel, or other booking tied to a trip.
@Model
final class BookingEntity {

    // MARK: Stored Properties

    var id: UUID
    var typeRaw: String  // "flight", "hotel", "car_rental", "other"
    var title: String
    var confirmationCode: String
    var notes: String
    var sortOrder: Int

    // Flight-specific
    var airline: String?
    var flightNumber: String?
    var departureAirport: String?
    var arrivalAirport: String?
    var departureTime: Date?
    var arrivalTime: Date?

    // Hotel-specific
    var hotelName: String?
    var hotelAddress: String?
    var checkInDate: Date?
    var checkOutDate: Date?

    var trip: TripEntity?

    // MARK: Computed Properties

    var bookingType: BookingType {
        get { BookingType(rawValue: typeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    // MARK: Initializer

    init(
        type: BookingType,
        title: String,
        confirmationCode: String = "",
        notes: String = "",
        sortOrder: Int = 0
    ) {
        self.id = UUID()
        self.typeRaw = type.rawValue
        self.title = title
        self.confirmationCode = confirmationCode
        self.notes = notes
        self.sortOrder = sortOrder
    }
}

// MARK: - BookingType

enum BookingType: String, Codable, CaseIterable {
    case flight
    case hotel
    case carRental = "car_rental"
    case other

    var label: String {
        switch self {
        case .flight: "Flight"
        case .hotel: "Hotel"
        case .carRental: "Car Rental"
        case .other: "Other"
        }
    }

    var icon: String {
        switch self {
        case .flight: "airplane"
        case .hotel: "bed.double.fill"
        case .carRental: "car.fill"
        case .other: "doc.text"
        }
    }

    var color: String {
        switch self {
        case .flight: "blue"
        case .hotel: "purple"
        case .carRental: "orange"
        case .other: "gray"
        }
    }
}
