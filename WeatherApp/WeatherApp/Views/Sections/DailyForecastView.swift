import SwiftUI

struct DailyForecastView: View {
    let forecasts: [DailyForecast]
    @EnvironmentObject var weatherViewModel: WeatherViewModel
    @State private var selectedDate: Date = Date()
    @State private var showDayDetail = false

    private var tempRange: (min: Double, max: Double) {
        let lows = forecasts.map(\.tempLow)
        let highs = forecasts.map(\.tempHigh)
        return (lows.min() ?? 0, highs.max() ?? 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "10-Day Forecast", icon: "calendar")

            if forecasts.isEmpty {
                Text("No daily data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(forecasts.enumerated()), id: \.element.id) { index, forecast in
                        DailyRow(
                            forecast: forecast,
                            globalMin: tempRange.min,
                            globalMax: tempRange.max,
                            isFirst: index == 0
                        )
                        .contentShape(Rectangle())
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            selectedDate = forecast.date
                            showDayDetail = true
                        }

                        if index < forecasts.count - 1 {
                            Divider()
                                .background(.white.opacity(0.1))
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showDayDetail) {
            DayDetailSheet(
                selectedDate: $selectedDate,
                forecasts: forecasts
            )
            .environmentObject(weatherViewModel)
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
                .accessibilityLabel(WeatherCodeInfo.description(for: forecast.weatherCode))

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
                    Capsule()
                        .fill(.white.opacity(0.1))
                        .frame(height: 5)

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
        // Map actual temperatures to colors based on how they feel
        let lowColor = TemperatureColor.forCelsius(forecast.tempLow)
        let highColor = TemperatureColor.forCelsius(forecast.tempHigh)
        // Add a midpoint color for the middle of the range
        let midTemp = (forecast.tempLow + forecast.tempHigh) / 2
        let midColor = TemperatureColor.forCelsius(midTemp)

        return LinearGradient(
            colors: [lowColor, midColor, highColor],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

// MARK: - Temperature-to-Color Mapping

enum TemperatureColor {
    /// Maps a Celsius temperature to a color based on how it feels.
    /// Uses the color scale from the reference image.
    static func forCelsius(_ temp: Double) -> Color {
        // Convert if user is in Fahrenheit — the API temp is in user's unit
        let celsius: Double
        if UnitSettings.shared.selectedTemperature == .fahrenheit {
            celsius = (temp - 32) * 5 / 9
        } else {
            celsius = temp
        }

        switch celsius {
        case ...(-18):  return Color(hex: "9B59B6") // Extreme Cold — purple
        case -17...(-7): return Color(hex: "1A237E") // Dangerous Cold — deep blue
        case -6...(-1):  return Color(hex: "1565C0") // Freezing — blue
        case 0...7:      return Color(hex: "2196F3") // Cold — light blue
        case 8...12:     return Color(hex: "4DD0E1") // Cool — cyan
        case 13...17:    return Color(hex: "26A69A") // Mild — teal
        case 18...23:    return Color(hex: "66BB6A") // Comfortable — green
        case 24...29:    return Color(hex: "FDD835") // Warm — yellow
        case 30...34:    return Color(hex: "EF6C00") // Hot — orange
        case 35...40:    return Color(hex: "D32F2F") // Very Hot — red
        default:         return Color(hex: "9B59B6") // Extreme Heat — purple
        }
    }
}
