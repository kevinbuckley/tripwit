import Testing
import CoreData
import Foundation
import TripCore

@testable import TripWit

/// Creates an in-memory Core Data stack for testing.
private func makeTestContext() -> NSManagedObjectContext {
    let controller = PersistenceController(inMemory: true)
    return controller.viewContext
}

@Test func tripEntityCanBeCreated() {
    let context = makeTestContext()
    let trip = TripEntity.create(
        in: context,
        name: "Test Trip",
        destination: "Test City",
        startDate: Date(),
        endDate: Date().addingTimeInterval(86400 * 3),
        status: .planning,
        notes: "Test notes"
    )
    #expect(trip.wrappedName == "Test Trip")
    #expect(trip.destination == "Test City")
    #expect(trip.status == .planning)
    #expect(trip.notes == "Test notes")
}

@Test func tripEntityComputedProperties() {
    let context = makeTestContext()
    let calendar = Calendar.current
    let start = calendar.date(from: DateComponents(year: 2026, month: 6, day: 1))!
    let end = calendar.date(from: DateComponents(year: 2026, month: 6, day: 5))!

    let trip = TripEntity.create(
        in: context,
        name: "Duration Test",
        destination: "Somewhere",
        startDate: start,
        endDate: end
    )
    #expect(trip.durationInDays == 5)
}

@Test func stopEntityCategoryRoundTrips() {
    let context = makeTestContext()
    let stop = StopEntity.create(
        in: context,
        name: "Test Stop",
        latitude: 35.6762,
        longitude: 139.6503,
        category: .restaurant,
        sortOrder: 0
    )
    #expect(stop.category == .restaurant)
    #expect(stop.categoryRaw == "restaurant")

    stop.category = .attraction
    #expect(stop.categoryRaw == "attraction")
}

@Test func dayEntityFormattedDate() {
    let context = makeTestContext()
    let calendar = Calendar.current
    let date = calendar.date(from: DateComponents(year: 2026, month: 3, day: 15))!
    let day = DayEntity.create(in: context, date: date, dayNumber: 1)
    #expect(!day.formattedDate.isEmpty)
    #expect(day.dayNumber == 1)
}

@Test func stopEntityVisitedDefaults() {
    let context = makeTestContext()
    let stop = StopEntity.create(
        in: context,
        name: "Visit Test",
        latitude: 40.7128,
        longitude: -74.0060,
        category: .attraction,
        sortOrder: 0
    )
    #expect(stop.isVisited == false)
    #expect(stop.visitedAt == nil)
}

@Test func stopEntityVisitedToggle() {
    let context = makeTestContext()
    let stop = StopEntity.create(
        in: context,
        name: "Toggle Test",
        latitude: 48.8566,
        longitude: 2.3522,
        category: .restaurant,
        sortOrder: 0
    )
    stop.isVisited = true
    stop.visitedAt = Date()
    #expect(stop.isVisited == true)
    #expect(stop.visitedAt != nil)

    stop.isVisited = false
    stop.visitedAt = nil
    #expect(stop.isVisited == false)
    #expect(stop.visitedAt == nil)
}

@Test func stopEntityVisitedInit() {
    let context = makeTestContext()
    let now = Date()
    let stop = StopEntity.create(
        in: context,
        name: "Pre-visited",
        latitude: 51.5074,
        longitude: -0.1278,
        category: .accommodation,
        sortOrder: 0,
        isVisited: true,
        visitedAt: now
    )
    #expect(stop.isVisited == true)
    #expect(stop.visitedAt == now)
}

@Test func tripStatusConversion() {
    let context = makeTestContext()
    let trip = TripEntity.create(
        in: context,
        name: "Status Test",
        destination: "Nowhere",
        startDate: Date(),
        endDate: Date()
    )
    #expect(trip.status == .planning)
    #expect(trip.statusRaw == "planning")

    trip.status = .active
    #expect(trip.statusRaw == "active")

    trip.status = .completed
    #expect(trip.statusRaw == "completed")
}
