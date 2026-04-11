import SwiftUI

struct WatchHourlyView: View {
    let hourly: [SharedHourly]

    private static let hourFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ha"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("HOURLY")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(Array(hourly.prefix(12).enumerated()), id: \.offset) { i, hour in
                        VStack(spacing: 4) {
                            Text(i == 0 ? "Now" : Self.hourFmt.string(from: hour.time).lowercased())
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)

                            Image(systemName: sfSymbol(for: hour.weatherCode))
                                .font(.caption)
                                .symbolRenderingMode(.multicolor)

                            Text("\(Int(round(hour.temp)))°")
                                .font(.caption2)
                                .fontWeight(.semibold)

                            if hour.precipChance > 10 {
                                Text("\(hour.precipChance)%")
                                    .font(.system(size: 8))
                                    .foregroundStyle(.cyan)
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.05)))
    }

    private func sfSymbol(for code: Int) -> String {
        switch code {
        case 0, 1: return "sun.max.fill"
        case 2: return "cloud.sun.fill"
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
}
