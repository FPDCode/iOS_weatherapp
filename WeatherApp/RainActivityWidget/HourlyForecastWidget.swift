import SwiftUI
import WidgetKit

struct HourlyForecastWidget: Widget {
    let kind = "HourlyForecast"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherTimelineProvider()) { entry in
            HourlyForecastWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "weatherapp://now/hourly"))
        }
        .configurationDisplayName("Hourly Forecast")
        .description("Next 6 hours at a glance.")
        .supportedFamilies([.systemMedium])
    }
}

struct HourlyForecastWidgetView: View {
    let entry: WeatherEntry

    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ha"
        return f
    }()

    var body: some View {
        if let data = entry.data {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: "clock")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Text("HOURLY FORECAST")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(data.locationName)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                HStack(spacing: 0) {
                    ForEach(Array(data.hourly.prefix(6).enumerated()), id: \.offset) { index, hour in
                        VStack(spacing: 4) {
                            Text(index == 0 ? "Now" : Self.hourFormatter.string(from: hour.time).lowercased())
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)

                            Image(systemName: WeatherWidgetHelpers.sfSymbol(for: hour.weatherCode, isDay: true))
                                .font(.body)
                                .symbolRenderingMode(.multicolor)

                            Text("\(Int(round(hour.temp)))°")
                                .font(.subheadline)
                                .fontWeight(.semibold)

                            if hour.precipChance > 10 {
                                Text("\(hour.precipChance)%")
                                    .font(.system(size: 9))
                                    .foregroundStyle(.blue)
                            }
                        }
                        .frame(maxWidth: .infinity)
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
