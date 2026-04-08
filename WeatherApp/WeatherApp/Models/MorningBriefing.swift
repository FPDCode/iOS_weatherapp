import Foundation

struct MorningBriefing {
    let clothingSuggestion: ClothingSuggestion
    let umbrellaNeeded: Bool
    let maxPrecipToday: Int
    let commuteOut: CommuteForecast?
    let commuteReturn: CommuteForecast?
    let sunriseSunset: String
    let alerts: [WeatherAlert]

    static func generate(
        phases: [DayPhaseWeather],
        hourly: [HourlyForecast],
        high: Double,
        low: Double,
        sunrise: String,
        sunset: String,
        commuteOutHour: Int = 8,
        commuteReturnHour: Int = 18
    ) -> MorningBriefing {
        let maxPrecip = hourly.prefix(24).map(\.precipChance).max() ?? 0
        let umbrella = maxPrecip >= 30

        let clothing = ClothingSuggestion.forConditions(
            high: high,
            low: low,
            maxWind: hourly.prefix(12).map(\.windSpeed).max() ?? 0,
            precipChance: maxPrecip
        )

        let calendar = Calendar.current

        let commuteOut = hourly.first { forecast in
            calendar.component(.hour, from: forecast.time) == commuteOutHour
        }.map { forecast in
            return CommuteForecast(label: "Departure", time: WeatherFormatters.shortTime(forecast.time), forecast: forecast)
        }

        let commuteReturn = hourly.first { forecast in
            calendar.component(.hour, from: forecast.time) == commuteReturnHour
        }.map { forecast in
            return CommuteForecast(label: "Return", time: WeatherFormatters.shortTime(forecast.time), forecast: forecast)
        }

        // Alerts — with timing info so user can plan ahead
        let now = Date()
        var alerts: [WeatherAlert] = []
        let settings = UnitSettings.shared

        // Heavy rain alert
        if maxPrecip >= 70 {
            let rainStart = hourly.prefix(24).first { $0.precipChance >= 60 }
            let timing = Self.timingLabel(from: now, to: rainStart?.time)
            alerts.append(WeatherAlert(icon: "cloud.heavyrain.fill", message: "Heavy rain expected — up to \(maxPrecip)% chance", severity: .warning, timing: timing))
        }

        // Strong wind alert
        let maxWind = hourly.prefix(24).map(\.windSpeed).max() ?? 0
        if maxWind >= settings.toMph(25) {
            let windStart = hourly.prefix(24).first { $0.windSpeed >= settings.toMph(25) }
            let timing = Self.timingLabel(from: now, to: windStart?.time)
            alerts.append(WeatherAlert(icon: "wind", message: "Strong winds up to \(WeatherFormatters.windSpeed(maxWind))", severity: .caution, timing: timing))
        }

        // Extreme heat
        if high >= settings.threshold(fahrenheit: 95) {
            let peakHour = hourly.prefix(24).max(by: { $0.temperature < $1.temperature })
            let timing = Self.timingLabel(from: now, to: peakHour?.time, verb: "Peaks")
            alerts.append(WeatherAlert(icon: "thermometer.sun.fill", message: "Extreme heat — stay hydrated", severity: .warning, timing: timing))
        }

        // Freezing temps
        if low <= settings.threshold(fahrenheit: 32) {
            let freezeHour = hourly.prefix(24).first { $0.temperature <= settings.threshold(fahrenheit: 32) }
            let timing = Self.timingLabel(from: now, to: freezeHour?.time)
            alerts.append(WeatherAlert(icon: "thermometer.snowflake", message: "Freezing temperatures expected", severity: .caution, timing: timing))
        }

        return MorningBriefing(
            clothingSuggestion: clothing,
            umbrellaNeeded: umbrella,
            maxPrecipToday: maxPrecip,
            commuteOut: commuteOut,
            commuteReturn: commuteReturn,
            sunriseSunset: "\(sunrise) → \(sunset)",
            alerts: alerts
        )
    }

    private static func timingLabel(from now: Date, to target: Date?, verb: String = "Starting") -> String? {
        guard let target else { return nil }
        let minutes = Int(target.timeIntervalSince(now) / 60)
        if minutes <= 0 {
            return "Happening now"
        }
        let timeStr = WeatherFormatters.shortTime(target)
        if minutes < 60 {
            return "\(verb) around \(timeStr) — in \(minutes)m"
        }
        let hours = minutes / 60
        let remainMins = minutes % 60
        if remainMins == 0 {
            return "\(verb) around \(timeStr) — in \(hours)h"
        }
        return "\(verb) around \(timeStr) — in \(hours)h \(remainMins)m"
    }
}

// MARK: - Clothing

struct ClothingSuggestion {
    let layers: String
    let icon: String
    let extras: [String]

    static func forConditions(high: Double, low: Double, maxWind: Double, precipChance: Int) -> ClothingSuggestion {
        let settings = UnitSettings.shared
        let avgTemp = (high + low) / 2
        var extras: [String] = []

        // Thresholds adapt to the user's chosen temperature unit
        let freezing = settings.threshold(fahrenheit: 32)
        let cool = settings.threshold(fahrenheit: 50)
        let mild = settings.threshold(fahrenheit: 65)
        let warm = settings.threshold(fahrenheit: 80)

        let (layers, icon): (String, String)
        switch avgTemp {
        case ..<freezing:
            layers = "Heavy winter coat, thermal layers"
            icon = "snowflake"
            extras.append("Gloves & hat")
            extras.append("Warm boots")
        case freezing..<cool:
            layers = "Warm jacket and long sleeves"
            icon = "cloud.fill"
            extras.append("Scarf recommended")
        case cool..<mild:
            layers = "Light jacket or sweater"
            icon = "sun.haze.fill"
        case mild..<warm:
            layers = "Light clothing, short sleeves"
            icon = "sun.max.fill"
        default:
            layers = "Minimal, breathable clothing"
            icon = "sun.max.fill"
            extras.append("Sunscreen recommended")
            extras.append("Stay hydrated")
        }

        if precipChance >= 30 {
            extras.append("Umbrella")
        }
        if precipChance >= 50 {
            extras.append("Rain jacket")
        }
        // Wind threshold: 20 mph normalized to current unit
        if maxWind >= settings.toMph(20) {
            extras.append("Windbreaker")
        }

        return ClothingSuggestion(layers: layers, icon: icon, extras: extras)
    }
}

// MARK: - Commute

struct CommuteForecast: Identifiable {
    let id = UUID()
    let label: String
    let time: String
    let forecast: HourlyForecast
}

// MARK: - Alerts

struct WeatherAlert: Identifiable {
    let id = UUID()
    let icon: String
    let message: String
    let severity: AlertSeverity
    let timing: String? // e.g. "Starting around 2 PM — in 3h"

    enum AlertSeverity {
        case caution
        case warning
    }
}
