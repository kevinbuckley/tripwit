import SwiftData
import SwiftUI
import Foundation
import TripCore

@Observable
final class DataManager {

    let modelContext: ModelContext

    init(modelContext: ModelContext) {
        self.modelContext = modelContext
    }

    // MARK: - Trips

    func fetchTrips() -> [TripEntity] {
        let sort = SortDescriptor(\TripEntity.startDate, order: .reverse)
        let descriptor = FetchDescriptor<TripEntity>(sortBy: [sort])
        return (try? modelContext.fetch(descriptor)) ?? []
    }

    @discardableResult
    func createTrip(
        name: String,
        destination: String,
        startDate: Date,
        endDate: Date,
        notes: String = ""
    ) -> TripEntity {
        let trip = TripEntity(
            name: name,
            destination: destination,
            startDate: startDate,
            endDate: endDate,
            notes: notes
        )
        modelContext.insert(trip)
        generateDays(for: trip)
        try? modelContext.save()
        return trip
    }

    func updateTrip(_ trip: TripEntity) {
        trip.updatedAt = Date()
        try? modelContext.save()
    }

    func deleteTrip(_ trip: TripEntity) {
        modelContext.delete(trip)
        try? modelContext.save()
    }

    // MARK: - Days

    /// Delete existing days and create new ones based on the trip's date range.
    /// Uses the same logic as ItineraryEngine.generateDays.
    func generateDays(for trip: TripEntity) {
        // Remove existing days
        for day in trip.days {
            modelContext.delete(day)
        }
        trip.days.removeAll()

        let calendar = Calendar.current
        let startOfStart = calendar.startOfDay(for: trip.startDate)
        let startOfEnd = calendar.startOfDay(for: trip.endDate)

        var currentDate = startOfStart
        var dayNumber = 1

        while currentDate <= startOfEnd {
            let day = DayEntity(date: currentDate, dayNumber: dayNumber)
            day.trip = trip
            trip.days.append(day)
            modelContext.insert(day)
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
        let sortOrder = day.stops.count
        let stop = StopEntity(
            name: name,
            latitude: latitude,
            longitude: longitude,
            category: category,
            sortOrder: sortOrder,
            notes: notes
        )
        stop.day = day
        day.stops.append(stop)
        modelContext.insert(stop)
        try? modelContext.save()
        return stop
    }

    func deleteStop(_ stop: StopEntity) {
        modelContext.delete(stop)
        try? modelContext.save()
    }

    func toggleVisited(_ stop: StopEntity) {
        stop.isVisited.toggle()
        stop.visitedAt = stop.isVisited ? Date() : nil
        try? modelContext.save()
    }

    func reorderStops(in day: DayEntity, from source: IndexSet, to destination: Int) {
        var stops = day.stops.sorted { $0.sortOrder < $1.sortOrder }
        stops.move(fromOffsets: source, toOffset: destination)
        for (index, stop) in stops.enumerated() {
            stop.sortOrder = index
        }
        try? modelContext.save()
    }

    // MARK: - Sample Data

    /// If no trips exist, create sample trips for demo purposes.
    func loadSampleDataIfEmpty() {
        let descriptor = FetchDescriptor<TripEntity>()
        let count = (try? modelContext.fetchCount(descriptor)) ?? 0
        guard count == 0 else { return }

        let calendar = Calendar.current

        func date(year: Int, month: Int, day: Int) -> Date {
            calendar.date(from: DateComponents(year: year, month: month, day: day))!
        }

        // Tokyo Adventure
        let tokyo = TripEntity(
            name: "Tokyo Adventure",
            destination: "Tokyo, Japan",
            startDate: date(year: 2026, month: 4, day: 10),
            endDate: date(year: 2026, month: 4, day: 17),
            status: .planning,
            notes: "Cherry blossom season trip"
        )
        modelContext.insert(tokyo)
        generateDays(for: tokyo)

        // Add stops to Tokyo Day 1
        if let tokyoDay1 = tokyo.days.first(where: { $0.dayNumber == 1 }) {
            tokyoDay1.notes = "Arrival day"
            addStop(
                to: tokyoDay1,
                name: "Narita Airport",
                latitude: 35.7720,
                longitude: 140.3929,
                category: .transport
            )
            addStop(
                to: tokyoDay1,
                name: "Shinjuku Hotel",
                latitude: 35.6938,
                longitude: 139.7034,
                category: .accommodation
            )
        }

        // Add stops to Tokyo Day 2
        if let tokyoDay2 = tokyo.days.first(where: { $0.dayNumber == 2 }) {
            tokyoDay2.notes = "Temple and garden visits"
            addStop(
                to: tokyoDay2,
                name: "Senso-ji Temple",
                latitude: 35.7148,
                longitude: 139.7967,
                category: .attraction
            )
            addStop(
                to: tokyoDay2,
                name: "Tsukiji Outer Market",
                latitude: 35.6654,
                longitude: 139.7707,
                category: .restaurant
            )
        }

        // Paris Getaway
        let paris = TripEntity(
            name: "Paris Getaway",
            destination: "Paris, France",
            startDate: date(year: 2026, month: 2, day: 10),
            endDate: date(year: 2026, month: 2, day: 14),
            status: .active,
            notes: "Valentine's week in Paris"
        )
        modelContext.insert(paris)
        generateDays(for: paris)

        if let parisDay1 = paris.days.first(where: { $0.dayNumber == 1 }) {
            parisDay1.notes = "Explore the city center"
            addStop(
                to: parisDay1,
                name: "Eiffel Tower",
                latitude: 48.8584,
                longitude: 2.2945,
                category: .attraction
            )
            addStop(
                to: parisDay1,
                name: "Le Jules Verne",
                latitude: 48.8583,
                longitude: 2.2944,
                category: .restaurant
            )
        }

        // NYC Weekend
        let nyc = TripEntity(
            name: "New York City Weekend",
            destination: "New York, USA",
            startDate: date(year: 2025, month: 12, day: 20),
            endDate: date(year: 2025, month: 12, day: 23),
            status: .completed,
            notes: "Holiday shopping and sightseeing"
        )
        modelContext.insert(nyc)
        generateDays(for: nyc)

        try? modelContext.save()
    }
}
