import Foundation
import SwiftUI
import WidgetKit

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
    @Published var sunriseDate: Date?
    @Published var sunsetDate: Date?
    @Published var tomorrowSunriseDate: Date?
    @Published var tomorrowSunsetDate: Date?
    @Published var lastUpdated: Date?
    @Published var todayUVIndex: Double = 0
    @Published var airQuality: AirQualityInfo?
    @Published var pressureInfo: PressureInfo?
    @Published var windInfo: WindInfo?
    @Published var precipTimeline: PrecipitationTimeline?
    @Published var comfortInfo: ComfortInfo?
    @Published var cloudCoverInfo: CloudCoverInfo?
    @Published var sunshinePlan: SunshinePlan?
    @Published var gardeningInfo: GardeningInfo?
    @Published var stormRisk: StormRiskInfo?
    @Published var todaySunshineDuration: Double = 0
    @Published var todayPrecipHours: Double = 0
    @Published var nwsAlerts: [NWSAlert] = []
    @Published var smartWarnings: [SmartWarning] = []
    @Published var currentVisibility: Double = 10000
    @Published var currentHumidity: Int = 50

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

        print("🌤️ Fetching weather for \(latitude), \(longitude)")

        do {
            let response = try await weatherService.fetchWeather(latitude: latitude, longitude: longitude)
            print("✅ Weather response received — hourly: \((response.hourly?.time ?? []).count) hours, daily: \((response.daily?.time ?? []).count) days")
            processResponse(response)

            // Air quality is best-effort — don't fail if it errors
            if let aqResponse = try? await weatherService.fetchAirQuality(latitude: latitude, longitude: longitude) {
                processAirQuality(aqResponse)
            }

            // NWS alerts — best-effort
            if let alerts = try? await NWSAlertsService.shared.fetchAlerts(latitude: latitude, longitude: longitude) {
                nwsAlerts = alerts
            }

            // Generate smart warnings from all collected data
            smartWarnings = SmartWarningEngine.analyze(
                hourlyForecasts: hourlyForecasts,
                pressureInfo: pressureInfo,
                windInfo: windInfo,
                airQuality: airQuality,
                stormRisk: stormRisk,
                gardeningInfo: gardeningInfo,
                todayUVIndex: todayUVIndex,
                todayHigh: todayHigh,
                todayLow: todayLow
            )

            // Update rain Live Activity
            let locationName = LocationStore.shared.activeLocation?.name ?? "Current Location"
            RainActivityService.shared.update(with: precipTimeline, locationName: locationName)

            // Write shared data for widgets
            writeWidgetData(locationName: locationName)

            lastUpdated = Date()
        } catch {
            print("❌ Weather fetch failed: \(error)")
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

        if let minutely = response.minutely15 {
            processMinutelyPrecip(minutely)
        }

        if let hourly = response.hourly {
            processHourlyData(hourly)
            processTodayPhases(hourly)
            processPressureTrend(hourly)
            processCurrentWind(hourly, current: response.currentWeather)
            processComfort(hourly)
            processCloudCover(hourly)
            processSunshinePlan(hourly, daily: response.daily)
            processGardening(hourly)
            processStormRisk(hourly)
        }
    }

    private func processDailyData(_ daily: DailyData) {
        var forecasts: [DailyForecast] = []
        let count = min(
            (daily.time ?? []).count,
            daily.weatherCodeInts.count,
            daily.tempMaxValues.count,
            daily.tempMinValues.count,
            daily.precipProbMaxInts.count,
            10
        )

        for i in 0..<count {
            if let date = dailyDateFormatter.date(from: (daily.time ?? [])[i]) {
                forecasts.append(DailyForecast(
                    date: date,
                    weatherCode: daily.weatherCodeInts[i],
                    tempHigh: daily.tempMaxValues[i],
                    tempLow: daily.tempMinValues[i],
                    precipChance: daily.precipProbMaxInts[i],
                    uvIndexMax: daily.uvMaxValues[safe: i] ?? 0,
                    sunshineDuration: daily.sunshineValues[safe: i] ?? 0,
                    daylightDuration: daily.daylightValues[safe: i] ?? 0,
                    precipSum: daily.precipSumValues[safe: i] ?? 0,
                    precipHours: daily.precipHoursValues[safe: i] ?? 0,
                    windSpeedMax: daily.windSpeedMaxValues[safe: i] ?? 0,
                    windGustsMax: daily.windGustsMaxValues[safe: i] ?? 0,
                    windDirectionDominant: daily.windDirDominantInts[safe: i] ?? 0,
                    sunrise: i < daily.sunriseStrings.count ? daily.sunriseStrings[i] : "",
                    sunset: i < daily.sunsetStrings.count ? daily.sunsetStrings[i] : ""
                ))
            }
        }

        dailyForecasts = forecasts

        if !daily.tempMaxValues.isEmpty {
            todayHigh = daily.tempMaxValues[0]
            todayLow = daily.tempMinValues[0]
        }

        if let uv = daily.uvMaxValues.first {
            todayUVIndex = uv
        }

        if let sunshine = daily.sunshineValues.first {
            todaySunshineDuration = sunshine
        }
        if let precipH = daily.precipHoursValues.first {
            todayPrecipHours = precipH
        }

        if !daily.sunriseStrings.isEmpty {
            sunrise = formatTimeFromAPI(daily.sunriseStrings[0])
            sunset = formatTimeFromAPI(daily.sunsetStrings[0])
            sunriseDate = hourlyDateFormatter.date(from: daily.sunriseStrings[0])
            sunsetDate = hourlyDateFormatter.date(from: daily.sunsetStrings[0])

            if daily.sunriseStrings.count > 1 {
                tomorrowSunriseDate = hourlyDateFormatter.date(from: daily.sunriseStrings[1])
                tomorrowSunsetDate = hourlyDateFormatter.date(from: daily.sunsetStrings[1])
            }
        }
    }

    private func processHourlyData(_ hourly: HourlyData) {
        var forecasts: [HourlyForecast] = []
        let now = Date()
        let calendar = Calendar.current

        let temps = hourly.temps
        let feels = hourly.feelsLike
        let precProb = hourly.precipProbabilityInts
        let prec = hourly.precip
        let codes = hourly.weatherCodeInts
        let humid = hourly.humidityInts
        let vis = hourly.vis
        let wind = hourly.wind

        let safeCount = min(
            (hourly.time ?? []).count, temps.count, feels.count, precProb.count,
            prec.count, codes.count, humid.count, vis.count, wind.count
        )

        for i in 0..<safeCount {
            guard let date = hourlyDateFormatter.date(from: (hourly.time ?? [])[i]) else { continue }

            guard let oneHourAgo = calendar.date(byAdding: .hour, value: -1, to: now),
                  date >= oneHourAgo else { continue }
            if forecasts.count >= 48 { break }

            forecasts.append(HourlyForecast(
                time: date,
                temperature: temps[i],
                feelsLike: feels[i],
                precipChance: precProb[i],
                precipAmount: prec[i],
                weatherCode: codes[i],
                pressure: hourly.pressure[safe: i] ?? 0,
                humidity: humid[i],
                visibility: vis[i],
                windSpeed: wind[i],
                uvIndex: hourly.uv[safe: i] ?? 0
            ))
        }

        hourlyForecasts = forecasts

        // Extract current hour's visibility and humidity for shader
        if let first = forecasts.first {
            currentVisibility = first.visibility
            currentHumidity = first.humidity
        }
    }

    private func processTodayPhases(_ hourly: HourlyData) {
        let calendar = Calendar.current
        let now = Date()
        let currentHour = calendar.component(.hour, from: now)

        // Determine current phase index
        let allPhases = DayPhase.allCases // [morning, afternoon, evening, night]
        let currentPhaseIndex: Int
        switch currentHour {
        case 6..<12: currentPhaseIndex = 0  // morning
        case 12..<18: currentPhaseIndex = 1 // afternoon
        case 18..<22: currentPhaseIndex = 2 // evening
        default: currentPhaseIndex = 3      // night
        }

        // Build the 4 upcoming phases: current + next 3 (wrapping into tomorrow)
        var upcomingPhases: [(phase: DayPhase, dayOffset: Int)] = []
        for offset in 0..<4 {
            let idx = (currentPhaseIndex + offset) % 4
            let dayOff = (currentPhaseIndex + offset) >= 4 ? 1 : 0
            upcomingPhases.append((allPhases[idx], dayOff))
        }

        // Pre-extract safe arrays once
        let t = hourly.temps
        let f = hourly.feelsLike
        let pp = hourly.precipProbabilityInts
        let h = hourly.humidityInts
        let wc = hourly.weatherCodeInts
        let w = hourly.wind
        let uvArr = hourly.uv
        let timeArr = hourly.time ?? []

        var phases: [DayPhaseWeather] = []

        for (phase, dayOff) in upcomingPhases {
            let baseDay = calendar.startOfDay(for: calendar.date(byAdding: .day, value: dayOff, to: now) ?? now)
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
                let extraDay = hour >= 24 ? 1 : 0
                guard let targetDay = calendar.date(byAdding: .day, value: extraDay, to: baseDay),
                      let targetHour = calendar.date(byAdding: .hour, value: actualHour, to: targetDay)
                else { continue }

                for i in 0..<timeArr.count {
                    if let date = hourlyDateFormatter.date(from: timeArr[i]),
                       calendar.isDate(date, equalTo: targetHour, toGranularity: .hour) {
                        if i < t.count { temps.append(t[i]) }
                        if i < f.count { feels.append(f[i]) }
                        if i < pp.count { precips.append(pp[i]) }
                        if i < h.count { humids.append(h[i]) }
                        if i < wc.count { codes.append(wc[i]) }
                        if i < w.count { winds.append(w[i]) }
                        if i < uvArr.count { uvs.append(uvArr[i]) }
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

    private func processMinutelyPrecip(_ minutely: Minutely15Data) {
        let now = Date()
        let calendar = Calendar.current

        var slots: [PrecipSlot] = []

        let timeArr = minutely.time ?? []
        let precipArr = minutely.precipitation?.map { $0 ?? 0 } ?? []
        let rainArr = minutely.rain?.map { $0 ?? 0 } ?? []
        let snowArr = minutely.snowfall?.map { $0 ?? 0 } ?? []
        let count = min(timeArr.count, precipArr.count)

        for i in 0..<count {
            guard let date = hourlyDateFormatter.date(from: timeArr[i]) else { continue }

            guard let fifteenMinAgo = calendar.date(byAdding: .minute, value: -15, to: now),
                  date >= fifteenMinAgo else { continue }
            if slots.count >= 8 { break }

            let precip = precipArr[i]
            let rain = rainArr[safe: i] ?? precip
            let snow = snowArr[safe: i] ?? 0

            // Map hourly precipitation chance onto this 15-min slot
            let slotHour = calendar.component(.hour, from: date)
            let chance = hourlyForecasts.first { calendar.component(.hour, from: $0.time) == slotHour }?.precipChance ?? 0

            slots.append(PrecipSlot(
                time: date,
                precipitation: precip,
                rain: rain,
                snowfall: snow,
                intensity: PrecipIntensity.from(mmPer15min: precip),
                precipChance: chance
            ))
        }

        guard !slots.isEmpty else {
            precipTimeline = nil
            return
        }

        let isCurrentlyRaining = slots.first.map { $0.precipitation >= 0.1 } ?? false
        let maxIntensity = slots.map(\.precipitation).max() ?? 0

        // Find next change: if raining, when does it stop? If dry, when does it start?
        var nextChangeTime: Date?
        var nextChangeLabel: String?

        if isCurrentlyRaining {
            // Find first dry slot
            if let drySlot = slots.first(where: { $0.precipitation < 0.1 }) {
                nextChangeTime = drySlot.time
                let minutes = Int(drySlot.time.timeIntervalSince(now) / 60)
                nextChangeLabel = "Stopping in \(minutes) min"
            } else {
                nextChangeLabel = "Rain for the next 2 hours"
            }
        } else {
            // Find first wet slot
            if let wetSlot = slots.first(where: { $0.precipitation >= 0.1 }) {
                nextChangeTime = wetSlot.time
                let minutes = Int(wetSlot.time.timeIntervalSince(now) / 60)
                if minutes <= 0 {
                    nextChangeLabel = "Rain starting now"
                } else {
                    nextChangeLabel = "Rain in \(minutes) min"
                }
            } else {
                nextChangeLabel = "No rain for 2 hours"
            }
        }

        // Build summary
        let summary: String
        if maxIntensity < 0.1 {
            summary = "Clear skies — no precipitation expected in the next 2 hours"
        } else {
            let hasSnow = slots.contains { $0.snowfall > 0.1 }
            let precipType = hasSnow ? "snow" : "rain"
            let maxLevel = PrecipIntensity.from(mmPer15min: maxIntensity)
            summary = "\(maxLevel.rawValue) \(precipType) expected"
        }

        precipTimeline = PrecipitationTimeline(
            slots: slots,
            summary: summary,
            isRaining: isCurrentlyRaining,
            nextChangeTime: nextChangeTime,
            nextChangeLabel: nextChangeLabel,
            maxIntensity: maxIntensity
        )
    }

    private func processCurrentWind(_ hourly: HourlyData, current: CurrentWeather?) {
        let now = Date()
        let calendar = Calendar.current

        // Find the current hour in hourly data
        for i in 0..<(hourly.time ?? []).count {
            guard let date = hourlyDateFormatter.date(from: (hourly.time ?? [])[i]) else { continue }
            guard calendar.isDate(date, equalTo: now, toGranularity: .hour) else { continue }

            let speed = hourly.wind[safe: i] ?? current?.windspeed ?? 0
            let gusts = hourly.gusts[safe: i] ?? speed
            let direction = hourly.windDirectionInts[safe: i] ?? Int(current?.winddirection ?? 0)

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
        let pressureArr = hourly.pressure
        guard !pressureArr.isEmpty else {
            pressureInfo = nil
            return
        }

        let now = Date()
        let calendar = Calendar.current

        // Collect pressure readings from now through +10 hours
        var currentPressure: Double?
        var pressureAt10h: Double?
        var readings: [(date: Date, pressure: Double)] = []

        for i in 0..<min((hourly.time ?? []).count, pressureArr.count) {
            guard let date = hourlyDateFormatter.date(from: (hourly.time ?? [])[i]) else { continue }

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

        for i in 0..<(hourly.time ?? []).count {
            guard let date = hourlyDateFormatter.date(from: (hourly.time ?? [])[i]) else { continue }

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

    private func processComfort(_ hourly: HourlyData) {
        let dewPoints = hourly.dewPoint
        guard !dewPoints.isEmpty else { comfortInfo = nil; return }
        let now = Date()
        let calendar = Calendar.current

        for i in 0..<(hourly.time ?? []).count {
            guard let date = hourlyDateFormatter.date(from: (hourly.time ?? [])[i]),
                  calendar.isDate(date, equalTo: now, toGranularity: .hour) else { continue }
            guard i < dewPoints.count else { break }

            let dewPt = dewPoints[i]
            let dewPtF = UnitSettings.shared.toFahrenheit(dewPt)
            let humidity = hourly.humidityInts[safe: i] ?? 0

            comfortInfo = ComfortInfo(
                dewPoint: dewPt,
                humidity: humidity,
                level: ComfortLevel.from(dewPointF: dewPtF)
            )
            return
        }
    }

    private func processCloudCover(_ hourly: HourlyData) {
        let clouds = hourly.cloudCoverInts
        guard !clouds.isEmpty else { cloudCoverInfo = nil; return }
        let now = Date()
        let calendar = Calendar.current

        var currentTotal = 0, currentLow = 0, currentMid = 0, currentHigh = 0
        var readings: [(date: Date, total: Int, low: Int, mid: Int, high: Int)] = []

        for i in 0..<(hourly.time ?? []).count {
            guard let date = hourlyDateFormatter.date(from: (hourly.time ?? [])[i]) else { continue }
            guard let oneHourAgo = calendar.date(byAdding: .hour, value: -1, to: now),
                  date >= oneHourAgo else { continue }
            if readings.count >= 24 { break }

            let total = clouds[safe: i] ?? 0
            let low = hourly.cloudCoverLowInts[safe: i] ?? 0
            let mid = hourly.cloudCoverMidInts[safe: i] ?? 0
            let high = hourly.cloudCoverHighInts[safe: i] ?? 0

            if readings.isEmpty {
                currentTotal = total
                currentLow = low
                currentMid = mid
                currentHigh = high
            }
            readings.append((date: date, total: total, low: low, mid: mid, high: high))
        }

        cloudCoverInfo = CloudCoverInfo(
            total: currentTotal, low: currentLow, mid: currentMid, high: currentHigh,
            hourlyReadings: readings
        )
    }

    private func processSunshinePlan(_ hourly: HourlyData, daily: DailyData?) {
        let clouds = hourly.cloudCoverInts
        guard !clouds.isEmpty else { sunshinePlan = nil; return }
        let now = Date()
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: now)

        let sunshineSecs = daily?.sunshineValues.first ?? 0
        let daylightSecs = daily?.daylightValues.first ?? 1

        var slots: [SunshineSlot] = []

        // Only daytime hours (6am-9pm)
        for i in 0..<(hourly.time ?? []).count {
            guard let date = hourlyDateFormatter.date(from: (hourly.time ?? [])[i]) else { continue }
            guard calendar.isDate(date, inSameDayAs: today) else {
                if date > calendar.date(byAdding: .day, value: 1, to: today)! { break }
                continue
            }

            let hour = calendar.component(.hour, from: date)
            guard (6...21).contains(hour) else { continue }

            let cloud = clouds[safe: i] ?? 100
            let radiation = hourly.radiation[safe: i] ?? 0

            slots.append(SunshineSlot(
                time: date,
                cloudCover: cloud,
                radiation: radiation,
                isSunny: cloud < 40
            ))
        }

        // Find best consecutive sunny window
        var bestStart = 0, bestLen = 0, curStart = 0, curLen = 0
        for (i, slot) in slots.enumerated() {
            if slot.isSunny {
                if curLen == 0 { curStart = i }
                curLen += 1
                if curLen > bestLen { bestLen = curLen; bestStart = curStart }
            } else {
                curLen = 0
            }
        }

        let bestWindow: (start: Date, end: Date)?
        if bestLen >= 2, bestStart < slots.count {
            let endIdx = min(bestStart + bestLen - 1, slots.count - 1)
            bestWindow = (slots[bestStart].time, slots[endIdx].time.addingTimeInterval(3600))
        } else {
            bestWindow = nil
        }

        let sunnyHours = slots.filter(\.isSunny).count
        let summary: String
        if sunnyHours == 0 {
            summary = "Overcast all day — no clear sunshine expected"
        } else if sunnyHours >= slots.count - 2 {
            summary = "Mostly sunny — great day for outdoor activities"
        } else {
            summary = "\(sunnyHours) hours of sunshine expected today"
        }

        sunshinePlan = SunshinePlan(
            todaySunshineDuration: sunshineSecs,
            todayDaylightDuration: daylightSecs,
            sunshinePercent: daylightSecs > 0 ? (sunshineSecs / daylightSecs) * 100 : 0,
            slots: slots,
            bestWindow: bestWindow,
            summary: summary
        )
    }

    private func processGardening(_ hourly: HourlyData) {
        let soilTemps = hourly.soilTemp
        let soilMoistures = hourly.soilMoist
        guard !soilTemps.isEmpty, !soilMoistures.isEmpty else {
            gardeningInfo = nil
            return
        }

        let now = Date()
        let calendar = Calendar.current

        for i in 0..<(hourly.time ?? []).count {
            guard let date = hourlyDateFormatter.date(from: (hourly.time ?? [])[i]),
                  calendar.isDate(date, equalTo: now, toGranularity: .hour) else { continue }

            let temp = soilTemps[safe: i] ?? 0
            let moisture = (soilMoistures[safe: i] ?? 0) * 100 // Convert to percentage

            let tempF = UnitSettings.shared.toFahrenheit(temp)
            let frostRisk = tempF <= 32

            let wateringAdvice: String
            if moisture > 40 { wateringAdvice = "Soil is well-hydrated — no watering needed" }
            else if moisture > 25 { wateringAdvice = "Soil moisture is adequate" }
            else if moisture > 15 { wateringAdvice = "Consider watering your garden" }
            else { wateringAdvice = "Soil is dry — water your plants today" }

            let plantingAdvice: String
            if frostRisk { plantingAdvice = "Frost risk — protect sensitive plants" }
            else if tempF < 45 { plantingAdvice = "Too cold for most planting" }
            else if tempF < 60 { plantingAdvice = "Good for cool-season crops" }
            else if tempF < 85 { plantingAdvice = "Ideal conditions for planting" }
            else { plantingAdvice = "Hot soil — water after planting" }

            gardeningInfo = GardeningInfo(
                soilTemp: temp,
                soilMoisture: moisture,
                frostRisk: frostRisk,
                wateringAdvice: wateringAdvice,
                plantingAdvice: plantingAdvice
            )
            return
        }
    }

    private func processStormRisk(_ hourly: HourlyData) {
        let capeVals = hourly.capeValues
        guard !capeVals.isEmpty else { stormRisk = nil; return }
        let now = Date()
        let calendar = Calendar.current

        // Find max CAPE in the next 12 hours
        var maxCape: Double = 0
        var count = 0
        for i in 0..<(hourly.time ?? []).count {
            guard let date = hourlyDateFormatter.date(from: (hourly.time ?? [])[i]),
                  date >= now else { continue }
            if count >= 12 { break }
            if let c = capeVals[safe: i] { maxCape = max(maxCape, c) }
            count += 1
        }

        stormRisk = StormRiskInfo(
            cape: maxCape,
            level: StormRiskLevel.from(cape: maxCape)
        )
    }

    /// Get hourly forecasts for a specific date (for the day detail view)
    func hourlyForDate(_ date: Date) -> [HourlyForecast] {
        let calendar = Calendar.current
        return hourlyForecasts.filter { calendar.isDate($0.time, inSameDayAs: date) }
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

    // MARK: - Widget Data

    private func writeWidgetData(locationName: String) {
        let sharedHourly = hourlyForecasts.prefix(12).map { h in
            SharedHourly(time: h.time, temp: h.temperature, weatherCode: h.weatherCode, precipChance: h.precipChance)
        }

        let sharedDaily = dailyForecasts.prefix(7).map { d in
            SharedDaily(date: d.date, weatherCode: d.weatherCode, high: d.tempHigh, low: d.tempLow, precipChance: d.precipChance)
        }

        let sharedPrecip = precipTimeline?.slots.map { s in
            SharedPrecipSlot(minuteOffset: Swift.max(0, Int(s.time.timeIntervalSince(Date()) / 60)), precipitation: s.precipitation, intensity: s.intensity.rawValue)
        } ?? []

        // Build activity windows — score activities using default slots
        let calendar = Calendar.current
        let now = Date()
        var activityWindows: [SharedActivityWindow] = []
        let defaultBlocks: [(Int, Int)] = [(6,8),(8,10),(10,12),(12,14),(14,16),(16,18),(18,20),(20,22)]

        // Cover today and tomorrow
        for dayOffset in 0...1 {
            guard let day = calendar.date(byAdding: .day, value: dayOffset, to: now) else { continue }
            let isToday = dayOffset == 0

            for (startH, endH) in defaultBlocks {
                guard let start = calendar.date(bySettingHour: startH, minute: 0, second: 0, of: day),
                      let end = calendar.date(bySettingHour: endH, minute: 0, second: 0, of: day) else { continue }
                if isToday && end <= now { continue }

                let effectiveStart = isToday ? Swift.max(start, now) : start
                let slot = FreeTimeSlot(start: effectiveStart, end: end, source: .default)
                let scored = ActivityScorer.scoreActivities(
                    slots: [slot],
                    hourlyForecasts: hourlyForecasts
                )
                for window in scored {
                    activityWindows.append(SharedActivityWindow(
                        activity: window.activity.rawValue,
                        activityIcon: window.activity.icon,
                        startTime: window.slot.start,
                        endTime: window.slot.end,
                        score: window.score,
                        rating: window.rating.rawValue,
                        ratingColor: window.rating.color,
                        temp: window.avgTemp,
                        precipChance: window.maxPrecipChance,
                        isToday: isToday
                    ))
                }
            }
        }

        let data = SharedWeatherData(
            updatedAt: Date(),
            locationName: locationName,
            currentTemp: currentTemp,
            currentFeelsLike: hourlyForecasts.first?.feelsLike ?? currentTemp,
            currentWeatherCode: currentWeatherCode,
            currentCondition: currentCondition,
            isDay: isDay,
            todayHigh: todayHigh,
            todayLow: todayLow,
            hourly: Array(sharedHourly),
            daily: Array(sharedDaily),
            precipSlots: sharedPrecip,
            precipSummary: precipTimeline?.summary ?? "No precipitation data",
            isRaining: precipTimeline?.isRaining ?? false,
            nextRainChange: precipTimeline?.nextChangeLabel,
            activityWindows: activityWindows
        )

        WidgetDataStore.write(data)
        WidgetCenter.shared.reloadAllTimelines()
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
