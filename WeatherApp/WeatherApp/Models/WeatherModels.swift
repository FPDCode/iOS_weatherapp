import Foundation

// MARK: - Open-Meteo API Response

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
    let weathercode: [Int]
    let pressure: [Double]?
    let relativehumidity2m: [Int]
    let visibility: [Double]

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case precipitationProbability = "precipitation_probability"
        case precipitation
        case weathercode
        case pressure = "surface_pressure"
        case relativehumidity2m = "relativehumidity_2m"
        case visibility
    }
}

struct DailyData: Codable {
    let time: [String]
    let weathercode: [Int]
    let temperature2mMax: [Double]
    let temperature2mMin: [Double]
    let precipitationProbabilityMax: [Int]
    let sunrise: [String]
    let sunset: [String]

    enum CodingKeys: String, CodingKey {
        case time, weathercode
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
        case precipitationProbabilityMax = "precipitation_probability_max"
        case sunrise, sunset
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
        case .night: return 22...29 // wraps to next day 0-5
        }
    }

    var gradient: [String] {
        switch self {
        case .morning: return ["FFA751", "FFE259"]
        case .afternoon: return ["2196F3", "73C8F5"]
        case .evening: return ["FC5C7D", "6A82FB"]
        case .night: return ["0F2027", "2C5364"]
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
}

struct DailyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let weatherCode: Int
    let tempHigh: Double
    let tempLow: Double
    let precipChance: Int
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

    static func color(for code: Int) -> String {
        switch code {
        case 0, 1: return "FFD700"
        case 2, 3: return "A0AEC0"
        case 45, 48: return "CBD5E0"
        case 51...57: return "63B3ED"
        case 61...67: return "4299E1"
        case 71...77: return "E2E8F0"
        case 80...86: return "2B6CB0"
        case 95, 96, 99: return "805AD5"
        default: return "A0AEC0"
        }
    }
}
