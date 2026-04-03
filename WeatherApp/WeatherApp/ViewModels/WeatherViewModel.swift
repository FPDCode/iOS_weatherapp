import Foundation
import SwiftUI

@MainActor
class WeatherViewModel: ObservableObject {
    @Published var currentTemp: Double = 0
    @Published var currentWeatherCode: Int = 0
    @Published var currentCondition: String = "Loading..."
    @Published var isDay: Bool = true

    @Published var todayPhases: [DayPhaseWeather] = []
    @Published var hourlyForecasts: [HourlyForecast] = []
    @Published var dailyForecasts: [DailyForecast] = []

    @Published var isLoading: Bool = true
    @Published var errorMessage: String?

    @Published var todayHigh: Double = 0
    @Published var todayLow: Double = 0
    @Published var sunrise: String = ""
    @Published var sunset: String = ""

    private let weatherService = WeatherService.shared
    private let isoFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withDashSeparatorInDate, .withTime, .withColonSeparatorInTime]
        return f
    }()
    private let dayFormatter: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withFullDate, .withDashSeparatorInDate]
        return f
    }()

    func fetchWeather(latitude: Double, longitude: Double) async {
        isLoading = true
        errorMessage = nil

        do {
            let response = try await weatherService.fetchWeather(latitude: latitude, longitude: longitude)
            processResponse(response)
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func processResponse(_ response: WeatherResponse) {
        // Current weather
        if let current = response.currentWeather {
            currentTemp = current.temperature
            currentWeatherCode = current.weathercode
            currentCondition = WeatherCodeInfo.description(for: current.weathercode)
            isDay = current.isDay == 1
        }

        // Daily data
        if let daily = response.daily {
            processDailyData(daily)
        }

        // Hourly data
        if let hourly = response.hourly {
            processHourlyData(hourly)
            processTodayPhases(hourly)
        }
    }

    private func processDailyData(_ daily: DailyData) {
        var forecasts: [DailyForecast] = []
        let count = min(daily.time.count, 10)

        for i in 0..<count {
            if let date = dayFormatter.date(from: daily.time[i]) {
                forecasts.append(DailyForecast(
                    date: date,
                    weatherCode: daily.weathercode[i],
                    tempHigh: daily.temperature2mMax[i],
                    tempLow: daily.temperature2mMin[i],
                    precipChance: daily.precipitationProbabilityMax[i]
                ))
            }
        }

        dailyForecasts = forecasts

        // Today's high/low
        if !daily.temperature2mMax.isEmpty {
            todayHigh = daily.temperature2mMax[0]
            todayLow = daily.temperature2mMin[0]
        }

        // Sunrise/sunset
        if !daily.sunrise.isEmpty {
            sunrise = formatTimeFromISO(daily.sunrise[0])
            sunset = formatTimeFromISO(daily.sunset[0])
        }
    }

    private func processHourlyData(_ hourly: HourlyData) {
        var forecasts: [HourlyForecast] = []
        let now = Date()
        let calendar = Calendar.current

        for i in 0..<hourly.time.count {
            guard let date = isoFormatter.date(from: hourly.time[i]) else { continue }

            // Only include hours from now through 48 hours
            if date < calendar.date(byAdding: .hour, value: -1, to: now)! { continue }
            if forecasts.count >= 48 { break }

            forecasts.append(HourlyForecast(
                time: date,
                temperature: hourly.temperature2m[i],
                feelsLike: hourly.apparentTemperature[i],
                precipChance: hourly.precipitationProbability[i],
                precipAmount: hourly.precipitation[i],
                weatherCode: hourly.weathercode[i],
                pressure: hourly.pressure?[i] ?? 0,
                humidity: hourly.relativehumidity2m[i],
                visibility: hourly.visibility[i]
            ))
        }

        hourlyForecasts = forecasts
    }

    private func processTodayPhases(_ hourly: HourlyData) {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())

        var phases: [DayPhaseWeather] = []

        for phase in DayPhase.allCases {
            let range = phase.hourRange
            var temps: [Double] = []
            var feels: [Double] = []
            var precips: [Int] = []
            var humids: [Int] = []
            var codes: [Int] = []

            for hour in range {
                let actualHour = hour % 24
                let dayOffset = hour >= 24 ? 1 : 0
                guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today),
                      let targetHour = calendar.date(byAdding: .hour, value: actualHour, to: targetDate)
                else { continue }

                // Find matching hour in data
                for i in 0..<hourly.time.count {
                    if let date = isoFormatter.date(from: hourly.time[i]),
                       calendar.isDate(date, equalTo: targetHour, toGranularity: .hour) {
                        temps.append(hourly.temperature2m[i])
                        feels.append(hourly.apparentTemperature[i])
                        precips.append(hourly.precipitationProbability[i])
                        humids.append(hourly.relativehumidity2m[i])
                        codes.append(hourly.weathercode[i])
                        break
                    }
                }
            }

            guard !temps.isEmpty else { continue }

            // Use the most common weather code
            let avgTemp = temps.reduce(0, +) / Double(temps.count)
            let avgFeels = feels.reduce(0, +) / Double(feels.count)
            let maxPrecip = precips.max() ?? 0
            let avgHumid = humids.reduce(0, +) / humids.count
            let dominantCode = mostFrequent(codes) ?? 0

            phases.append(DayPhaseWeather(
                phase: phase,
                temperature: avgTemp,
                feelsLike: avgFeels,
                weatherCode: dominantCode,
                precipChance: maxPrecip,
                humidity: avgHumid,
                windSpeed: nil
            ))
        }

        todayPhases = phases
    }

    private func mostFrequent(_ array: [Int]) -> Int? {
        var counts: [Int: Int] = [:]
        array.forEach { counts[$0, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private func formatTimeFromISO(_ iso: String) -> String {
        guard let date = isoFormatter.date(from: iso) else { return "" }
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        return formatter.string(from: date)
    }
}
