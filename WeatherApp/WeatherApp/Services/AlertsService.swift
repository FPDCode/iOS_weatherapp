import Foundation

// MARK: - NWS Alerts API (api.weather.gov)

actor NWSAlertsService {
    static let shared = NWSAlertsService()

    private let baseURL = "https://api.weather.gov/alerts/active"

    func fetchAlerts(latitude: Double, longitude: Double) async throws -> [NWSAlert] {
        // NWS uses point-based alerts
        var components = URLComponents(string: baseURL)!
        components.queryItems = [
            URLQueryItem(name: "point", value: "\(latitude),\(longitude)"),
            URLQueryItem(name: "status", value: "actual"),
            URLQueryItem(name: "message_type", value: "alert,update"),
        ]

        guard let url = components.url else { return [] }

        var request = URLRequest(url: url)
        request.setValue("application/geo+json", forHTTPHeaderField: "Accept")
        // NWS requires a User-Agent with contact info
        request.setValue("WeatherApp/1.0 (iOS Weather App)", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            return []
        }

        let decoded = try JSONDecoder().decode(NWSAlertResponse.self, from: data)
        return decoded.features.compactMap { feature -> NWSAlert? in
            let props = feature.properties
            guard let event = props.event,
                  let severity = props.severity else { return nil }

            return NWSAlert(
                id: props.id ?? UUID().uuidString,
                event: event,
                headline: props.headline,
                description: props.alertDescription,
                severity: NWSAlertSeverity.from(props: severity),
                urgency: props.urgency ?? "Unknown",
                certainty: props.certainty ?? "Unknown",
                senderName: props.senderName,
                onset: parseDate(props.onset),
                expires: parseDate(props.expires),
                instruction: props.instruction
            )
        }
    }

    private func parseDate(_ dateStr: String?) -> Date? {
        guard let dateStr else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: dateStr) { return date }
        // Try without fractional seconds
        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: dateStr)
    }
}

// MARK: - NWS Response Models

struct NWSAlertResponse: Codable {
    let features: [NWSAlertFeature]
}

struct NWSAlertFeature: Codable {
    let properties: NWSAlertProperties
}

struct NWSAlertProperties: Codable {
    let id: String?
    let event: String?
    let headline: String?
    let alertDescription: String?
    let severity: String?
    let urgency: String?
    let certainty: String?
    let senderName: String?
    let onset: String?
    let expires: String?
    let instruction: String?

    enum CodingKeys: String, CodingKey {
        case id, event, headline
        case alertDescription = "description"
        case severity, urgency, certainty, senderName
        case onset, expires, instruction
    }
}

// MARK: - App Alert Models

struct NWSAlert: Identifiable {
    let id: String
    let event: String
    let headline: String?
    let description: String?
    let severity: NWSAlertSeverity
    let urgency: String
    let certainty: String
    let senderName: String?
    let onset: Date?
    let expires: Date?
    let instruction: String?
}

enum NWSAlertSeverity: String {
    case extreme = "Extreme"
    case severe = "Severe"
    case moderate = "Moderate"
    case minor = "Minor"
    case unknown = "Unknown"

    var color: String {
        switch self {
        case .extreme: return "DC2626"  // dark red
        case .severe: return "F87171"   // red
        case .moderate: return "FB923C" // orange
        case .minor: return "FBBF24"   // yellow
        case .unknown: return "A0AEC0"  // gray
        }
    }

    var icon: String {
        switch self {
        case .extreme: return "exclamationmark.octagon.fill"
        case .severe: return "exclamationmark.triangle.fill"
        case .moderate: return "exclamationmark.triangle.fill"
        case .minor: return "info.circle.fill"
        case .unknown: return "questionmark.circle"
        }
    }

    static func from(props severity: String) -> NWSAlertSeverity {
        switch severity.lowercased() {
        case "extreme": return .extreme
        case "severe": return .severe
        case "moderate": return .moderate
        case "minor": return .minor
        default: return .unknown
        }
    }
}

// MARK: - Smart Warning Engine

