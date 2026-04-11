import SwiftUI

// MARK: - Precipitation Detail Sheet

struct PrecipDetailSheet: View {
    let timeline: PrecipitationTimeline
    let hourlyForecasts: [HourlyForecast]
    @Environment(\.dismiss) private var dismiss

    private var next24hPrecip: Double {
        hourlyForecasts.prefix(24).reduce(0) { $0 + $1.precipAmount }
    }

    private var rainHours: Int {
        hourlyForecasts.prefix(24).filter { $0.precipChance >= 50 }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current status
                    VStack(spacing: 12) {
                        Image(systemName: timeline.isRaining ? "cloud.rain.fill" : "cloud.fill")
                            .font(.largeTitle)
                            .symbolRenderingMode(.multicolor)

                        Text(timeline.summary)
                            .font(.title3)
                            .fontWeight(.semibold)
                            .multilineTextAlignment(.center)

                        if let change = timeline.nextChangeLabel {
                            Text(change)
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }

                        HStack(spacing: 30) {
                            VStack(spacing: 2) {
                                Text(WeatherFormatters.precipitation(next24hPrecip))
                                    .font(.title3).fontWeight(.bold)
                                Text("Total 24h").font(.caption2).foregroundStyle(.secondary)
                            }
                            VStack(spacing: 2) {
                                Text("\(rainHours)h").font(.title3).fontWeight(.bold)
                                Text("Rain hours").font(.caption2).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // 24h precipitation chart
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("24-HOUR PRECIPITATION", icon: "chart.bar.fill")
                        PrecipHourlyChart(forecasts: Array(hourlyForecasts.prefix(24)))
                            .frame(height: 100)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // Intensity guide
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("INTENSITY GUIDE", icon: "info.circle.fill")
                        intensityRow("None", "< 0.1 mm/15min", "4A5568")
                        intensityRow("Light", "0.1–0.5 mm/15min", "63B3ED")
                        intensityRow("Moderate", "0.5–2.0 mm/15min", "4299E1")
                        intensityRow("Heavy", "> 2.0 mm/15min", "2B6CB0")
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))
                }
                .padding(16)
            }
            .background(Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("Precipitation")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        }
    }

    private func intensityRow(_ name: String, _ range: String, _ color: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Color(hex: color)).frame(width: 8, height: 8)
            Text(name).font(.caption).fontWeight(.medium).frame(width: 65, alignment: .leading)
            Text(range).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct PrecipHourlyChart: View {
    let forecasts: [HourlyForecast]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let count = max(forecasts.count, 1)
            let barWidth = w / CGFloat(count) - 2
            let maxPrecip = max(forecasts.map(\.precipAmount).max() ?? 1, 0.5)

            ZStack(alignment: .bottomLeading) {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(forecasts.enumerated()), id: \.offset) { _, f in
                        let barH = f.precipAmount > 0.01 ? max(h * CGFloat(f.precipAmount / maxPrecip), 3) : 2
                        RoundedRectangle(cornerRadius: 2)
                            .fill(f.precipAmount > 0.01 ? Color(hex: "4299E1") : Color.gray.opacity(0.2))
                            .frame(width: barWidth, height: barH)
                    }
                }

                HStack {
                    Text("Now").font(.system(size: 8)).foregroundStyle(.tertiary)
                    Spacer()
                    Text("+24h").font(.system(size: 8)).foregroundStyle(.tertiary)
                }
                .offset(y: 14)
            }
        }
    }
}

// MARK: - Cloud Cover Detail Sheet

