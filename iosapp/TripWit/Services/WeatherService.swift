import Foundation
import CoreLocation

/// Fetches weather forecast from the free Open-Meteo API (no API key needed).
@Observable
final class WeatherService {

    struct DayForecast: Identifiable {
        let id = UUID()
        let date: Date
        let highTemp: Double
        let lowTemp: Double
        let conditionCode: Int  // WMO weather code
        let precipProbability: Int  // percentage
    }

    private(set) var forecasts: [DayForecast] = []
    private(set) var isLoading = false
    private(set) var errorMessage: String?
    private(set) var locationName: String = ""

    /// Whether the device locale uses Fahrenheit (US, Cayman Islands, etc.)
    var usesFahrenheit: Bool {
        Locale.current.measurementSystem == .us
    }

    /// Formatted temperature string with the correct unit symbol.
    func formatTemp(_ temp: Double) -> String {
        "\(Int(round(temp)))°"
    }

    /// Fetch weather for a destination string and date range.
    func fetchWeather(destination: String, startDate: Date, endDate: Date) async {
        isLoading = true
        errorMessage = nil
        forecasts = []
        locationName = destination

        // First, geocode the destination
        let geocoder = CLGeocoder()
        do {
            let placemarks = try await geocoder.geocodeAddressString(destination)
            guard let location = placemarks.first?.location else {
                errorMessage = "Could not find location"
                isLoading = false
                return
            }

            let lat = location.coordinate.latitude
            let lon = location.coordinate.longitude

            // Format dates for API (POSIX locale ensures Gregorian calendar on all devices)
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "en_US_POSIX")
            formatter.calendar = Calendar(identifier: .gregorian)
            formatter.dateFormat = "yyyy-MM-dd"

            let start = formatter.string(from: startDate)
            let end = formatter.string(from: endDate)

            // Use Open-Meteo free API — respect device locale for temperature unit
            let tempUnit = usesFahrenheit ? "fahrenheit" : "celsius"
            let urlString = "https://api.open-meteo.com/v1/forecast?latitude=\(lat)&longitude=\(lon)&daily=temperature_2m_max,temperature_2m_min,weathercode,precipitation_probability_max&temperature_unit=\(tempUnit)&start_date=\(start)&end_date=\(end)&timezone=auto"

            guard let url = URL(string: urlString) else {
                errorMessage = "Invalid URL"
                isLoading = false
                return
            }

            let (data, _) = try await URLSession.shared.data(from: url)
            let decoded = try JSONDecoder().decode(OpenMeteoResponse.self, from: data)

            var results: [DayForecast] = []
            let dateParser = DateFormatter()
            dateParser.locale = Locale(identifier: "en_US_POSIX")
            dateParser.calendar = Calendar(identifier: .gregorian)
            dateParser.dateFormat = "yyyy-MM-dd"

            for i in 0..<decoded.daily.time.count {
                guard let date = dateParser.date(from: decoded.daily.time[i]) else { continue }
                results.append(DayForecast(
                    date: date,
                    highTemp: decoded.daily.temperature_2m_max[i],
                    lowTemp: decoded.daily.temperature_2m_min[i],
                    conditionCode: decoded.daily.weathercode[i],
                    precipProbability: decoded.daily.precipitation_probability_max?[i] ?? 0
                ))
            }

            forecasts = results
            isLoading = false
        } catch let urlError as URLError {
            switch urlError.code {
            case .notConnectedToInternet, .networkConnectionLost:
                errorMessage = "No internet connection"
            case .timedOut:
                errorMessage = "Request timed out"
            default:
                errorMessage = "Could not load weather"
            }
            isLoading = false
        } catch {
            errorMessage = "Could not load weather"
            isLoading = false
        }
    }

    /// Convert WMO weather code to SF Symbol name.
    static func weatherIcon(for code: Int) -> String {
        switch code {
        case 0: return "sun.max.fill"
        case 1, 2: return "cloud.sun.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51, 53, 55: return "cloud.drizzle.fill"
        case 56, 57: return "cloud.sleet.fill"
        case 61, 63, 65: return "cloud.rain.fill"
        case 66, 67: return "cloud.sleet.fill"
        case 71, 73, 75: return "cloud.snow.fill"
        case 77: return "snowflake"
        case 80, 81, 82: return "cloud.heavyrain.fill"
        case 85, 86: return "cloud.snow.fill"
        case 95: return "cloud.bolt.fill"
        case 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    /// Convert WMO weather code to description.
    static func weatherDescription(for code: Int) -> String {
        switch code {
        case 0: return "Clear"
        case 1: return "Mostly Clear"
        case 2: return "Partly Cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing Drizzle"
        case 61, 63: return "Rain"
        case 65: return "Heavy Rain"
        case 66, 67: return "Freezing Rain"
        case 71, 73: return "Snow"
        case 75: return "Heavy Snow"
        case 77: return "Snow Grains"
        case 80, 81: return "Showers"
        case 82: return "Heavy Showers"
        case 85, 86: return "Snow Showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Hail Storm"
        default: return "Unknown"
        }
    }

    /// Color for weather icon.
    static func weatherColor(for code: Int) -> String {
        switch code {
        case 0: return "yellow"
        case 1, 2: return "orange"
        case 3, 45, 48: return "gray"
        case 51...67: return "blue"
        case 71...86: return "cyan"
        case 95...99: return "purple"
        default: return "gray"
        }
    }
}

// MARK: - Open-Meteo Response

private struct OpenMeteoResponse: Codable {
    let daily: DailyData

    struct DailyData: Codable {
        let time: [String]
        let temperature_2m_max: [Double]
        let temperature_2m_min: [Double]
        let weathercode: [Int]
        let precipitation_probability_max: [Int]?
    }
}