struct SmartWarning: Identifiable {
    let id = UUID()
    let type: WarningType
    let severity: WarningSeverity
    let title: String
    let message: String
    let icon: String

    enum WarningSeverity: Int, Comparable {
        case info = 0
        case advisory = 1
        case watch = 2
        case warning = 3

        static func < (lhs: WarningSeverity, rhs: WarningSeverity) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var color: String {
            switch self {
            case .info: return "60A5FA"
            case .advisory: return "FBBF24"
            case .watch: return "FB923C"
            case .warning: return "F87171"
            }
        }
    }

    enum WarningType: String {
        case severeStorm
        case stormApproaching
        case extremeUV
        case unhealthyAir
        case highWind
        case lowVisibility
        case extremeHeat
        case extremeCold
        case freezingRain
        case allergyAlert
        case frostAdvisory
        case rapidPressureDrop
        case heavyRain
    }
}

struct SmartWarningEngine {
    static func analyze(
        hourlyForecasts: [HourlyForecast],
        pressureInfo: PressureInfo?,
        windInfo: WindInfo?,
        airQuality: AirQualityInfo?,
        stormRisk: StormRiskInfo?,
        gardeningInfo: GardeningInfo?,
        todayUVIndex: Double,
        todayHigh: Double,
        todayLow: Double
    ) -> [SmartWarning] {
        var warnings: [SmartWarning] = []
        let settings = UnitSettings.shared

        // --- Severe Storm Risk ---
        if let storm = stormRisk, storm.level == .moderate || storm.level == .high {
            warnings.append(SmartWarning(
                type: .severeStorm,
                severity: storm.level == .high ? .warning : .watch,
                title: "Thunderstorm Risk",
                message: "CAPE at \(Int(storm.cape)) J/kg — \(storm.level.rawValue.lowercased()) risk of severe thunderstorms in the next 12 hours",
                icon: "cloud.bolt.rain.fill"
            ))
        }

        // --- Rapid Pressure Drop ---
        if let pressure = pressureInfo {
            let change = pressure.pressureIn10h - pressure.currentPressure
            if change < -6 {
                warnings.append(SmartWarning(
                    type: .rapidPressureDrop,
                    severity: .watch,
                    title: "Rapid Pressure Drop",
                    message: "Pressure falling \(String(format: "%.1f", abs(change))) hPa in 10h — stormy conditions likely",
                    icon: "arrow.down.circle.fill"
                ))
            }
        }

        // --- High Wind ---
        if let wind = windInfo {
            let gustMph = settings.toMph(wind.gusts)
            if gustMph >= 50 {
                warnings.append(SmartWarning(
                    type: .highWind,
                    severity: .warning,
                    title: "High Wind Warning",
                    message: "Gusts up to \(WeatherFormatters.windSpeed(wind.gusts)) — secure loose objects",
                    icon: "wind"
                ))
            } else if gustMph >= 35 {
                warnings.append(SmartWarning(
                    type: .highWind,
                    severity: .advisory,
                    title: "Wind Advisory",
                    message: "Gusts up to \(WeatherFormatters.windSpeed(wind.gusts)) expected",
                    icon: "wind"
                ))
            }
        }

        // --- Extreme UV ---
        if todayUVIndex >= 11 {
            warnings.append(SmartWarning(
                type: .extremeUV,
                severity: .warning,
                title: "Extreme UV Index",
                message: "UV index \(Int(todayUVIndex)) — avoid sun exposure midday, wear SPF 50+",
                icon: "sun.max.trianglebadge.exclamationmark"
            ))
        } else if todayUVIndex >= 8 {
            warnings.append(SmartWarning(
                type: .extremeUV,
                severity: .advisory,
                title: "Very High UV",
                message: "UV index \(Int(todayUVIndex)) — sunscreen and shade recommended",
                icon: "sun.max.fill"
            ))
        }

        // --- Air Quality ---
        if let aq = airQuality {
            if aq.aqi > 200 {
                warnings.append(SmartWarning(
                    type: .unhealthyAir,
                    severity: .warning,
                    title: "Hazardous Air Quality",
                    message: "AQI \(aq.aqi) — avoid all outdoor activity, close windows",
                    icon: "aqi.high"
                ))
            } else if aq.aqi > 150 {
                warnings.append(SmartWarning(
                    type: .unhealthyAir,
                    severity: .watch,
                    title: "Unhealthy Air Quality",
                    message: "AQI \(aq.aqi) — sensitive groups should limit outdoor exposure",
                    icon: "aqi.high"
                ))
            }
        }

        // --- Extreme Heat ---
        let highF = settings.toFahrenheit(todayHigh)
        if highF >= 105 {
            warnings.append(SmartWarning(
                type: .extremeHeat,
                severity: .warning,
                title: "Extreme Heat Warning",
                message: "High of \(WeatherFormatters.temperature(todayHigh)) — heat stroke risk, stay indoors",
                icon: "thermometer.sun.fill"
            ))
        } else if highF >= 95 {
            warnings.append(SmartWarning(
                type: .extremeHeat,
                severity: .advisory,
                title: "Heat Advisory",
                message: "High of \(WeatherFormatters.temperature(todayHigh)) — stay hydrated, limit outdoor activity",
                icon: "thermometer.sun.fill"
            ))
        }

        // --- Extreme Cold ---
        let lowF = settings.toFahrenheit(todayLow)
        if lowF <= -10 {
            warnings.append(SmartWarning(
                type: .extremeCold,
                severity: .warning,
                title: "Extreme Cold Warning",
                message: "Low of \(WeatherFormatters.temperature(todayLow)) — frostbite risk, limit exposure",
                icon: "thermometer.snowflake"
            ))
        } else if lowF <= 15 {
            warnings.append(SmartWarning(
                type: .extremeCold,
                severity: .advisory,
                title: "Cold Advisory",
                message: "Low of \(WeatherFormatters.temperature(todayLow)) — dress in warm layers",
                icon: "thermometer.snowflake"
            ))
        }

        // --- Low Visibility ---
        if let firstHour = hourlyForecasts.first, firstHour.visibility < 500 {
            warnings.append(SmartWarning(
                type: .lowVisibility,
                severity: .advisory,
                title: "Low Visibility",
                message: "Visibility under \(WeatherFormatters.visibility(firstHour.visibility)) — use caution driving",
                icon: "cloud.fog.fill"
            ))
        }

        // --- Freezing Rain ---
        let next6 = hourlyForecasts.prefix(6)
        let hasFreezing = next6.contains { settings.toFahrenheit($0.temperature) <= 33 && $0.precipAmount > 0.1 }
        if hasFreezing {
            warnings.append(SmartWarning(
                type: .freezingRain,
                severity: .watch,
                title: "Freezing Rain Risk",
                message: "Near-freezing temperatures with precipitation — icy roads possible",
                icon: "cloud.sleet.fill"
            ))
        }

        // --- Heavy Rain ---
        let maxPrecip6h = next6.map(\.precipAmount).reduce(0, +)
        if maxPrecip6h > 25 { // 25mm in 6 hours
            warnings.append(SmartWarning(
                type: .heavyRain,
                severity: .watch,
                title: "Heavy Rain",
                message: "Significant rainfall expected in the next 6 hours — flash flood risk",
                icon: "cloud.heavyrain.fill"
            ))
        }

        // --- Allergy Alert ---
        if let pollen = airQuality?.pollenSummary, pollen.overallLevel == .veryHigh {
            warnings.append(SmartWarning(
                type: .allergyAlert,
                severity: .advisory,
                title: "High Pollen Alert",
                message: "Very high pollen levels — take antihistamines, keep windows closed",
                icon: "leaf.fill"
            ))
        }

        // --- Frost Advisory ---
        if let garden = gardeningInfo, garden.frostRisk {
            warnings.append(SmartWarning(
                type: .frostAdvisory,
                severity: .info,
                title: "Frost Advisory",
                message: "Ground temperature near freezing — protect sensitive plants",
                icon: "snowflake"
            ))
        }

        // Sort by severity (highest first)
        return warnings.sorted { $0.severity > $1.severity }
    }
}
