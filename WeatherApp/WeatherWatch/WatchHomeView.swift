import SwiftUI

struct WatchHomeView: View {
    @EnvironmentObject var connectivity: WatchConnectivityService

    var body: some View {
        NavigationStack {
            if let data = connectivity.weatherData {
                ScrollView {
                    VStack(spacing: 12) {
                        // Current conditions
                        WatchCurrentView(data: data)

                        // Hourly
                        if !data.hourly.isEmpty {
                            WatchHourlyView(hourly: data.hourly)
                        }

                        // Daily mini
                        if !data.daily.isEmpty {
                            WatchDailySection(daily: data.daily)
                        }

                        // Precipitation
                        if !data.precipSlots.isEmpty {
                            WatchPrecipSection(data: data)
                        }
                    }
                    .padding(.horizontal, 4)
                }
                .navigationTitle(data.locationName)
                .navigationBarTitleDisplayMode(.inline)
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "iphone.and.arrow.forward")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)

                    Text("Open the iPhone app to sync weather data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()
            }
        }
        .onAppear {
            connectivity.requestUpdate()
        }
    }
}

// MARK: - Daily Mini Section

struct WatchDailySection: View {
    let daily: [SharedDaily]

    private static let dayFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("THIS WEEK")
                .font(.system(size: 10, weight: .semibold))
                .foregroundStyle(.secondary)

            ForEach(Array(daily.prefix(5).enumerated()), id: \.offset) { i, day in
                HStack(spacing: 6) {
                    Text(i == 0 ? "Today" : Self.dayFmt.string(from: day.date))
                        .font(.caption2)
                        .frame(width: 36, alignment: .leading)

                    Image(systemName: sfSymbol(for: day.weatherCode))
                        .font(.caption2)
                        .symbolRenderingMode(.multicolor)
                        .frame(width: 16)

                    if day.precipChance > 10 {
                        Text("\(day.precipChance)%")
                            .font(.system(size: 9))
                            .foregroundStyle(.cyan)
                            .frame(width: 24)
                    } else {
                        Spacer().frame(width: 24)
                    }

                    Text("\(Int(round(day.low)))°")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Spacer()

                    Text("\(Int(round(day.high)))°")
                        .font(.caption2)
                        .fontWeight(.medium)
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

// MARK: - Precipitation Mini Section

struct WatchPrecipSection: View {
    let data: SharedWeatherData

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 4) {
                Image(systemName: "cloud.rain.fill")
                    .font(.system(size: 9))
                    .symbolRenderingMode(.multicolor)
                Text("NEXT 2H")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            if let change = data.nextRainChange {
                Text(change)
                    .font(.caption)
                    .fontWeight(.medium)
            }

            // Mini bars
            HStack(spacing: 1) {
                ForEach(Array(data.precipSlots.enumerated()), id: \.offset) { _, slot in
                    RoundedRectangle(cornerRadius: 1)
                        .fill(slot.precipitation > 0.1 ? Color.cyan : Color.gray.opacity(0.3))
                        .frame(height: slot.precipitation > 0.1 ? 12 : 4)
                        .frame(maxWidth: .infinity)
                }
            }
            .frame(height: 12)
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 12).fill(.white.opacity(0.05)))
    }
}