struct CloudCoverDetailSheet: View {
    let info: CloudCoverInfo
    let stormRisk: StormRiskInfo?
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current overview
                    VStack(spacing: 12) {
                        ZStack {
                            Circle().fill(.white.opacity(0.08)).frame(width: 100, height: 100)
                            VStack(spacing: 4) {
                                Image(systemName: cloudIcon).font(.title).symbolRenderingMode(.hierarchical).foregroundStyle(.white)
                                Text("\(info.total)%").font(.title3).fontWeight(.bold)
                            }
                        }

                        Text(cloudDescription).font(.subheadline).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // Layer breakdown
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("CLOUD LAYERS", icon: "cloud.fill")
                        cloudLayerDetail("High Clouds", info.high, "90CAF9", "Cirrus, cirrostratus — thin, wispy clouds at 6–12 km altitude")
                        Divider().background(.white.opacity(0.1))
                        cloudLayerDetail("Mid Clouds", info.mid, "78909C", "Altocumulus, altostratus — mid-level clouds at 2–6 km altitude")
                        Divider().background(.white.opacity(0.1))
                        cloudLayerDetail("Low Clouds", info.low, "546E7A", "Stratus, stratocumulus — thick clouds below 2 km altitude")
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // Storm risk
                    if let storm = stormRisk {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("STORM RISK", icon: "bolt.fill")
                            HStack(spacing: 12) {
                                Image(systemName: storm.level.icon).font(.title2).symbolRenderingMode(.multicolor)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(storm.level.rawValue).font(.subheadline).fontWeight(.semibold).foregroundStyle(Color(hex: storm.level.color))
                                    Text("CAPE: \(Int(storm.cape)) J/kg").font(.caption).foregroundStyle(.secondary)
                                }
                            }
                            Text(stormExplanation).font(.caption).foregroundStyle(.secondary)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))
                    }
                }
                .padding(16)
            }
            .background(Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("Cloud Cover")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        }
    }

    private var cloudIcon: String {
        switch info.total {
        case 0..<20: return "sun.max.fill"
        case 20..<50: return "cloud.sun.fill"
        case 50..<80: return "cloud.fill"
        default: return "smoke.fill"
        }
    }

    private var cloudDescription: String {
        switch info.total {
        case 0..<10: return "Clear skies — virtually no cloud cover"
        case 10..<30: return "Mostly clear with some scattered clouds"
        case 30..<60: return "Partly cloudy — a mix of sun and clouds"
        case 60..<85: return "Mostly cloudy — limited sunshine"
        default: return "Overcast — full cloud cover"
        }
    }

    private var stormExplanation: String {
        guard let storm = stormRisk else { return "" }
        switch storm.level {
        case .none: return "No thunderstorm risk at this time."
        case .marginal: return "Slight instability — isolated storms possible but unlikely."
        case .slight: return "Some atmospheric instability — scattered storms possible."
        case .moderate: return "Significant instability — organized storms likely with gusty winds."
        case .high: return "Severe storm potential — large hail, damaging winds, and heavy rain possible."
        }
    }

    private func cloudLayerDetail(_ name: String, _ value: Int, _ color: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text("\(value)%").font(.title3).fontWeight(.bold).foregroundStyle(Color(hex: color)).frame(width: 50)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline).fontWeight(.medium)
                Text(desc).font(.caption2).foregroundStyle(.tertiary)
            }
        }
    }
}

// MARK: - Comfort Detail Sheet

