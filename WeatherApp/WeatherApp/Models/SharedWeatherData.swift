import Foundation

/// Lightweight weather snapshot written by the main app to the App Group
/// container so widgets can read it. Kept minimal to avoid large payloads.
struct SharedWeatherData: Codable {
    let updatedAt: Date
    let locationName: String

    // Current conditions
    let currentTemp: Double
    let currentFeelsLike: Double
    let currentWeatherCode: Int
    let currentCondition: String
    let isDay: Bool
    let todayHigh: Double
    let todayLow: Double

    // Hourly (next 12 hours)
    let hourly: [SharedHourly]

    // Daily (next 7 days)
    let daily: [SharedDaily]

    // Precipitation (next 2h, 15-min slots)
    let precipSlots: [SharedPrecipSlot]
    let precipSummary: String
    let isRaining: Bool
    let nextRainChange: String?

    // Best time for activities
    let activityWindows: [SharedActivityWindow]
}

struct SharedHourly: Codable {
    let time: Date
    let temp: Double
    let weatherCode: Int
    let precipChance: Int
}

struct SharedDaily: Codable {
    let date: Date
    let weatherCode: Int
    let high: Double
    let low: Double
    let precipChance: Int
}

struct SharedPrecipSlot: Codable {
    let minuteOffset: Int
    let precipitation: Double
    let intensity: String
}

struct SharedActivityWindow: Codable {
    let activity: String       // "Running", "Walking", etc.
    let activityIcon: String   // SF Symbol name
    let startTime: Date
    let endTime: Date
    let score: Double
    let rating: String         // "Excellent", "Good", "Fair", "Poor"
    let ratingColor: String    // hex
    let temp: Double
    let precipChance: Int
    let isToday: Bool
}

// MARK: - App Group Store

enum WidgetDataStore {
    static let appGroupID = "group.com.weatherapp.betterWeather"
    private static let dataKey = "shared_weather_data"

    static var sharedDefaults: UserDefaults? {
        UserDefaults(suiteName: appGroupID)
    }

    /// Called by the main app after each weather fetch
    static func write(_ data: SharedWeatherData) {
        guard let defaults = sharedDefaults,
              let encoded = try? JSONEncoder().encode(data) else { return }
        defaults.set(encoded, forKey: dataKey)
    }

    /// Called by widget extensions to read current weather
    static func read() -> SharedWeatherData? {
        guard let defaults = sharedDefaults,
              let data = defaults.data(forKey: dataKey),
              let decoded = try? JSONDecoder().decode(SharedWeatherData.self, from: data) else {
            return nil
        }
        return decoded
    }
}
