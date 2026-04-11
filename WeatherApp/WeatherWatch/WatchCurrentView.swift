import SwiftUI

struct WatchCurrentView: View {
    let data: SharedWeatherData

    private var sfSymbol: String {
        switch data.currentWeatherCode {
        case 0, 1: return data.isDay ? "sun.max.fill" : "moon.stars.fill"
        case 2: return data.isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3: return "cloud.fill"
        case 45, 48: return "cloud.fog.fill"
        case 51...55: return "cloud.drizzle.fill"
        case 61...65: return "cloud.rain.fill"
        case 71...77: return "cloud.snow.fill"
        case 80...82: return "cloud.rain.fill"
        case 95, 96, 99: return "cloud.bolt.rain.fill"
        default: return "cloud.fill"
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            // Weather icon
            Image(systemName: sfSymbol)
                .font(.system(size: 36))
                .symbolRenderingMode(.multicolor)

            // Temperature
            Text("\(Int(round(data.currentTemp)))°")
                .font(.system(size: 42, weight: .thin, design: .rounded))

            // Condition
            Text(data.currentCondition)
                .font(.caption)
                .foregroundStyle(.secondary)

            // Feels like (if different)
            if abs(data.currentFeelsLike - data.currentTemp) >= 1.5 {
                Text("Feels \(Int(round(data.currentFeelsLike)))°")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // H/L
            HStack(spacing: 8) {
                HStack(spacing: 2) {
                    Image(systemName: "arrow.up").font(.system(size: 8))
                    Text("\(Int(round(data.todayHigh)))°").font(.caption2)
                }
                HStack(spacing: 2) {
                    Image(systemName: "arrow.down").font(.system(size: 8))
                    Text("\(Int(round(data.todayLow)))°").font(.caption2)
                }
            }
            .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
}
