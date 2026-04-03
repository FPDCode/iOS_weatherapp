import SwiftUI

// MARK: - Metric Picker

enum HourlyMetric: String, CaseIterable {
    case temperature = "Temp"
    case precipitation = "Precip"
    case wind = "Wind"
    case uv = "UV"
    case pressure = "Pressure"
    case humidity = "Humidity"
    case visibility = "Visibility"

    var icon: String {
        switch self {
        case .temperature: return "thermometer"
        case .precipitation: return "cloud.rain"
        case .wind: return "wind"
        case .uv: return "sun.max.fill"
        case .pressure: return "gauge.medium"
        case .humidity: return "humidity"
        case .visibility: return "eye"
        }
    }
}

struct HourlyForecastView: View {
    let forecasts: [HourlyForecast]
    @State private var selectedMetric: HourlyMetric = .temperature

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "48-Hour Forecast", icon: "calendar.badge.clock")

            if forecasts.isEmpty {
                Text("No hourly data available")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 20)
            } else {
                // Metric picker
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(HourlyMetric.allCases, id: \.self) { metric in
                            MetricPill(
                                metric: metric,
                                isSelected: selectedMetric == metric
                            )
                            .onTapGesture {
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedMetric = metric
                                }
                            }
                        }
                    }
                }

                // Hourly scroll
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 0) {
                        ForEach(Array(forecasts.enumerated()), id: \.element.id) { index, forecast in
                            HourlyCell(
                                forecast: forecast,
                                metric: selectedMetric,
                                showDayDivider: shouldShowDayDivider(at: index)
                            )
                        }
                    }
                    .padding(.horizontal, 4)
                }
            }
        }
    }

    private func shouldShowDayDivider(at index: Int) -> Bool {
        guard index > 0 else { return false }
        let current = forecasts[index].time
        let previous = forecasts[index - 1].time
        return !Calendar.current.isDate(current, inSameDayAs: previous)
    }
}

struct MetricPill: View {
    let metric: HourlyMetric
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: metric.icon)
                .font(.caption2)
            Text(metric.rawValue)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isSelected ? .white.opacity(0.25) : .white.opacity(0.08))
        )
        .overlay(
            Capsule()
                .stroke(.white.opacity(isSelected ? 0.4 : 0.1), lineWidth: 1)
        )
    }
}

struct HourlyCell: View {
    let forecast: HourlyForecast
    let metric: HourlyMetric
    let showDayDivider: Bool

    var body: some View {
        HStack(spacing: 0) {
            if showDayDivider {
                DayDivider(date: forecast.time)
            }

            VStack(spacing: 6) {
                // Time
                Text(WeatherFormatters.hourTime(forecast.time))
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                // Weather icon
                Image(systemName: WeatherCodeInfo.sfSymbol(for: forecast.weatherCode))
                    .font(.body)
                    .symbolRenderingMode(.multicolor)
                    .frame(height: 24)
                    .accessibilityLabel(WeatherCodeInfo.description(for: forecast.weatherCode))

                // Metric-specific content
                metricContent
            }
            .frame(width: 64)
            .padding(.vertical, 10)
        }
    }

    @ViewBuilder
    private var metricContent: some View {
        switch metric {
        case .temperature:
            VStack(spacing: 2) {
                Text(WeatherFormatters.temperature(forecast.temperature))
                    .font(.callout)
                    .fontWeight(.semibold)
                HStack(spacing: 2) {
                    Text("FL")
                        .font(.system(size: 8))
                        .foregroundStyle(.secondary)
                    Text(WeatherFormatters.temperature(forecast.feelsLike))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

        case .precipitation:
            VStack(spacing: 2) {
                Text(WeatherFormatters.percent(forecast.precipChance))
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(forecast.precipChance > 50 ? .blue : .primary)
                Text(WeatherFormatters.precipitation(forecast.precipAmount))
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }

        case .wind:
            VStack(spacing: 2) {
                Text(WeatherFormatters.windSpeed(forecast.windSpeed))
                    .font(.caption)
                    .fontWeight(.semibold)
                Image(systemName: "wind")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

        case .uv:
            VStack(spacing: 2) {
                Text(String(format: "%.0f", forecast.uvIndex))
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(forecast.uvIndex >= 6 ? .orange : forecast.uvIndex >= 3 ? .yellow : .primary)
                Image(systemName: "sun.max.fill")
                    .font(.caption2)
                    .symbolRenderingMode(.multicolor)
            }

        case .pressure:
            Text(WeatherFormatters.pressure(forecast.pressure))
                .font(.caption)
                .fontWeight(.semibold)

        case .humidity:
            VStack(spacing: 2) {
                Text(WeatherFormatters.humidity(forecast.humidity))
                    .font(.callout)
                    .fontWeight(.semibold)
                    .foregroundStyle(forecast.humidity > 70 ? .cyan : .primary)
                Image(systemName: "humidity")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

        case .visibility:
            Text(WeatherFormatters.visibility(forecast.visibility))
                .font(.caption)
                .fontWeight(.semibold)
        }
    }
}

struct DayDivider: View {
    let date: Date

    var body: some View {
        VStack {
            Text(WeatherFormatters.dayOfWeek(date).uppercased())
                .font(.system(size: 9, weight: .bold))
                .foregroundStyle(.secondary)
            Rectangle()
                .fill(.white.opacity(0.2))
                .frame(width: 1, height: 50)
        }
        .frame(width: 30)
    }
}
