import Foundation
import CoreData
import TripCore

struct TripShareService {

    // MARK: - Export (Entity → .tripwit file)

    static func exportTrip(_ trip: TripEntity) throws -> URL {
        let transfer = TripTransfer(
            schemaVersion: TripTransfer.currentSchemaVersion,
            name: trip.wrappedName,
            destination: trip.wrappedDestination,
            startDate: trip.wrappedStartDate,
            endDate: trip.wrappedEndDate,
            statusRaw: trip.wrappedStatusRaw,
            notes: trip.wrappedNotes,
            hasCustomDates: trip.hasCustomDates,
            budgetAmount: trip.budgetAmount,
            budgetCurrencyCode: trip.wrappedBudgetCurrencyCode,
            days: trip.daysArray.map { day in
                DayTransfer(
                    date: day.wrappedDate,
                    dayNumber: Int(day.dayNumber),
                    notes: day.wrappedNotes,
                    location: day.wrappedLocation,
                    locationLatitude: day.locationLatitude,
                    locationLongitude: day.locationLongitude,
                    stops: day.stopsArray.map { stop in
                        StopTransfer(
                            name: stop.wrappedName,
                            latitude: stop.latitude,
                            longitude: stop.longitude,
                            arrivalTime: stop.arrivalTime,
                            departureTime: stop.departureTime,
                            categoryRaw: stop.wrappedCategoryRaw,
                            notes: stop.wrappedNotes,
                            sortOrder: Int(stop.sortOrder),
                            isVisited: stop.isVisited,
                            visitedAt: stop.visitedAt,
                            rating: Int(stop.rating),
                            address: stop.address,
                            phone: stop.phone,
                            website: stop.website,
                            comments: stop.commentsArray.map { c in
                                CommentTransfer(text: c.wrappedText, createdAt: c.wrappedCreatedAt)
                            }
                        )
                    }
                )
            },
            bookings: trip.bookingsArray.map { b in
                BookingTransfer(
                    typeRaw: b.wrappedTypeRaw,
                    title: b.wrappedTitle,
                    confirmationCode: b.wrappedConfirmationCode,
                    notes: b.wrappedNotes,
                    sortOrder: Int(b.sortOrder),
                    airline: b.airline,
                    flightNumber: b.flightNumber,
                    departureAirport: b.departureAirport,
                    arrivalAirport: b.arrivalAirport,
                    departureTime: b.departureTime,
                    arrivalTime: b.arrivalTime,
                    hotelName: b.hotelName,
                    hotelAddress: b.hotelAddress,
                    checkInDate: b.checkInDate,
                    checkOutDate: b.checkOutDate
                )
            },
            lists: trip.listsArray.map { list in
                ListTransfer(
                    name: list.wrappedName,
                    icon: list.wrappedIcon,
                    sortOrder: Int(list.sortOrder),
                    items: list.itemsArray.map { item in
                        ListItemTransfer(text: item.wrappedText, isChecked: item.isChecked, sortOrder: Int(item.sortOrder))
                    }
                )
            },
            expenses: trip.expensesArray.map { e in
                ExpenseTransfer(
                    title: e.wrappedTitle,
                    amount: e.amount,
                    currencyCode: e.wrappedCurrencyCode,
                    dateIncurred: e.wrappedDateIncurred,
                    categoryRaw: e.wrappedCategoryRaw,
                    notes: e.wrappedNotes,
                    sortOrder: Int(e.sortOrder),
                    createdAt: e.wrappedCreatedAt
                )
            }
        )

        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(transfer)

        let sanitized = trip.wrappedName
            .components(separatedBy: CharacterSet.alphanumerics.inverted)
            .joined(separator: "_")
        let url = FileManager.default.temporaryDirectory.appendingPathComponent("\(sanitized).tripwit")
        try data.write(to: url)
        return url
    }

    // MARK: - Decode (File → Transfer struct for preview)

