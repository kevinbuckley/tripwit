import SwiftUI

/// Displays a horizontal scrollable weather forecast for a trip.
/// For multi-city trips, fetches weather for the primary (first) location.
struct WeatherSection: View {

    let trip: TripEntity
    @State private var weatherService = WeatherService()

    /// The primary weather location — uses the first day's location or falls back to trip destination.
    private var weatherLocation: String {
        let sortedDays = trip.daysArray.sorted { $0.dayNumber < $1.dayNumber }
        if let firstLoc = sortedDays.first(where: { !$0.wrappedLocation.isEmpty })?.wrappedLocation, !firstLoc.isEmpty {
            return firstLoc
        }
        return trip.wrappedDestination
    }

    /// Unique locations across this trip for display in multi-city scenarios.
    private var uniqueLocations: [String] {
        var seen = Set<String>()
        var result: [String] = []
        for day in trip.daysArray.sorted(by: { $0.dayNumber < $1.dayNumber }) {
            let loc = day.wrappedLocation.isEmpty ? trip.wrappedDestination : day.wrappedLocation
            if !seen.contains(loc) {
                seen.insert(loc)
                result.append(loc)
            }
        }
        return result
    }

    private var dateFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }

    private var dayFormatter: DateFormatter {
        let f = DateFormatter()
        f.dateFormat = "M/d"
        return f
    }

    var body: some View {
        Section {
            if weatherService.isLoading {
                HStack {
                    Spacer()
                    VStack(spacing: 8) {
                        ProgressView()
                        Text("Loading forecast...")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            } else if let error = weatherService.errorMessage {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "cloud.slash")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            } else if !weatherService.forecasts.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(weatherService.forecasts) { day in
                            weatherDayCard(day)
                        }
                    }
                    .padding(.vertical, 4)
                }
                .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
            } else {
                HStack {
                    Spacer()
                    VStack(spacing: 6) {
                        Image(systemName: "cloud.sun")
                            .font(.title2)
                            .foregroundStyle(.secondary)
                        Text("Forecast not available yet")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.vertical, 12)
                    Spacer()
                }
            }
        } header: {
            HStack {
                Label("Weather", systemImage: "cloud.sun.fill")
                if uniqueLocations.count > 1 {
                    Text("· \(weatherLocation)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if !weatherService.forecasts.isEmpty {
                    Button {
                        Task {
                            await weatherService.fetchWeather(
                                destination: weatherLocation,
                                startDate: trip.wrappedStartDate,
                                endDate: trip.wrappedEndDate
                            )
                        }
                    } label: {
                        Image(systemName: "arrow.clockwise")
                            .font(.caption)
                    }
                    .accessibilityLabel("Refresh weather")
                }
            }
        }
        .task {
            // Only fetch if trip is in the future or current (Open-Meteo supports ~16 days ahead)
            if !trip.isPast {
                await weatherService.fetchWeather(
                    destination: weatherLocation,
                    startDate: trip.wrappedStartDate,
                    endDate: trip.wrappedEndDate
                )
            }
        }
    }

    private func weatherDayCard(_ day: WeatherService.DayForecast) -> some View {
        VStack(spacing: 6) {
            Text(dateFormatter.string(from: day.date))
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)

            Text(dayFormatter.string(from: day.date))
                .font(.caption2)
                .foregroundStyle(.tertiary)

            Image(systemName: WeatherService.weatherIcon(for: day.conditionCode))
                .font(.title3)
                .foregroundStyle(iconColor(for: day.conditionCode))
                .frame(height: 28)

            VStack(spacing: 2) {
                Text("\(Int(day.highTemp))°")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(Int(day.lowTemp))°")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if day.precipProbability > 0 {
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.blue)
                    Text("\(day.precipProbability)%")
                        .font(.system(size: 9))
                        .foregroundStyle(.blue)
                }
            }
        }
        .frame(width: 56)
        .padding(.vertical, 8)
        .padding(.horizontal, 4)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func iconColor(for code: Int) -> Color {
        switch WeatherService.weatherColor(for: code) {
        case "yellow": return .yellow
        case "orange": return .orange
        case "blue": return .blue
        case "cyan": return .cyan
        case "purple": return .purple
        default: return .gray
        }
    }
}
