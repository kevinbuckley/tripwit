import Foundation
import HealthKit
import Observation

// MARK: - Value Type

/// Step count data for a single calendar day, with goal tracking.
struct DayStepCount {
    let date: Date
    let steps: Int
    let goal: Int

    static let defaultGoal = 8_000

    /// Fraction of goal reached, clamped 0…1. Returns 0 when goal is not set.
    var percentage: Double {
        guard goal > 0 else { return 0 }
        return min(Double(steps) / Double(goal), 1.0)
    }

    /// True when step count meets or exceeds the goal.
    var goalMet: Bool { steps >= goal }
}

// MARK: - Store Protocol (enables injection / testing)

protocol StepCountStoreProtocol: Sendable {
    var isAvailable: Bool { get }
    func requestAuthorization() async throws
    /// Sum of steps for the given calendar day in the user's local timezone.
    func fetchDaySteps(for date: Date) async throws -> Int
}

// MARK: - HealthKit-backed Store

final class HKStepCountStore: StepCountStoreProtocol {
    private let store = HKHealthStore()
    private let stepType = HKQuantityType(.stepCount)

    var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    func requestAuthorization() async throws {
        try await store.requestAuthorization(toShare: [], read: [stepType])
    }

    func fetchDaySteps(for date: Date) async throws -> Int {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: date)
        guard let end = calendar.date(byAdding: .day, value: 1, to: start) else { return 0 }
        let predicate = HKQuery.predicateForSamples(withStart: start, end: end, options: .strictEndDate)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKStatisticsQuery(
                quantityType: stepType,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, stats, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                let count = stats?.sumQuantity()?.doubleValue(for: .count()) ?? 0
                continuation.resume(returning: Int(count))
            }
            store.execute(query)
        }
    }
}

// MARK: - Service

/// Manages HealthKit step count reads for trip days.
@MainActor
@Observable
final class StepCountService {

    // MARK: - State

    private(set) var stepsByDate: [Date: Int] = [:]
    var authorizationStatus: AuthStatus = .notDetermined
    private(set) var isFetching = false

    enum AuthStatus { case notDetermined, authorized, denied, unavailable }

    // MARK: - Configuration

    var dailyGoal: Int = DayStepCount.defaultGoal

    // MARK: - Init

    private let store: StepCountStoreProtocol

    init(store: StepCountStoreProtocol = HKStepCountStore()) {
        self.store = store
        if !store.isAvailable { authorizationStatus = .unavailable }
    }

    // MARK: - Authorization

    func requestAuthorization() async {
        guard store.isAvailable else {
            authorizationStatus = .unavailable
            return
        }
        do {
            try await store.requestAuthorization()
            authorizationStatus = .authorized
        } catch {
            authorizationStatus = .denied
        }
    }

    // MARK: - Fetching

    /// Loads step counts for all provided dates, merging into `stepsByDate`.
    func fetchSteps(for dates: [Date]) async {
        guard authorizationStatus == .authorized, !dates.isEmpty else { return }
        isFetching = true
        defer { isFetching = false }

        await withTaskGroup(of: (Date, Int).self) { group in
            for date in dates {
                group.addTask {
                    let steps = (try? await self.store.fetchDaySteps(for: date)) ?? 0
                    return (Calendar.current.startOfDay(for: date), steps)
                }
            }
            for await (day, count) in group {
                stepsByDate[day] = count
            }
        }
    }

    // MARK: - Lookup

    /// Returns a `DayStepCount` for `date`, using the stored step total if available.
    func stepCount(for date: Date) -> DayStepCount {
        let key = Calendar.current.startOfDay(for: date)
        return DayStepCount(date: key, steps: stepsByDate[key] ?? 0, goal: dailyGoal)
    }

    /// True when we have a stored reading for `date`.
    func hasData(for date: Date) -> Bool {
        let key = Calendar.current.startOfDay(for: date)
        return stepsByDate[key] != nil
    }
}
