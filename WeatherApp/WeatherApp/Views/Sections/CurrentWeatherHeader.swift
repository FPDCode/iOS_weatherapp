import SwiftUI

struct CurrentWeatherHeader: View {
    let cityName: String
    let temperature: Double
    let condition: String
    let high: Double
    let low: Double
    let weatherCode: Int
    let isDay: Bool
    let sunrise: String
    let sunset: String

    var body: some View {
        VStack(spacing: 4) {
            Text(cityName)
                .font(.largeTitle)
                .fontWeight(.medium)

            Text(WeatherFormatters.temperature(temperature))
                .font(.system(size: 76, weight: .thin, design: .rounded))

            Text(condition)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.secondary)

            HStack(spacing: 16) {
                Label("H: \(WeatherFormatters.temperature(high))", systemImage: "arrow.up")
                    .font(.subheadline)
                Label("L: \(WeatherFormatters.temperature(low))", systemImage: "arrow.down")
                    .font(.subheadline)
            }
            .foregroundStyle(.secondary)
            .padding(.top, 2)

            // Sunrise/Sunset
            HStack(spacing: 24) {
                Label(sunrise, systemImage: "sunrise.fill")
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.8))
                Label(sunset, systemImage: "sunset.fill")
                    .font(.caption)
                    .foregroundStyle(.orange.opacity(0.8))
            }
            .padding(.top, 8)
        }
        .padding(.top, 40)
        .padding(.bottom, 20)
    }
}
