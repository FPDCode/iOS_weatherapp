import Foundation

// MARK: - Open-Meteo Forecast API Response

struct WeatherResponse: Codable {
    let latitude: Double
    let longitude: Double
    let currentWeather: CurrentWeather?
    let hourly: HourlyData?
    let daily: DailyData?

    enum CodingKeys: String, CodingKey {
        case latitude, longitude
        case currentWeather = "current_weather"
        case hourly, daily
    }
}

struct CurrentWeather: Codable {
    let temperature: Double
    let windspeed: Double
    let winddirection: Double
    let weathercode: Int
    let isDay: Int
    let time: String

    enum CodingKeys: String, CodingKey {
        case temperature, windspeed, winddirection, weathercode
        case isDay = "is_day"
        case time
    }
}

struct HourlyData: Codable {
    let time: [String]
    let temperature2m: [Double]
    let apparentTemperature: [Double]
    let precipitationProbability: [Int]
    let precipitation: [Double]
    let weatherCode: [Int]
    let surfacePressure: [Double]?
    let relativeHumidity2m: [Int]
    let visibility: [Double]
    let windSpeed10m: [Double]
    let uvIndex: [Double]?

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case precipitationProbability = "precipitation_probability"
        case precipitation
        case weatherCode = "weather_code"
        case surfacePressure = "surface_pressure"
        case relativeHumidity2m = "relative_humidity_2m"
        case visibility
        case windSpeed10m = "wind_speed_10m"
        case uvIndex = "uv_index"
    }
}

struct DailyData: Codable {
    let time: [String]
    let weatherCode: [Int]
    let temperature2mMax: [Double]
    let temperature2mMin: [Double]
    let precipitationProbabilityMax: [Int]
    let sunrise: [String]
    let sunset: [String]
    let uvIndexMax: [Double]?

    enum CodingKeys: String, CodingKey {
        case time
        case weatherCode = "weather_code"
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
        case precipitationProbabilityMax = "precipitation_probability_max"
        case sunrise, sunset
        case uvIndexMax = "uv_index_max"
    }
}

// MARK: - Open-Meteo Air Quality API Response

struct AirQualityResponse: Codable {
    let latitude: Double
    let longitude: Double
    let hourly: AirQualityHourly?
}

struct AirQualityHourly: Codable {
    let time: [String]
    let europeanAqi: [Int?]?
    let usAqi: [Int?]?
    let pm25: [Double?]?
    let pm10: [Double?]?
    let alderPollen: [Double?]?
    let birchPollen: [Double?]?
    let grassPollen: [Double?]?
    let mugwortPollen: [Double?]?
    let olivePollen: [Double?]?
    let ragweedPollen: [Double?]?

    enum CodingKeys: String, CodingKey {
        case time
        case europeanAqi = "european_aqi"
        case usAqi = "us_aqi"
        case pm25 = "pm2_5"
        case pm10
        case alderPollen = "alder_pollen"
        case birchPollen = "birch_pollen"
        case grassPollen = "grass_pollen"
        case mugwortPollen = "mugwort_pollen"
        case olivePollen = "olive_pollen"
        case ragweedPollen = "ragweed_pollen"
    }
}

// MARK: - App Models

struct DayPhaseWeather: Identifiable {
    let id = UUID()
    let phase: DayPhase
    let temperature: Double
    let feelsLike: Double
    let weatherCode: Int
    let precipChance: Int
    let humidity: Int
    let windSpeed: Double?
    let uvIndex: Double?
}

enum DayPhase: String, CaseIterable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
    case night = "Night"

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var hourRange: ClosedRange<Int> {
        switch self {
        case .morning: return 6...11
        case .afternoon: return 12...17
        case .evening: return 18...21
        case .night: return 22...29
        }
    }
}

struct HourlyForecast: Identifiable {
    let id = UUID()
    let time: Date
    let temperature: Double
    let feelsLike: Double
    let precipChance: Int
    let precipAmount: Double
    let weatherCode: Int
    let pressure: Double
    let humidity: Int
    let visibility: Double
    let windSpeed: Double
    let uvIndex: Double
}

struct DailyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let weatherCode: Int
    let tempHigh: Double
    let tempLow: Double
    let precipChance: Int
    let uvIndexMax: Double
}

struct AirQualityInfo {
    let aqi: Int
    let pm25: Double
    let pm10: Double
    let level: AQILevel
    let pollenSummary: PollenSummary?
}

enum AQILevel: String {
    case good = "Good"
    case fair = "Fair"
    case moderate = "Moderate"
    case poor = "Poor"
    case veryPoor = "Very Poor"
    case hazardous = "Hazardous"

    var color: String {
        switch self {
        case .good: return "34D399"
        case .fair: return "60A5FA"
        case .moderate: return "FBBF24"
        case .poor: return "FB923C"
        case .veryPoor: return "F87171"
        case .hazardous: return "A855F7"
        }
    }

    var icon: String {
        switch self {
        case .good: return "aqi.low"
        case .fair: return "aqi.medium"
        case .moderate: return "aqi.medium"
        case .poor: return "aqi.high"
        case .veryPoor: return "aqi.high"
        case .hazardous: return "aqi.high"
        }
    }

    static func from(usAqi: Int) -> AQILevel {
        switch usAqi {
        case 0...50: return .good
        case 51...100: return .fair
        case 101...150: return .moderate
        case 151...200: return .poor
        case 201...300: return .veryPoor
        default: return .hazardous
        }
    }
}

struct PollenSummary {
    let grassLevel: PollenLevel
    let treeLevel: PollenLevel
    let weedLevel: PollenLevel

    var overallLevel: PollenLevel {
        [grassLevel, treeLevel, weedLevel].max(by: { $0.rawValue < $1.rawValue }) ?? .none
    }
}

enum PollenLevel: Int, Comparable {
    case none = 0
    case low = 1
    case moderate = 2
    case high = 3
    case veryHigh = 4

    static func < (lhs: PollenLevel, rhs: PollenLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }

    var color: String {
        switch self {
        case .none: return "34D399"
        case .low: return "60A5FA"
        case .moderate: return "FBBF24"
        case .high: return "FB923C"
        case .veryHigh: return "F87171"
        }
    }

    /// Grains/m³ thresholds (approximate, varies by species)
    static func from(grainsPerM3: Double) -> PollenLevel {
        switch grainsPerM3 {
        case ..<1: return .none
        case 1..<25: return .low
        case 25..<50: return .moderate
        case 50..<100: return .high
        default: return .veryHigh
        }
    }
}

// MARK: - Weather Code Helpers

struct WeatherCodeInfo {
    static func description(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Unknown"
        }
    }

    static func sfSymbol(for code: Int, isDay: Bool = true) -> String {
        switch code {
        case 0:
            return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1:
            return isDay ? "sun.min.fill" : "moon.fill"
        case 2:
            return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55:
            return "cloud.drizzle.fill"
        case 56, 57:
            return "cloud.sleet.fill"
        case 61, 63, 65:
            return "cloud.rain.fill"
        case 66, 67:
            return "cloud.sleet.fill"
        case 71, 73, 75, 77:
            return "cloud.snow.fill"
        case 80, 81, 82:
            return "cloud.heavyrain.fill"
        case 85, 86:
            return "cloud.snow.fill"
        case 95, 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return "questionmark.circle"
        }
    }
}
