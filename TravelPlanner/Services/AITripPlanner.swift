import Foundation
import TripCore

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Generable Types for AI Suggestions

@available(iOS 26, *)
@Generable
struct SuggestedStop {
    @Guide(description: "The name of the place or attraction to visit")
    var name: String

    @Guide(description: "A short one-sentence description of why this is worth visiting")
    var reason: String

    @Guide(.anyOf(["accommodation", "restaurant", "attraction", "transport", "activity", "other"]))
    var category: String

    @Guide(description: "Suggested visit duration in minutes, e.g. 60 for one hour")
    var durationMinutes: Int
}

@available(iOS 26, *)
@Generable
struct StopSuggestions {
    @Guide(description: "A list of suggested stops to visit")
    var stops: [SuggestedStop]
}

// MARK: - AI Trip Planner Service

@available(iOS 26, *)
@Observable
final class AITripPlanner {

    var isGenerating = false
    var suggestions: [SuggestedStop] = []
    var errorMessage: String?

    private var session: LanguageModelSession?

    /// Check whether the on-device model is available on this device.
    var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    /// Generate stop suggestions for a specific day of a trip.
    func suggestStops(
        destination: String,
        dayNumber: Int,
        totalDays: Int,
        existingStops: [String],
        preferences: String = ""
    ) async {
        guard isAvailable else {
            errorMessage = "Apple Intelligence is not available on this device."
            return
        }

        isGenerating = true
        suggestions = []
        errorMessage = nil

        let existingList = existingStops.isEmpty
            ? "None yet"
            : existingStops.joined(separator: ", ")

        let preferenceLine = preferences.isEmpty
            ? ""
            : "\nTravel preferences: \(preferences)"

        let prompt = """
        You are a travel planning assistant. Suggest 5 great stops to visit \
        in \(destination) for Day \(dayNumber) of a \(totalDays)-day trip.

        Already planned stops: \(existingList)
        Do NOT suggest places that duplicate existing stops.\(preferenceLine)

        Mix categories: include restaurants, attractions, and activities. \
        Suggest a realistic day with varied experiences. \
        Include local favorites, not just tourist traps.
        """

        do {
            let plannerSession = LanguageModelSession {
                """
                You are an expert travel planner. You suggest specific, real places \
                with accurate category classifications. Keep suggestions practical \
                and focused on the destination city. Suggest real place names, not \
                generic descriptions.
                """
            }
            session = plannerSession

            let result = try await plannerSession.respond(
                to: prompt,
                generating: StopSuggestions.self
            )
            suggestions = result.content.stops
        } catch {
            errorMessage = "Could not generate suggestions. Please try again."
        }

        isGenerating = false
    }

    /// Generate nearby suggestions based on a specific stop's location.
    func suggestNearby(
        stopName: String,
        stopCategory: String,
        latitude: Double,
        longitude: Double,
        existingStops: [String]
    ) async {
        guard isAvailable else {
            errorMessage = "Apple Intelligence is not available on this device."
            return
        }

        isGenerating = true
        suggestions = []
        errorMessage = nil

        let existingList = existingStops.isEmpty
            ? "None"
            : existingStops.joined(separator: ", ")

        let prompt = """
        I am currently at \(stopName) (a \(stopCategory)) located at \
        coordinates \(latitude), \(longitude).

        Suggest 5 highly-rated places that are within 1 mile (1.6 km) of \
        my current location. Everything must be walkable — no driving. \
        Focus on:
        - Great restaurants and cafés for a meal or snack
        - Notable attractions, landmarks, or hidden gems nearby
        - Fun activities in the immediate area

        IMPORTANT: Only suggest places that are within 1 mile / 1.6 km \
        walking distance from coordinates \(latitude), \(longitude). \
        Do NOT suggest anything farther away.

        Already planned stops (do NOT duplicate these): \(existingList)

        Prioritize places that are popular with locals, not just tourists. \
        Include a mix of food and things to see/do.
        """

        do {
            let nearbySession = LanguageModelSession {
                """
                You are a local expert guide. You recommend specific, real nearby \
                places with accurate category classifications. Every suggestion \
                MUST be within 1 mile (1.6 km) walking distance of the user's \
                location. Suggest real place names that actually exist near the \
                given coordinates. Never suggest places farther than 1 mile away.
                """
            }
            session = nearbySession

            let result = try await nearbySession.respond(
                to: prompt,
                generating: StopSuggestions.self
            )
            suggestions = result.content.stops
        } catch {
            errorMessage = "Could not generate nearby suggestions. Please try again."
        }

        isGenerating = false
    }

    /// Map a category string from the AI to a StopCategory enum.
    static func mapCategory(_ raw: String) -> StopCategory {
        switch raw.lowercased() {
        case "accommodation": return .accommodation
        case "restaurant": return .restaurant
        case "attraction": return .attraction
        case "transport": return .transport
        case "activity": return .activity
        default: return .other
        }
    }
}
#endif
