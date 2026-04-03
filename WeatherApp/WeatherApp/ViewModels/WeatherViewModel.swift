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
    @Published var lastUpdated: Date?
    @Published var todayUVIndex: Double = 0
    @Published var airQuality: AirQualityInfo?
    @Published var pressureInfo: PressureInfo?
    @Published var windInfo: WindInfo?

    private let weatherService = WeatherService.shared

    // Open-Meteo returns "2026-04-03T14:00" — no seconds, so use DateFormatter
    private let hourlyDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    private let dailyDateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone.current
        return f
    }()

    func fetchWeather(latitude: Double, longitude: Double) async {
        isLoading = true
        errorMessage = nil

        do {
            async let weatherTask = weatherService.fetchWeather(latitude: latitude, longitude: longitude)
            async let aqTask = weatherService.fetchAirQuality(latitude: latitude, longitude: longitude)

            let response = try await weatherTask
            processResponse(response)

            // Air quality is best-effort — don't fail if it errors
            if let aqResponse = try? await aqTask {
                processAirQuality(aqResponse)
            }

            lastUpdated = Date()
        } catch {
            errorMessage = error.localizedDescription
        }

        isLoading = false
    }

    private func processResponse(_ response: WeatherResponse) {
        if let current = response.currentWeather {
            currentTemp = current.temperature
            currentWeatherCode = current.weathercode
            currentCondition = WeatherCodeInfo.description(for: current.weathercode)
            isDay = current.isDay == 1
        }

        if let daily = response.daily {
            processDailyData(daily)
        }

        if let hourly = response.hourly {
            processHourlyData(hourly)
            processTodayPhases(hourly)
            processPressureTrend(hourly)
            processCurrentWind(hourly, current: response.currentWeather)
        }
    }

    private func processDailyData(_ daily: DailyData) {
        var forecasts: [DailyForecast] = []
        let count = min(
            daily.time.count,
            daily.weatherCode.count,
            daily.temperature2mMax.count,
            daily.temperature2mMin.count,
            daily.precipitationProbabilityMax.count,
            10
        )

        for i in 0..<count {
            if let date = dailyDateFormatter.date(from: daily.time[i]) {
                forecasts.append(DailyForecast(
                    date: date,
                    weatherCode: daily.weatherCode[i],
                    tempHigh: daily.temperature2mMax[i],
                    tempLow: daily.temperature2mMin[i],
                    precipChance: daily.precipitationProbabilityMax[i],
                    uvIndexMax: daily.uvIndexMax?[safe: i] ?? 0
                ))
            }
        }

        dailyForecasts = forecasts

        if !daily.temperature2mMax.isEmpty {
            todayHigh = daily.temperature2mMax[0]
            todayLow = daily.temperature2mMin[0]
        }

        if let uv = daily.uvIndexMax?.first {
            todayUVIndex = uv
        }

        if !daily.sunrise.isEmpty {
            sunrise = formatTimeFromAPI(daily.sunrise[0])
            sunset = formatTimeFromAPI(daily.sunset[0])
        }
    }

    private func processHourlyData(_ hourly: HourlyData) {
        var forecasts: [HourlyForecast] = []
        let now = Date()
        let calendar = Calendar.current

        let safeCount = min(
            hourly.time.count,
            hourly.temperature2m.count,
            hourly.apparentTemperature.count,
            hourly.precipitationProbability.count,
            hourly.precipitation.count,
            hourly.weatherCode.count,
            hourly.relativeHumidity2m.count,
            hourly.visibility.count,
            hourly.windSpeed10m.count
        )

        for i in 0..<safeCount {
            guard let date = hourlyDateFormatter.date(from: hourly.time[i]) else { continue }

            guard let oneHourAgo = calendar.date(byAdding: .hour, value: -1, to: now),
                  date >= oneHourAgo else { continue }
            if forecasts.count >= 48 { break }

            forecasts.append(HourlyForecast(
                time: date,
                temperature: hourly.temperature2m[i],
                feelsLike: hourly.apparentTemperature[i],
                precipChance: hourly.precipitationProbability[i],
                precipAmount: hourly.precipitation[i],
                weatherCode: hourly.weatherCode[i],
                pressure: hourly.surfacePressure?[safe: i] ?? 0,
                humidity: hourly.relativeHumidity2m[i],
                visibility: hourly.visibility[i],
                windSpeed: hourly.windSpeed10m[i],
                uvIndex: hourly.uvIndex?[safe: i] ?? 0
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
            var winds: [Double] = []
            var uvs: [Double] = []

            for hour in range {
                let actualHour = hour % 24
                let dayOffset = hour >= 24 ? 1 : 0
                guard let targetDate = calendar.date(byAdding: .day, value: dayOffset, to: today),
                      let targetHour = calendar.date(byAdding: .hour, value: actualHour, to: targetDate)
                else { continue }

                for i in 0..<hourly.time.count {
                    if let date = hourlyDateFormatter.date(from: hourly.time[i]),
                       calendar.isDate(date, equalTo: targetHour, toGranularity: .hour) {
                        if i < hourly.temperature2m.count { temps.append(hourly.temperature2m[i]) }
                        if i < hourly.apparentTemperature.count { feels.append(hourly.apparentTemperature[i]) }
                        if i < hourly.precipitationProbability.count { precips.append(hourly.precipitationProbability[i]) }
                        if i < hourly.relativeHumidity2m.count { humids.append(hourly.relativeHumidity2m[i]) }
                        if i < hourly.weatherCode.count { codes.append(hourly.weatherCode[i]) }
                        if i < hourly.windSpeed10m.count { winds.append(hourly.windSpeed10m[i]) }
                        if let uvArr = hourly.uvIndex, i < uvArr.count { uvs.append(uvArr[i]) }
                        break
                    }
                }
            }

            guard !temps.isEmpty else { continue }

            let avgTemp = temps.reduce(0, +) / Double(temps.count)
            let avgFeels = feels.reduce(0, +) / Double(feels.count)
            let maxPrecip = precips.max() ?? 0
            let avgHumid = humids.isEmpty ? 0 : humids.reduce(0, +) / humids.count
            let dominantCode = mostFrequent(codes) ?? 0
            let avgWind = winds.isEmpty ? nil : winds.reduce(0, +) / Double(winds.count)
            let maxUV = uvs.isEmpty ? nil : uvs.max()

            phases.append(DayPhaseWeather(
                phase: phase,
                temperature: avgTemp,
                feelsLike: avgFeels,
                weatherCode: dominantCode,
                precipChance: maxPrecip,
                humidity: avgHumid,
                windSpeed: avgWind,
                uvIndex: maxUV
            ))
        }

        todayPhases = phases
    }

    private func processCurrentWind(_ hourly: HourlyData, current: CurrentWeather?) {
        let now = Date()
        let calendar = Calendar.current

        // Find the current hour in hourly data
        for i in 0..<hourly.time.count {
            guard let date = hourlyDateFormatter.date(from: hourly.time[i]) else { continue }
            guard calendar.isDate(date, equalTo: now, toGranularity: .hour) else { continue }

            let speed = hourly.windSpeed10m[safe: i] ?? current?.windspeed ?? 0
            let gusts = hourly.windGusts10m?[safe: i] ?? speed
            let direction = hourly.windDirection10m?[safe: i] ?? Int(current?.winddirection ?? 0)

            let speedMph = UnitSettings.shared.toMph(speed)
            let beaufort = BeaufortScale.from(speedMph: speedMph)

            windInfo = WindInfo(
                speed: speed,
                gusts: gusts,
                direction: direction,
                beaufort: beaufort
            )
            return
        }

        // Fallback to current_weather if hourly match not found
        if let current {
            let speedMph = UnitSettings.shared.toMph(current.windspeed)
            windInfo = WindInfo(
                speed: current.windspeed,
                gusts: current.windspeed,
                direction: Int(current.winddirection),
                beaufort: BeaufortScale.from(speedMph: speedMph)
            )
        }
    }

    private func processPressureTrend(_ hourly: HourlyData) {
        guard let pressureArr = hourly.surfacePressure, !pressureArr.isEmpty else {
            pressureInfo = nil
            return
        }

        let now = Date()
        let calendar = Calendar.current

        // Collect pressure readings from now through +10 hours
        var currentPressure: Double?
        var pressureAt10h: Double?
        var readings: [(date: Date, pressure: Double)] = []

        for i in 0..<min(hourly.time.count, pressureArr.count) {
            guard let date = hourlyDateFormatter.date(from: hourly.time[i]) else { continue }

            // Skip past hours (more than 1h ago)
            guard let oneHourAgo = calendar.date(byAdding: .hour, value: -1, to: now),
                  date >= oneHourAgo else { continue }

            // Current hour
            if currentPressure == nil {
                currentPressure = pressureArr[i]
            }

            // Collect readings for the next 12 hours (for the mini chart)
            if readings.count < 12 {
                readings.append((date: date, pressure: pressureArr[i]))
            }

            // Find the reading closest to +10 hours
            if let tenHoursLater = calendar.date(byAdding: .hour, value: 10, to: now),
               calendar.isDate(date, equalTo: tenHoursLater, toGranularity: .hour) {
                pressureAt10h = pressureArr[i]
            }
        }

        guard let current = currentPressure else {
            pressureInfo = nil
            return
        }

        // If we didn't find an exact +10h match, use the last reading or interpolate
        let target = pressureAt10h ?? readings.last?.pressure ?? current
        let change = target - current
        let trend = PressureTrend.from(change: change)

        pressureInfo = PressureInfo(
            currentPressure: current,
            pressureIn10h: target,
            trend: trend,
            hourlyReadings: readings
        )
    }

    private func processAirQuality(_ response: AirQualityResponse) {
        guard let hourly = response.hourly else { return }

        // Find the current hour's data
        let now = Date()
        let calendar = Calendar.current
        var currentAqi: Int?
        var currentPM25: Double?
        var currentPM10: Double?

        // Also collect pollen data for today
        var grassValues: [Double] = []
        var treeValues: [Double] = []
        var weedValues: [Double] = []

        let today = calendar.startOfDay(for: now)

        for i in 0..<hourly.time.count {
            guard let date = hourlyDateFormatter.date(from: hourly.time[i]) else { continue }

            // Get current hour AQI
            if calendar.isDate(date, equalTo: now, toGranularity: .hour) {
                currentAqi = hourly.usAqi?[safe: i] ?? hourly.europeanAqi?[safe: i]
                currentPM25 = hourly.pm25?[safe: i]
                currentPM10 = hourly.pm10?[safe: i]
            }

            // Collect today's pollen
            if calendar.isDate(date, inSameDayAs: today) {
                if let v = hourly.grassPollen?[safe: i] { grassValues.append(v) }
                if let alder = hourly.alderPollen?[safe: i],
                   let birch = hourly.birchPollen?[safe: i],
                   let olive = hourly.olivePollen?[safe: i] {
                    treeValues.append(max(alder, birch, olive))
                }
                if let mugwort = hourly.mugwortPollen?[safe: i],
                   let ragweed = hourly.ragweedPollen?[safe: i] {
                    weedValues.append(max(mugwort, ragweed))
                }
            }
        }

        guard let aqi = currentAqi else { return }

        let pollenSummary: PollenSummary?
        if !grassValues.isEmpty || !treeValues.isEmpty || !weedValues.isEmpty {
            pollenSummary = PollenSummary(
                grassLevel: PollenLevel.from(grainsPerM3: grassValues.max() ?? 0),
                treeLevel: PollenLevel.from(grainsPerM3: treeValues.max() ?? 0),
                weedLevel: PollenLevel.from(grainsPerM3: weedValues.max() ?? 0)
            )
        } else {
            pollenSummary = nil
        }

        airQuality = AirQualityInfo(
            aqi: aqi,
            pm25: currentPM25 ?? 0,
            pm10: currentPM10 ?? 0,
            level: AQILevel.from(usAqi: aqi),
            pollenSummary: pollenSummary
        )
    }

    private func mostFrequent(_ array: [Int]) -> Int? {
        var counts: [Int: Int] = [:]
        array.forEach { counts[$0, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }

    private func formatTimeFromAPI(_ timeString: String) -> String {
        guard let date = hourlyDateFormatter.date(from: timeString) else { return "" }
        return WeatherFormatters.shortTime(date)
    }
}

// MARK: - Safe Array Access

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

extension Array where Element == Optional<Int> {
    subscript(safe index: Int) -> Int? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}

extension Array where Element == Optional<Double> {
    subscript(safe index: Int) -> Double? {
        guard indices.contains(index) else { return nil }
        return self[index]
    }
}
