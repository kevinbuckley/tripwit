import Foundation
import TripCore

#if canImport(FoundationModels)
import FoundationModels

// MARK: - Generable Types for AI Suggestions

@available(iOS 26, *)
@Generable
struct LocatedPlace {
    @Guide(description: "The full name of the place")
    var name: String

    @Guide(description: "The latitude coordinate of the place")
    var latitude: Double

    @Guide(description: "The longitude coordinate of the place")
    var longitude: Double

    @Guide(description: "A short address or neighborhood description")
    var address: String
}

@available(iOS 26, *)
@Generable
struct ParsedItineraryDay {
    @Guide(description: "The day number in the itinerary, starting from 1")
    var dayNumber: Int

    @Guide(description: "A list of stops planned for this day")
    var stops: [ParsedItineraryStop]
}

@available(iOS 26, *)
@Generable
struct ParsedItineraryStop {
    @Guide(description: "The name of the place or attraction")
    var name: String

    @Guide(description: "A short one-sentence description or note about this stop")
    var note: String

    @Guide(.anyOf(["accommodation", "restaurant", "attraction", "transport", "activity", "other"]))
    var category: String

    @Guide(description: "Suggested visit duration in minutes, e.g. 60 for one hour. Use 0 if unknown.")
    var durationMinutes: Int
}

@available(iOS 26, *)
@Generable
struct ParsedItinerary {
    @Guide(description: "A list of days extracted from the itinerary text")
    var days: [ParsedItineraryDay]
}

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

    /// Static availability check — can be called without an instance.
    static var isDeviceSupported: Bool {
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
        existingStops: [String],
        radiusMiles: Double = 1.0
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

        let radiusDesc = String(format: "%.1f mile(s) (%.1f km)", radiusMiles, radiusMiles * 1.60934)

        let prompt = """
        I am currently at \(stopName) (a \(stopCategory)) located at \
        coordinates \(latitude), \(longitude).

        Suggest 5 highly-rated places that are within \(radiusDesc) of \
        my current location. Focus on:
        - Great restaurants and cafés for a meal or snack
        - Notable attractions, landmarks, or hidden gems nearby
        - Fun activities in the immediate area

        IMPORTANT: Only suggest places that are within \(radiusDesc) \
        distance from coordinates \(latitude), \(longitude). \
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
                MUST be within \(radiusDesc) of the user's \
                location. Suggest real place names that actually exist near the \
                given coordinates. Never suggest places farther than \(radiusDesc) away.
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

    /// Plan an entire day based on a vibe/mood description.
    func planDayByVibe(
        vibe: String,
        destination: String,
        dayNumber: Int,
        totalDays: Int,
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
            ? "None yet"
            : existingStops.joined(separator: ", ")

        let prompt = """
        Plan a full day in \(destination) for Day \(dayNumber) of a \
        \(totalDays)-day trip. The traveler wants this vibe:

        "\(vibe)"

        Create a complete day itinerary with 6-8 stops in chronological \
        order from morning to evening. Include:
        - A breakfast/coffee spot to start the day
        - Morning activities matching the vibe
        - A lunch spot that fits the mood
        - Afternoon activities matching the vibe
        - A dinner spot to wrap up the day
        - Optionally an evening activity if it fits

        Already planned stops (do NOT duplicate): \(existingList)

        Order the stops as a realistic day — morning first, evening last. \
        Set duration estimates that make sense for each type of stop. \
        Suggest real, specific places in \(destination).
        """

        do {
            let vibeSession = LanguageModelSession {
                """
                You are a creative travel planner who designs full-day itineraries \
                based on a mood or vibe. You suggest specific, real places with \
                accurate categories. You order stops chronologically for a realistic \
                day flow: breakfast → morning → lunch → afternoon → dinner → evening. \
                Every place must actually exist in the destination city.
                """
            }
            session = vibeSession

            let result = try await vibeSession.respond(
                to: prompt,
                generating: StopSuggestions.self
            )
            suggestions = result.content.stops
        } catch {
            errorMessage = "Could not plan your day. Please try again."
        }

        isGenerating = false
    }

    /// Locate a place by name using AI to find its coordinates.
    var locatedPlace: LocatedPlace?
    var isLocating = false

    func locatePlace(name: String, destination: String) async {
        guard isAvailable else {
            errorMessage = "Apple Intelligence is not available on this device."
            return
        }

        isLocating = true
        locatedPlace = nil
        errorMessage = nil

        let prompt = """
        Find the location of "\(name)" in or near \(destination).

        Provide the exact latitude and longitude coordinates and a short \
        address or neighborhood description. If this is a well-known place, \
        use its actual coordinates. Be as accurate as possible.
        """

        do {
            let locateSession = LanguageModelSession {
                """
                You are a geocoding assistant. You provide accurate latitude and \
                longitude coordinates for real places. Always return real coordinates \
                that would place a pin on the correct location on a map.
                """
            }

            let result = try await locateSession.respond(
                to: prompt,
                generating: LocatedPlace.self
            )
            locatedPlace = result.content
        } catch {
            errorMessage = "Could not locate this place. Please try again."
        }

        isLocating = false
    }

    // MARK: - Parse Itinerary

    var parsedItinerary: ParsedItinerary?
    var isParsing = false

    /// Parse free-form itinerary text (e.g. from ChatGPT) into structured days and stops.
    func parseItinerary(text: String, destination: String, totalDays: Int) async {
        guard isAvailable else {
            errorMessage = "Apple Intelligence is not available on this device."
            return
        }

        isParsing = true
        parsedItinerary = nil
        errorMessage = nil

        let prompt = """
        Parse the following travel itinerary text into structured days and stops. \
        The trip destination is \(destination) and the trip has \(totalDays) day(s).

        RULES:
        - Extract every place, restaurant, attraction, or activity mentioned.
        - Assign each stop to the correct day number. If the text uses "Day 1", "Day 2", etc., \
          use those numbers. If stops don't have clear day assignments, assign them to day 1.
        - Day numbers must be between 1 and \(totalDays). If the text mentions more days than \
          the trip has, cap at \(totalDays).
        - Classify each stop: restaurant (any food/drink/café), attraction (museums, landmarks, \
          parks, viewpoints), activity (tours, shows, shopping, experiences), accommodation \
          (hotels, hostels), transport (airports, train stations), other.
        - Estimate duration in minutes if not specified (restaurants: 60-90, attractions: 60-120, \
          activities: 60-180).
        - Use the place name as given, do NOT rename or paraphrase.
        - If a note or description is given for the stop, include it. Otherwise use a short description.

        TEXT TO PARSE:
        \(text)
        """

        do {
            let parseSession = LanguageModelSession {
                """
                You are a travel itinerary parser. You extract structured stop data from \
                free-form text. You are precise about place names — use them exactly as written. \
                You assign accurate categories and reasonable duration estimates.
                """
            }

            let result = try await parseSession.respond(
                to: prompt,
                generating: ParsedItinerary.self
            )
            parsedItinerary = result.content
        } catch {
            errorMessage = "Could not parse the itinerary. Please try again."
        }

        isParsing = false
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
