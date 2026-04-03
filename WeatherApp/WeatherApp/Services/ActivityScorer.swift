import Foundation

// MARK: - Activity Types

enum OutdoorActivity: String, CaseIterable, Identifiable {
    case running = "Running"
    case walking = "Walking"
    case cycling = "Cycling"
    case errands = "Errands"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .errands: return "bag.fill"
        }
    }

    var idealTempRange: ClosedRange<Double> {
        switch self {
        case .running: return 45...65
        case .walking: return 55...75
        case .cycling: return 50...70
        case .errands: return 40...85
        }
    }

    var maxWindMph: Double {
        switch self {
        case .running: return 15
        case .walking: return 20
        case .cycling: return 12
        case .errands: return 25
        }
    }

    var maxPrecipChance: Int {
        switch self {
        case .running: return 20
        case .walking: return 15
        case .cycling: return 10
        case .errands: return 40
        }
    }

    var minDurationMinutes: Int {
        switch self {
        case .running: return 30
        case .walking: return 30
        case .cycling: return 45
        case .errands: return 30
        }
    }
}

// MARK: - Scored Activity Window

struct ScoredActivityWindow: Identifiable {
    let id = UUID()
    let activity: OutdoorActivity
    let slot: FreeTimeSlot
    let score: Double // 0-100
    let avgTemp: Double
    let avgFeelsLike: Double
    let maxPrecipChance: Int
    let avgWind: Double
    let weatherCode: Int
    let reasons: [String] // Why this slot is good/bad

    var rating: ActivityRating {
        switch score {
        case 80...100: return .excellent
        case 60..<80: return .good
        case 40..<60: return .fair
        default: return .poor
        }
    }
}

enum ActivityRating: String {
    case excellent = "Excellent"
    case good = "Good"
    case fair = "Fair"
    case poor = "Poor"

    var color: String {
        switch self {
        case .excellent: return "34D399" // green
        case .good: return "60A5FA"     // blue
        case .fair: return "FBBF24"     // yellow
        case .poor: return "F87171"     // red
        }
    }

    var icon: String {
        switch self {
        case .excellent: return "star.fill"
        case .good: return "hand.thumbsup.fill"
        case .fair: return "hand.raised.fill"
        case .poor: return "xmark.circle.fill"
        }
    }
}

// MARK: - Scorer

struct ActivityScorer {

    static func scoreActivities(
        slots: [FreeTimeSlot],
        hourlyForecasts: [HourlyForecast],
        activities: [OutdoorActivity] = OutdoorActivity.allCases
    ) -> [ScoredActivityWindow] {

        var results: [ScoredActivityWindow] = []

        for activity in activities {
            for slot in slots {
                guard slot.durationMinutes >= activity.minDurationMinutes else { continue }

                // Find hourly forecasts that overlap this slot
                let overlapping = hourlyForecasts.filter { forecast in
                    let forecastEnd = forecast.time.addingTimeInterval(3600)
                    return forecast.time < slot.end && forecastEnd > slot.start
                }

                guard !overlapping.isEmpty else { continue }

                let scored = scoreSlot(activity: activity, slot: slot, forecasts: overlapping)
                results.append(scored)
            }
        }

        return results.sorted { $0.score > $1.score }
    }

    private static func scoreSlot(
        activity: OutdoorActivity,
        slot: FreeTimeSlot,
        forecasts: [HourlyForecast]
    ) -> ScoredActivityWindow {

        let avgTemp = forecasts.map(\.temperature).reduce(0, +) / Double(forecasts.count)
        let avgFeels = forecasts.map(\.feelsLike).reduce(0, +) / Double(forecasts.count)
        let maxPrecip = forecasts.map(\.precipChance).max() ?? 0
        let avgWind = forecasts.map(\.windSpeed).reduce(0, +) / Double(forecasts.count)
        let dominantCode = mostFrequent(forecasts.map(\.weatherCode)) ?? 0

        var score: Double = 100
        var reasons: [String] = []

        // Temperature scoring (0-35 points)
        let tempRange = activity.idealTempRange
        if tempRange.contains(avgTemp) {
            reasons.append("\(Int(avgTemp))° — ideal temperature")
        } else if avgTemp < tempRange.lowerBound {
            let diff = tempRange.lowerBound - avgTemp
            score -= min(diff * 1.5, 35)
            reasons.append("\(Int(avgTemp))° — cooler than ideal")
        } else {
            let diff = avgTemp - tempRange.upperBound
            score -= min(diff * 1.5, 35)
            reasons.append("\(Int(avgTemp))° — warmer than ideal")
        }

        // Precipitation scoring (0-30 points)
        if maxPrecip <= 5 {
            reasons.append("No rain expected")
        } else if maxPrecip <= activity.maxPrecipChance {
            score -= Double(maxPrecip) * 0.5
            reasons.append("\(maxPrecip)% rain chance")
        } else {
            score -= Double(maxPrecip) * 0.8
            reasons.append("\(maxPrecip)% rain — risky")
        }

        // Wind scoring (0-20 points)
        if avgWind <= activity.maxWindMph * 0.5 {
            reasons.append("Calm winds")
        } else if avgWind <= activity.maxWindMph {
            score -= (avgWind / activity.maxWindMph) * 10
            reasons.append("\(Int(avgWind)) mph wind")
        } else {
            score -= 20 + (avgWind - activity.maxWindMph) * 2
            reasons.append("\(Int(avgWind)) mph — too windy")
        }

        // Feels-like penalty
        let feelsLikeDiff = abs(avgTemp - avgFeels)
        if feelsLikeDiff > 10 {
            score -= 5
            reasons.append("Feels like \(Int(avgFeels))°")
        }

        // Severe weather penalty
        if dominantCode >= 95 {
            score -= 40
            reasons.append("Thunderstorm warning")
        } else if dominantCode >= 61 {
            score -= 15
            reasons.append(WeatherCodeInfo.description(for: dominantCode))
        }

        // Time-of-day bonus for running (early morning is nice)
        let hour = Calendar.current.component(.hour, from: slot.start)
        if activity == .running && (6...9).contains(hour) {
            score += 5
            reasons.append("Great morning time")
        }

        score = max(0, min(100, score))

        return ScoredActivityWindow(
            activity: activity,
            slot: slot,
            score: score,
            avgTemp: avgTemp,
            avgFeelsLike: avgFeels,
            maxPrecipChance: maxPrecip,
            avgWind: avgWind,
            weatherCode: dominantCode,
            reasons: reasons
        )
    }

    private static func mostFrequent(_ array: [Int]) -> Int? {
        var counts: [Int: Int] = [:]
        array.forEach { counts[$0, default: 0] += 1 }
        return counts.max(by: { $0.value < $1.value })?.key
    }
}