    static func decodeTrip(from url: URL) throws -> TripTransfer {
        let accessing = url.startAccessingSecurityScopedResource()
        defer { if accessing { url.stopAccessingSecurityScopedResource() } }

        let data = try Data(contentsOf: url)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(TripTransfer.self, from: data)
    }

    // MARK: - Import (Transfer → new Entities)

    @discardableResult
    static func importTrip(_ transfer: TripTransfer, into context: NSManagedObjectContext) -> TripEntity {
        let trip = TripEntity.create(
            in: context,
            name: transfer.name,
            destination: transfer.destination,
            startDate: transfer.startDate,
            endDate: transfer.endDate,
            notes: transfer.notes
        )
        trip.statusRaw = transfer.statusRaw
        trip.hasCustomDates = transfer.hasCustomDates
        trip.budgetAmount = transfer.budgetAmount
        trip.budgetCurrencyCode = transfer.budgetCurrencyCode

        for dayT in transfer.days {
            let day = DayEntity.create(
                in: context,
                date: dayT.date,
                dayNumber: dayT.dayNumber,
                notes: dayT.notes,
                location: dayT.location,
                locationLatitude: dayT.locationLatitude,
                locationLongitude: dayT.locationLongitude
            )
            day.trip = trip

            for stopT in dayT.stops {
                let stop = StopEntity.create(
                    in: context,
                    name: stopT.name,
                    latitude: stopT.latitude,
                    longitude: stopT.longitude,
                    category: StopCategory(rawValue: stopT.categoryRaw) ?? .other,
                    arrivalTime: stopT.arrivalTime,
                    departureTime: stopT.departureTime,
                    sortOrder: stopT.sortOrder,
                    notes: stopT.notes,
                    isVisited: stopT.isVisited,
                    visitedAt: stopT.visitedAt,
                    address: stopT.address,
                    phone: stopT.phone,
                    website: stopT.website
                )
                stop.rating = Int32(stopT.rating)
                stop.day = day

                for commentT in stopT.comments {
                    let comment = CommentEntity.create(in: context, text: commentT.text)
                    comment.createdAt = commentT.createdAt
                    comment.stop = stop
                }
            }
        }

        for bkT in transfer.bookings {
            let booking = BookingEntity.create(
                in: context,
                type: BookingType(rawValue: bkT.typeRaw) ?? .other,
                title: bkT.title,
                confirmationCode: bkT.confirmationCode,
                notes: bkT.notes,
                sortOrder: bkT.sortOrder
            )
            booking.airline = bkT.airline
            booking.flightNumber = bkT.flightNumber
            booking.departureAirport = bkT.departureAirport
            booking.arrivalAirport = bkT.arrivalAirport
            booking.departureTime = bkT.departureTime
            booking.arrivalTime = bkT.arrivalTime
            booking.hotelName = bkT.hotelName
            booking.hotelAddress = bkT.hotelAddress
            booking.checkInDate = bkT.checkInDate
            booking.checkOutDate = bkT.checkOutDate
            booking.trip = trip
        }

        for listT in transfer.lists {
            let list = TripListEntity.create(
                in: context,
                name: listT.name,
                icon: listT.icon,
                sortOrder: listT.sortOrder
            )
            list.trip = trip

            for itemT in listT.items {
                let item = TripListItemEntity.create(
                    in: context,
                    text: itemT.text,
                    sortOrder: itemT.sortOrder
                )
                item.isChecked = itemT.isChecked
                item.list = list
            }
        }

        for expT in transfer.expenses {
            let expense = ExpenseEntity.create(
                in: context,
                title: expT.title,
                amount: expT.amount,
                currencyCode: expT.currencyCode,
                dateIncurred: expT.dateIncurred,
                category: ExpenseCategory(rawValue: expT.categoryRaw) ?? .other,
                notes: expT.notes,
                sortOrder: expT.sortOrder
            )
            expense.trip = trip
        }

        try? context.save()
        return trip
    }
}
