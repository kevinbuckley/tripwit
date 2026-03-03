import CoreData
import Foundation

@objc(BookingEntity)
public class BookingEntity: NSManagedObject {
    @NSManaged public var id: UUID?
    @NSManaged public var typeRaw: String?
    @NSManaged public var title: String?
    @NSManaged public var confirmationCode: String?
    @NSManaged public var notes: String?
    @NSManaged public var sortOrder: Int32
    @NSManaged public var airline: String?
    @NSManaged public var flightNumber: String?
    @NSManaged public var departureAirport: String?
    @NSManaged public var arrivalAirport: String?
    @NSManaged public var departureTime: Date?
    @NSManaged public var arrivalTime: Date?
    @NSManaged public var hotelName: String?
    @NSManaged public var hotelAddress: String?
    @NSManaged public var checkInDate: Date?
    @NSManaged public var checkOutDate: Date?
    @NSManaged public var trip: TripEntity?
}

extension BookingEntity: Identifiable {}

extension BookingEntity {
    // MARK: - Safe accessors (non-optional wrappers)
    var wrappedTypeRaw: String { typeRaw ?? "other" }
    var wrappedTitle: String { title ?? "" }
    var wrappedConfirmationCode: String { confirmationCode ?? "" }
    var wrappedNotes: String { notes ?? "" }

    var bookingType: BookingType {
        get { BookingType(rawValue: wrappedTypeRaw) ?? .other }
        set { typeRaw = newValue.rawValue }
    }

    @discardableResult
    static func create(
        in context: NSManagedObjectContext,
        type: BookingType,
        title: String,
        confirmationCode: String = "",
        notes: String = "",
        sortOrder: Int = 0
    ) -> BookingEntity {
        let booking = BookingEntity(context: context)
        booking.id = UUID()
        booking.typeRaw = type.rawValue
        booking.title = title
        booking.confirmationCode = confirmationCode
        booking.notes = notes
        booking.sortOrder = Int32(sortOrder)
        return booking
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
