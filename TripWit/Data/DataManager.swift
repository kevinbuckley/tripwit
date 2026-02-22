import CoreData
import SwiftUI
import Foundation
import TripCore

@Observable
final class DataManager {

    let context: NSManagedObjectContext

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    // MARK: - Trips

    func fetchTrips() -> [TripEntity] {
        let request = TripEntity.fetchRequest() as! NSFetchRequest<TripEntity>
        request.sortDescriptors = [NSSortDescriptor(keyPath: \TripEntity.startDate, ascending: false)]
        return (try? context.fetch(request)) ?? []
    }

    @discardableResult
    func createTrip(
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        notes: String = ""
    ) -> TripEntity {
        let trip = TripEntity.create(
            in: context,
            name: name,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            notes: notes
        )
        generateDays(for: trip)
        try? context.save()
        return trip
    }

    func updateTrip(_ trip: TripEntity) {
        trip.updatedAt = Date()
        try? context.save()
    }

    func deleteTrip(_ trip: TripEntity) {
        context.delete(trip)
        try? context.save()
    }

    // MARK: - Days

    func generateDays(for trip: TripEntity) {
        // Remove existing days
        for day in trip.daysArray {
            context.delete(day)
        }

        guard let tripStart = trip.startDate, let tripEnd = trip.endDate else { return }

        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: tripStart)
        let startOfEnd = calendar.startOfDay(for: tripEnd)

        var currentDate = startOfStart
        var dayNumber = 1

