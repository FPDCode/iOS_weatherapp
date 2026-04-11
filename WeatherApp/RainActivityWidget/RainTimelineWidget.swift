import SwiftUI
import WidgetKit

struct RainTimelineWidget: Widget {
    let kind = "RainTimeline"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: WeatherTimelineProvider()) { entry in
            RainTimelineWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
                .widgetURL(URL(string: "weatherapp://now/precipitation"))
        }
        .configurationDisplayName("Rain Timeline")
        .description("Precipitation intensity for the next 2 hours.")
        .supportedFamilies([.systemMedium])
    }
}

struct RainTimelineWidgetView: View {
    let entry: WeatherEntry

    var body: some View {
        if let data = entry.data {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Image(systemName: data.isRaining ? "cloud.rain.fill" : "cloud.drizzle")
                        .font(.caption)
                        .symbolRenderingMode(.multicolor)
                    Text("PRECIPITATION")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text(data.locationName)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }

                if let changeLabel = data.nextRainChange {
                    Text(changeLabel)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                } else {
                    Text(data.precipSummary)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }

                // Precipitation bars
                GeometryReader { geo in
                    let slots = data.precipSlots
                    let barCount = max(slots.count, 1)
                    let spacing: CGFloat = 3
                    let barWidth = (geo.size.width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount)
                    let maxPrecip = max(slots.map(\.precipitation).max() ?? 1, 0.5)

                    HStack(spacing: spacing) {
                        ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                            let h = slot.precipitation < 0.1
                                ? geo.size.height * 0.08
                                : geo.size.height * CGFloat(slot.precipitation / maxPrecip)
                            RoundedRectangle(cornerRadius: 2)
                                .fill(WeatherWidgetHelpers.precipColor(slot.intensity))
                                .frame(width: barWidth, height: max(h, 2))
                                .frame(maxHeight: .infinity, alignment: .bottom)
                        }
                    }
                }
                .frame(height: 40)

                HStack {
                    Text("Now")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("+1h")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("+2h")
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        } else {
            Text("Open app to load weather")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
