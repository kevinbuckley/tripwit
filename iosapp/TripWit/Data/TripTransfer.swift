import Foundation

// MARK: - Trip Transfer (Codable serialization for .tripwit file sharing)

struct TripTransfer: Codable {
    static let currentSchemaVersion = 2

    var schemaVersion: Int
    var name: String
    var destination: String
    var startDate: Date
    var endDate: Date
    var statusRaw: String
    var notes: String
    var hasCustomDates: Bool
    var budgetAmount: Double
    var budgetCurrencyCode: String
    var days: [DayTransfer]
    var bookings: [BookingTransfer]
    var lists: [ListTransfer]
    var expenses: [ExpenseTransfer]
}

extension TripTransfer: Identifiable {
    var id: String { "\(name)-\(startDate.timeIntervalSince1970)" }
}

struct DayTransfer: Codable {
    var date: Date
    var dayNumber: Int
    var notes: String
    var location: String
    var locationLatitude: Double
    var locationLongitude: Double
    var stops: [StopTransfer]
}

struct StopTransfer: Codable {
    var name: String
    var latitude: Double
    var longitude: Double
    var arrivalTime: Date?
    var departureTime: Date?
    var categoryRaw: String
    var notes: String
    var sortOrder: Int
    var isVisited: Bool
    var visitedAt: Date?
    var rating: Int
    var address: String?
    var phone: String?
    var website: String?
    var comments: [CommentTransfer]
    // Added in schema v1 — defaults ensure old files without these fields still decode
    var links: [StopLinkTransfer] = []
    var todos: [StopTodoTransfer] = []
    // Added in schema v2 — booking fields for unified stops
    var confirmationCode: String? = nil
    var checkOutDate: Date? = nil
    var airline: String? = nil
    var flightNumber: String? = nil
    var departureAirport: String? = nil
    var arrivalAirport: String? = nil
}

struct CommentTransfer: Codable {
    var text: String
    var createdAt: Date
}

struct StopLinkTransfer: Codable {
    var title: String
    var url: String
    var sortOrder: Int
}

struct StopTodoTransfer: Codable {
    var text: String
    var isCompleted: Bool
    var sortOrder: Int
}

struct BookingTransfer: Codable {
    var typeRaw: String
    var title: String
    var confirmationCode: String
    var notes: String
    var sortOrder: Int
    var airline: String?
    var flightNumber: String?
    var departureAirport: String?
    var arrivalAirport: String?
    var departureTime: Date?
    var arrivalTime: Date?
    var hotelName: String?
    var hotelAddress: String?
    var checkInDate: Date?
    var checkOutDate: Date?
}

struct ListTransfer: Codable {
    var name: String
    var icon: String
    var sortOrder: Int
    var items: [ListItemTransfer]
}

struct ListItemTransfer: Codable {
    var text: String
    var isChecked: Bool
    var sortOrder: Int
}

struct ExpenseTransfer: Codable {
    var title: String
    var amount: Double
    var currencyCode: String
    var dateIncurred: Date
    var categoryRaw: String
    var notes: String
    var sortOrder: Int
    var createdAt: Date
}