        while currentDate <= startOfEnd {
            let day = DayEntity.create(
                in: context,
                date: currentDate,
                dayNumber: dayNumber,
                location: trip.destination ?? ""
            )
            day.trip = trip
            dayNumber += 1
            guard let nextDate = calendar.date(byAdding: .day, value: 1, to: currentDate) else {
                break
            }
            currentDate = nextDate
        }
    }

    // MARK: - Stops

    @discardableResult
    func addStop(
        to day: DayEntity,
        name: String,
        latitude: Double,
        longitude: Double,
        category: StopCategory,
        notes: String = ""
    ) -> StopEntity {
        let sortOrder = day.stopsArray.count
        let stop = StopEntity.create(
            in: context,
            name: name,
            latitude: latitude,
            longitude: longitude,
            category: category,
            sortOrder: sortOrder,
            notes: notes
        )
        stop.day = day
        // Touch the trip so @ObservedObject triggers a refresh in TripDetailView
        day.trip?.updatedAt = Date()
        try? context.save()
        return stop
    }

    func deleteStop(_ stop: StopEntity) {
        stop.day?.trip?.updatedAt = Date()
        context.delete(stop)
        try? context.save()
    }

    func toggleVisited(_ stop: StopEntity) {
        stop.isVisited.toggle()
        stop.visitedAt = stop.isVisited ? Date() : nil
        stop.day?.trip?.updatedAt = Date()
        try? context.save()
    }

    func moveStop(_ stop: StopEntity, to targetDay: DayEntity) {
        if let currentDay = stop.day {
            currentDay.removeFromStops(stop)
        }
        stop.sortOrder = Int32(targetDay.stopsArray.count)
        stop.day = targetDay
        targetDay.trip?.updatedAt = Date()
        try? context.save()
    }

    func reorderStops(in day: DayEntity, from source: IndexSet, to destination: Int) {
        var stops = day.stopsArray
        stops.move(fromOffsets: source, toOffset: destination)
        for (index, stop) in stops.enumerated() {
            stop.sortOrder = Int32(index)
        }
        day.trip?.updatedAt = Date()
        try? context.save()
    }

    // MARK: - Expenses

    @discardableResult
    func addExpense(
        to trip: TripEntity,
        title: String,
        amount: Double,
        category: ExpenseCategory = .other,
        date: Date = Date(),
        notes: String = ""
    ) -> ExpenseEntity {
        let expense = ExpenseEntity.create(
            in: context,
            title: title,
            amount: amount,
            currencyCode: trip.budgetCurrencyCode ?? "USD",
            dateIncurred: date,
            category: category,
            notes: notes,
            sortOrder: trip.expensesArray.count
        )
        expense.trip = trip
        trip.updatedAt = Date()
        try? context.save()
        return expense
    }

    func deleteExpense(_ expense: ExpenseEntity) {
        expense.trip?.updatedAt = Date()
        context.delete(expense)
        try? context.save()
    }

    // MARK: - Sample Data

    func loadSampleDataIfEmpty() {
        let request = TripEntity.fetchRequest() as! NSFetchRequest<TripEntity>
        let count = (try? context.count(for: request)) ?? 0
        guard count == 0 else { return }

        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        func daysFromNow(_ offset: Int) -> Date {
            calendar.date(byAdding: .day, value: offset, to: today) ?? today
        }

        // Paris Getaway — active trip
        let paris = TripEntity.create(
            in: context,
            name: "Paris Getaway",
            destination: "Paris, France",
            startDate: daysFromNow(-1),
            endDate: daysFromNow(3),
            status: .active,
            notes: "A romantic few days exploring the City of Light"
        )
        generateDays(for: paris)

        if let parisDay1 = paris.daysArray.first(where: { $0.dayNumber == 1 }) {
            parisDay1.notes = "Explore the city center"
            addStop(to: parisDay1, name: "Eiffel Tower", latitude: 48.8584, longitude: 2.2945, category: .attraction)
            addStop(to: parisDay1, name: "Le Jules Verne", latitude: 48.8583, longitude: 2.2944, category: .restaurant)
        }

        if let parisDay2 = paris.daysArray.first(where: { $0.dayNumber == 2 }) {
            parisDay2.notes = "Art and culture"
            addStop(to: parisDay2, name: "Louvre Museum", latitude: 48.8606, longitude: 2.3376, category: .attraction)
            addStop(to: parisDay2, name: "Café de Flore", latitude: 48.8540, longitude: 2.3325, category: .restaurant)
        }

        let parisHotel = BookingEntity.create(in: context, type: .hotel, title: "Hôtel Le Marais", confirmationCode: "HLM-28491")
        parisHotel.hotelName = "Hôtel Le Marais"
        parisHotel.hotelAddress = "12 Rue des Archives, 75004 Paris"
        parisHotel.checkInDate = daysFromNow(-1)
        parisHotel.checkOutDate = daysFromNow(3)
        parisHotel.trip = paris

        // Japan Adventure — upcoming trip
        let japan = TripEntity.create(
            in: context,
            name: "Japan Adventure",
            destination: "Japan",
            startDate: daysFromNow(30),
            endDate: daysFromNow(37),
            status: .planning,
            notes: "Cherry blossom season trip — Tokyo & Kyoto"
        )
        generateDays(for: japan)

        for day in japan.daysArray {
            if day.dayNumber <= 4 {
                day.location = "Tokyo, Japan"
            } else {
                day.location = "Kyoto, Japan"
            }
        }

        if let day1 = japan.daysArray.first(where: { $0.dayNumber == 1 }) {
            day1.notes = "Arrival day"
            addStop(to: day1, name: "Narita Airport", latitude: 35.7720, longitude: 140.3929, category: .transport)
            addStop(to: day1, name: "Shinjuku Hotel", latitude: 35.6938, longitude: 139.7034, category: .accommodation)
        }

        if let day2 = japan.daysArray.first(where: { $0.dayNumber == 2 }) {
            day2.notes = "Temple and garden visits"
            addStop(to: day2, name: "Senso-ji Temple", latitude: 35.7148, longitude: 139.7967, category: .attraction)
            addStop(to: day2, name: "Tsukiji Outer Market", latitude: 35.6654, longitude: 139.7707, category: .restaurant)
        }

        if let day5 = japan.daysArray.first(where: { $0.dayNumber == 5 }) {
            day5.notes = "Train to Kyoto, explore temples"
            addStop(to: day5, name: "Shinkansen to Kyoto", latitude: 35.6812, longitude: 139.7671, category: .transport)
            addStop(to: day5, name: "Fushimi Inari Shrine", latitude: 34.9671, longitude: 135.7727, category: .attraction)
        }

        // NYC Weekend — completed trip
        let nyc = TripEntity.create(
            in: context,
            name: "New York City Weekend",
            destination: "New York, USA",
            startDate: daysFromNow(-18),
            endDate: daysFromNow(-14),
            status: .completed,
            notes: "Holiday shopping and sightseeing"
        )
        generateDays(for: nyc)

        try? context.save()
    }
}