struct ComfortDetailSheet: View {
    let comfort: ComfortInfo
    let temp: Double
    let feelsLike: Double?
    let humidity: Int
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current level
                    VStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color(hex: comfort.level.color).opacity(0.15)).frame(width: 100, height: 100)
                            VStack(spacing: 4) {
                                Image(systemName: comfort.level.icon).font(.title).symbolRenderingMode(.hierarchical).foregroundStyle(Color(hex: comfort.level.color))
                                Text(comfort.level.rawValue).font(.caption).fontWeight(.bold).foregroundStyle(Color(hex: comfort.level.color))
                            }
                        }

                        HStack(spacing: 24) {
                            VStack(spacing: 2) {
                                Text(WeatherFormatters.temperature(comfort.dewPoint)).font(.title3).fontWeight(.bold)
                                Text("Dew Point").font(.caption2).foregroundStyle(.secondary)
                            }
                            VStack(spacing: 2) {
                                Text("\(comfort.humidity)%").font(.title3).fontWeight(.bold)
                                Text("Humidity").font(.caption2).foregroundStyle(.secondary)
                            }
                            if let feels = feelsLike {
                                VStack(spacing: 2) {
                                    Text(WeatherFormatters.temperature(feels)).font(.title3).fontWeight(.bold)
                                    Text("Feels Like").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // What it means
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("WHAT THIS MEANS", icon: "info.circle.fill")
                        Text(comfortExplanation).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // Comfort scale
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("COMFORT SCALE", icon: "gauge.medium")
                        ForEach(allLevels, id: \.self) { level in
                            HStack(spacing: 8) {
                                Circle().fill(Color(hex: level.color)).frame(width: 8, height: 8)
                                Text(level.rawValue).font(.caption).fontWeight(level == comfort.level ? .bold : .regular)
                                    .frame(width: 90, alignment: .leading)
                                Text(descriptionFor(level)).font(.caption2).foregroundStyle(.secondary)
                                Spacer()
                                if level == comfort.level {
                                    Image(systemName: "arrow.left").font(.caption2).foregroundStyle(Color(hex: level.color))
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))
                }
                .padding(16)
            }
            .background(Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("Comfort Level")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        }
    }

    private let allLevels: [ComfortLevel] = [.dry, .comfortable, .pleasant, .sticky, .humid, .muggy, .oppressive]

    private var comfortExplanation: String {
        switch comfort.level {
        case .dry: return "The air is very dry. This can cause skin irritation, dry eyes, and dehydration. Use moisturizer and drink extra water."
        case .comfortable: return "Ideal conditions for most activities. The air feels fresh and pleasant without any stickiness."
        case .pleasant: return "Slightly more moisture in the air but still very comfortable. Great for outdoor activities."
        case .sticky: return "You may notice some stickiness on your skin. Light, breathable clothing is recommended."
        case .humid: return "Noticeably humid conditions. Sweat evaporates slower, making it feel warmer. Take breaks in shade."
        case .muggy: return "Oppressive humidity that makes physical activity uncomfortable. Limit strenuous exercise and stay hydrated."
        case .oppressive: return "Dangerously humid. Heat exhaustion risk is high. Stay in air conditioning when possible."
        }
    }

    private func descriptionFor(_ level: ComfortLevel) -> String {
        switch level {
        case .dry: return "Dew point < 40°F"
        case .comfortable: return "40–50°F"
        case .pleasant: return "50–55°F"
        case .sticky: return "55–60°F"
        case .humid: return "60–65°F"
        case .muggy: return "65–70°F"
        case .oppressive: return "> 70°F"
        }
    }
}

// MARK: - Gardening Detail Sheet

struct GardeningDetailSheet: View {
    let info: GardeningInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Soil conditions
                    VStack(spacing: 16) {
                        HStack(spacing: 30) {
                            VStack(spacing: 4) {
                                Image(systemName: "thermometer.medium").font(.title2).foregroundStyle(.orange)
                                Text(WeatherFormatters.temperature(info.soilTemp)).font(.title3).fontWeight(.bold)
                                Text("Soil Temp").font(.caption2).foregroundStyle(.secondary)
                            }
                            VStack(spacing: 4) {
                                Image(systemName: "drop.fill").font(.title2).foregroundStyle(.blue)
                                Text("\(Int(info.soilMoisture))%").font(.title3).fontWeight(.bold)
                                Text("Moisture").font(.caption2).foregroundStyle(.secondary)
                            }
                        }

                        if info.frostRisk {
                            HStack(spacing: 8) {
                                Image(systemName: "exclamationmark.triangle.fill").foregroundStyle(.blue)
                                Text("Frost risk tonight — protect sensitive plants")
                                    .font(.subheadline).foregroundStyle(.blue)
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 10).fill(.blue.opacity(0.1)))
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // Advice
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("WATERING", icon: "drop.fill")
                        Text(info.wateringAdvice).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("PLANTING", icon: "leaf.fill")
                        Text(info.plantingAdvice).font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // Soil temp guide
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("SOIL TEMPERATURE GUIDE", icon: "thermometer.medium")
                        soilRow("< 5°C", "Too cold for most planting")
                        soilRow("5–10°C", "Cool-season crops (peas, lettuce, spinach)")
                        soilRow("10–15°C", "Root vegetables (carrots, beets, potatoes)")
                        soilRow("15–20°C", "Most vegetables and flowers")
                        soilRow("> 20°C", "Warm-season crops (tomatoes, peppers, squash)")
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))
                }
                .padding(16)
            }
            .background(Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("Garden & Soil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        }
    }

    private func soilRow(_ range: String, _ desc: String) -> some View {
        HStack(spacing: 8) {
            Text(range).font(.caption).fontWeight(.medium).frame(width: 60, alignment: .leading)
            Text(desc).font(.caption2).foregroundStyle(.secondary)
        }
    }
}
