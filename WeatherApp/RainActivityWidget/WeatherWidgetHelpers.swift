import SwiftUI
import WidgetKit

// MARK: - Shared Timeline Provider (for static widgets)

struct WeatherEntry: TimelineEntry {
    let date: Date
    let data: SharedWeatherData?
}

struct WeatherTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> WeatherEntry {
        WeatherEntry(date: .now, data: nil)
    }

    func getSnapshot(in context: Context, completion: @escaping (WeatherEntry) -> Void) {
        let data = WidgetDataStore.read()
        completion(WeatherEntry(date: .now, data: data))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<WeatherEntry>) -> Void) {
        let data = WidgetDataStore.read()
        let entry = WeatherEntry(date: .now, data: data)
        // Refresh every 30 minutes
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        completion(Timeline(entries: [entry], policy: .after(nextUpdate)))
    }
}

// MARK: - Weather Helpers

enum WeatherWidgetHelpers {
    /// Map Open-Meteo weather codes to SF Symbols
    static func sfSymbol(for code: Int, isDay: Bool) -> String {
        switch code {
        case 0:
            return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1, 2:
            return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55:
            return "cloud.drizzle.fill"
        case 56, 57:
            return "cloud.sleet.fill"
        case 61, 63:
            return "cloud.rain.fill"
        case 65:
            return "cloud.heavyrain.fill"
        case 66, 67:
            return "cloud.sleet.fill"
        case 71, 73, 75, 77:
            return "cloud.snow.fill"
        case 80, 81, 82:
            return "cloud.rain.fill"
        case 85, 86:
            return "cloud.snow.fill"
        case 95, 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return "cloud.fill"
        }
    }

    /// Map precipitation intensity string to a color
    static func precipColor(_ intensity: String) -> Color {
        switch intensity {
        case "Light": return Color(red: 0.39, green: 0.70, blue: 0.93)
        case "Moderate": return Color(red: 0.26, green: 0.60, blue: 0.88)
        case "Heavy": return Color(red: 0.17, green: 0.42, blue: 0.69)
        default: return Color.gray.opacity(0.3)
        }
    }
}
