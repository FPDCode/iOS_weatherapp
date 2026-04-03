import SwiftUI

struct DailyForecastView: View {
    let forecasts: [DailyForecast]

    private var tempRange: (min: Double, max: Double) {
        let lows = forecasts.map(\.tempLow)
        let highs = forecasts.map(\.tempHigh)
        return (lows.min() ?? 0, highs.max() ?? 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "10-Day Forecast", icon: "calendar")

            VStack(spacing: 0) {
                ForEach(Array(forecasts.enumerated()), id: \.element.id) { index, forecast in
                    DailyRow(
                        forecast: forecast,
                        globalMin: tempRange.min,
                        globalMax: tempRange.max,
                        isFirst: index == 0
                    )

                    if index < forecasts.count - 1 {
                        Divider()
                            .background(.white.opacity(0.1))
                    }
                }
            }
        }
    }
}

struct DailyRow: View {
    let forecast: DailyForecast
    let globalMin: Double
    let globalMax: Double
    let isFirst: Bool

    private var totalRange: Double {
        max(globalMax - globalMin, 1)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Day name
            Text(isFirst ? "Today" : WeatherFormatters.dayOfWeek(forecast.date))
                .font(.subheadline)
                .fontWeight(isFirst ? .semibold : .regular)
                .frame(width: 52, alignment: .leading)

            // Weather icon
            Image(systemName: WeatherCodeInfo.sfSymbol(for: forecast.weatherCode))
                .symbolRenderingMode(.multicolor)
                .font(.body)
                .frame(width: 32)

            // Precip chance
            HStack(spacing: 2) {
                if forecast.precipChance > 0 {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.cyan)
                    Text("\(forecast.precipChance)%")
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                }
            }
            .frame(width: 42, alignment: .leading)

            // Low temp
            Text(WeatherFormatters.temperature(forecast.tempLow))
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 34, alignment: .trailing)

            // Temperature bar
            GeometryReader { geo in
                let width = geo.size.width
                let lowOffset = CGFloat((forecast.tempLow - globalMin) / totalRange) * width
                let highOffset = CGFloat((forecast.tempHigh - globalMin) / totalRange) * width

                ZStack(alignment: .leading) {
                    // Track
                    Capsule()
                        .fill(.white.opacity(0.1))
                        .frame(height: 5)

                    // Range bar
                    Capsule()
                        .fill(tempBarGradient)
                        .frame(width: max(highOffset - lowOffset, 6), height: 5)
                        .offset(x: lowOffset)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(height: 20)
            .padding(.horizontal, 8)

            // High temp
            Text(WeatherFormatters.temperature(forecast.tempHigh))
                .font(.subheadline)
                .fontWeight(.medium)
                .frame(width: 34, alignment: .trailing)
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 4)
    }

    private var tempBarGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "64B5F6"), Color(hex: "FFB74D"), Color(hex: "EF5350")],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}
