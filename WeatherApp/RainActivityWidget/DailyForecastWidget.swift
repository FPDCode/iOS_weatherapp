import SwiftUI
import WidgetKit

struct DailyForecastWidget: Widget {
    let kind = "DailyForecast"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherTimelineProvider()) { entry in
            DailyForecastWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Daily Forecast")
        .description("5-day weather outlook.")
        .supportedFamilies([.systemLarge])
    }
}

struct DailyForecastWidgetView: View {
    let entry: WeatherEntry

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    var body: some View {
        if let data = entry.data {
            VStack(alignment: .leading, spacing: 8) {
                // Header with current conditions
                HStack(spacing: 12) {
                    Image(systemName: WeatherWidgetHelpers.sfSymbol(for: data.currentWeatherCode, isDay: data.isDay))
                        .font(.largeTitle)
                        .symbolRenderingMode(.multicolor)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(Int(round(data.currentTemp)))°")
                            .font(.system(size: 32, weight: .bold, design: .rounded))
                        Text(data.currentCondition)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(data.locationName)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Text("H:\(Int(round(data.todayHigh)))° L:\(Int(round(data.todayLow)))°")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                    }
                }

                Divider()

                // Daily rows
                let days = data.daily.prefix(5)
                let allHighs = days.map(\.high)
                let allLows = days.map(\.low)
                let globalHigh = allHighs.max() ?? 30
                let globalLow = allLows.min() ?? 0

                ForEach(Array(days.enumerated()), id: \.offset) { index, day in
                    HStack(spacing: 8) {
                        Text(index == 0 ? "Today" : Self.dayFormatter.string(from: day.date))
                            .font(.subheadline)
                            .frame(width: 50, alignment: .leading)

                        Image(systemName: WeatherWidgetHelpers.sfSymbol(for: day.weatherCode, isDay: true))
                            .font(.body)
                            .symbolRenderingMode(.multicolor)
                            .frame(width: 24)

                        if day.precipChance > 10 {
                            Text("\(day.precipChance)%")
                                .font(.system(size: 10))
                                .foregroundStyle(.blue)
                                .frame(width: 30)
                        } else {
                            Spacer().frame(width: 30)
                        }

                        Text("\(Int(round(day.low)))°")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .frame(width: 28, alignment: .trailing)

                        // Temperature range bar
                        GeometryReader { geo in
                            let range = max(globalHigh - globalLow, 1)
                            let lowFrac = CGFloat((day.low - globalLow) / range)
                            let highFrac = CGFloat((day.high - globalLow) / range)

                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 2)
                                    .fill(.quaternary)
                                    .frame(height: 4)

                                RoundedRectangle(cornerRadius: 2)
                                    .fill(LinearGradient(
                                        colors: [.blue, .orange],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    ))
                                    .frame(
                                        width: max((highFrac - lowFrac) * geo.size.width, 4),
                                        height: 4
                                    )
                                    .offset(x: lowFrac * geo.size.width)
                            }
                            .frame(maxHeight: .infinity, alignment: .center)
                        }
                        .frame(height: 16)

                        Text("\(Int(round(day.high)))°")
                            .font(.caption)
                            .fontWeight(.medium)
                            .frame(width: 28, alignment: .trailing)
                    }
                }
            }
        } else {
            Text("Open app to load weather")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
