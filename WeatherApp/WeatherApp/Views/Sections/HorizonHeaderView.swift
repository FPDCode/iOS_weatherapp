import SwiftUI

/// A weather horizon header inspired by Lumy — uses a Metal shader to render
/// a dynamic sky with atmospheric glow, sun/moon position, and weather-adaptive
/// colors. The weather info (temp, condition, etc.) is overlaid on top.
struct HorizonHeaderView: View {
    let cityName: String
    let temperature: Double
    let condition: String
    let high: Double
    let low: Double
    let weatherCode: Int
    let isDay: Bool
    let sunrise: String
    let sunset: String
    let sunriseDate: Date?
    let sunsetDate: Date?
    let lastUpdated: Date?


    /// Time of day as 0.0–1.0 (midnight → midnight)
    private var timeOfDay: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let seconds = now.timeIntervalSince(startOfDay)
        return seconds / 86400.0
    }

    /// Weather factor: 0.0 = clear, 1.0 = heavy storm
    private var weatherFactor: Double {
        switch weatherCode {
        case 0, 1: return 0.0       // Clear
        case 2: return 0.15          // Partly cloudy
        case 3: return 0.3           // Overcast
        case 45, 48: return 0.5      // Fog
        case 51...55: return 0.4     // Drizzle
        case 56...57: return 0.5     // Freezing drizzle
        case 61...63: return 0.5     // Rain
        case 65: return 0.65         // Heavy rain
        case 66...67: return 0.6     // Freezing rain
        case 71...77: return 0.55    // Snow
        case 80...82: return 0.55    // Showers
        case 85...86: return 0.6     // Snow showers
        case 95: return 0.8          // Thunderstorm
        case 96, 99: return 0.95     // Thunderstorm + hail
        default: return 0.1
        }
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            // Metal shader sky — edge to edge
            skyCanvas

            // Weather info overlay
            weatherOverlay
        }
        .frame(height: 340)
        .clipped()
    }

    // MARK: - Sky Shader Canvas

    private var skyCanvas: some View {
        GeometryReader { geo in
            TimelineView(.animation) { timeline in
                let time = timeline.date.timeIntervalSince1970
                Rectangle()
                    .fill(.white)
                    .colorEffect(
                        ShaderLibrary.weatherHorizon(
                            .float2(geo.size.width, geo.size.height),
                            .float(timeOfDay),
                            .float(weatherFactor),
                            .float(time.truncatingRemainder(dividingBy: 10000))
                        )
                    )
            }
        }
    }

    // MARK: - Weather Info Overlay

    private var weatherOverlay: some View {
        VStack(spacing: 4) {
            Spacer()

            Text(cityName)
                .font(.title2)
                .fontWeight(.medium)

            Text(WeatherFormatters.temperature(temperature))
                .font(.system(size: 72, weight: .thin, design: .rounded))

            Text(condition)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.7))

            HStack(spacing: 16) {
                Label("H: \(WeatherFormatters.temperature(high))", systemImage: "arrow.up")
                    .font(.subheadline)
                Label("L: \(WeatherFormatters.temperature(low))", systemImage: "arrow.down")
                    .font(.subheadline)
            }
            .foregroundStyle(.white.opacity(0.6))
            .padding(.top, 2)

            // Sunrise/Sunset
            HStack(spacing: 24) {
                Label(sunrise, systemImage: "sunrise.fill")
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.9))
                Label(sunset, systemImage: "sunset.fill")
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.9))
            }
            .padding(.top, 6)

            // Last updated
            if let lastUpdated {
                Text("Updated \(lastUpdated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.35))
                    .padding(.top, 2)
            }
        }
        .padding(.bottom, 20)
        .shadow(color: .black.opacity(0.3), radius: 10, x: 0, y: 2)
    }
}

// MARK: - Fallback for pre-iOS 17 shader support

/// Wraps the horizon header — uses shader on iOS 17+ (where colorEffect is
/// available), falls back to gradient on older OS versions.
struct AdaptiveHorizonHeader: View {
    let cityName: String
    let temperature: Double
    let condition: String
    let high: Double
    let low: Double
    let weatherCode: Int
    let isDay: Bool
    let sunrise: String
    let sunset: String
    let sunriseDate: Date?
    let sunsetDate: Date?
    let lastUpdated: Date?

    var body: some View {
        HorizonHeaderView(
            cityName: cityName,
            temperature: temperature,
            condition: condition,
            high: high,
            low: low,
            weatherCode: weatherCode,
            isDay: isDay,
            sunrise: sunrise,
            sunset: sunset,
            sunriseDate: sunriseDate,
            sunsetDate: sunsetDate,
            lastUpdated: lastUpdated
        )
    }
}
