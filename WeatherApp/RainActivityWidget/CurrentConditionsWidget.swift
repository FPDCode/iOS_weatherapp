import SwiftUI
import WidgetKit

struct CurrentConditionsWidget: Widget {
    let kind = "CurrentConditions"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherTimelineProvider()) { entry in
            CurrentConditionsView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Current Weather")
        .description("Temperature, conditions, and today's range.")
        .supportedFamilies([.systemSmall])
    }
}

struct CurrentConditionsView: View {
    let entry: WeatherEntry

    var body: some View {
        if let data = entry.data {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Image(systemName: WeatherWidgetHelpers.sfSymbol(for: data.currentWeatherCode, isDay: data.isDay))
                        .font(.title2)
                        .symbolRenderingMode(.multicolor)
                    Spacer()
                }

                Text("\(Int(round(data.currentTemp)))°")
                    .font(.system(size: 36, weight: .bold, design: .rounded))

                Text(data.currentCondition)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 4) {
                    Text("H:\(Int(round(data.todayHigh)))°")
                        .font(.caption2)
                    Text("L:\(Int(round(data.todayLow)))°")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(data.locationName)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                    .lineLimit(1)
            }
        } else {
            Text("Open app to load weather")
                .font(.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
    }
}
