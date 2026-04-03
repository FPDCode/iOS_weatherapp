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
        let timeFormatter = DateFormatter()
        timeFormatter.dateFormat = "h:mm a"

        let commuteOut = hourly.first { forecast in
            calendar.component(.hour, from: forecast.time) == commuteOutHour
        }.map { forecast in
            let timeStr = timeFormatter.string(from: forecast.time)
            return CommuteForecast(label: "Departure", time: timeStr, forecast: forecast)
        }

        let commuteReturn = hourly.first { forecast in
            calendar.component(.hour, from: forecast.time) == commuteReturnHour
        }.map { forecast in
            let timeStr = timeFormatter.string(from: forecast.time)
            return CommuteForecast(label: "Return", time: timeStr, forecast: forecast)
        }

        // Alerts
        var alerts: [WeatherAlert] = []
        if maxPrecip >= 70 {
            alerts.append(WeatherAlert(icon: "cloud.heavyrain.fill", message: "Heavy rain expected today", severity: .warning))
        }
        let maxWind = hourly.prefix(24).map(\.windSpeed).max() ?? 0
        if maxWind >= 25 {
            alerts.append(WeatherAlert(icon: "wind", message: "Strong winds up to \(Int(maxWind)) mph", severity: .caution))
        }
        if high >= 95 {
            alerts.append(WeatherAlert(icon: "thermometer.sun.fill", message: "Extreme heat — stay hydrated", severity: .warning))
        }
        if low <= 32 {
            alerts.append(WeatherAlert(icon: "thermometer.snowflake", message: "Freezing temperatures expected", severity: .caution))
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
}

// MARK: - Clothing

struct ClothingSuggestion {
    let layers: String
    let icon: String
    let extras: [String]

    static func forConditions(high: Double, low: Double, maxWind: Double, precipChance: Int) -> ClothingSuggestion {
        let avgTemp = (high + low) / 2
        var extras: [String] = []

        let (layers, icon): (String, String)
        switch avgTemp {
        case ..<32:
            layers = "Heavy winter coat, thermal layers"
            icon = "snowflake"
            extras.append("Gloves & hat")
            extras.append("Warm boots")
        case 32..<50:
            layers = "Warm jacket and long sleeves"
            icon = "cloud.fill"
            extras.append("Scarf recommended")
        case 50..<65:
            layers = "Light jacket or sweater"
            icon = "sun.haze.fill"
        case 65..<80:
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
        if maxWind >= 20 {
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

    enum AlertSeverity {
        case caution
        case warning
    }
}
