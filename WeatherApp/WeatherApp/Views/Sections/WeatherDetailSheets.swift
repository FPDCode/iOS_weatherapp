import SwiftUI

// MARK: - AQI Detail Sheet

struct AQIDetailSheet: View {
    let airQuality: AirQualityInfo
    let hourlyForecasts: [HourlyForecast]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current AQI
                    VStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(Color(hex: airQuality.level.color).opacity(0.15))
                                .frame(width: 100, height: 100)
                            VStack(spacing: 4) {
                                Text("\(airQuality.aqi)")
                                    .font(.system(size: 36, weight: .bold, design: .rounded))
                                    .foregroundStyle(Color(hex: airQuality.level.color))
                                Text(airQuality.level.rawValue)
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundStyle(Color(hex: airQuality.level.color))
                            }
                        }

                        AQIScaleBar(currentAQI: airQuality.aqi)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // Particulates
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("PARTICULATE MATTER", icon: "aqi.medium")

                        ParticulateRow(name: "PM2.5", value: airQuality.pm25, unit: "µg/m³", description: "Fine particles — penetrate deep into lungs", threshold: 25)
                        Divider().background(.white.opacity(0.1))
                        ParticulateRow(name: "PM10", value: airQuality.pm10, unit: "µg/m³", description: "Coarse particles — dust, pollen, mold", threshold: 50)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // Health recommendations
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("HEALTH ADVICE", icon: "heart.text.square.fill")

                        ForEach(Array(aqiTips.enumerated()), id: \.offset) { _, tip in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: tip.0)
                                    .font(.body)
                                    .foregroundStyle(Color(hex: airQuality.level.color))
                                    .frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tip.1).font(.subheadline).fontWeight(.medium)
                                    Text(tip.2).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // AQI Scale Legend
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("AQI SCALE", icon: "info.circle.fill")
                        aqiLegendRow("Good", "0–50", "34D399")
                        aqiLegendRow("Fair", "51–100", "FBBF24")
                        aqiLegendRow("Moderate", "101–150", "FB923C")
                        aqiLegendRow("Poor", "151–200", "F87171")
                        aqiLegendRow("Very Poor", "201–300", "A855F7")
                        aqiLegendRow("Hazardous", "300+", "7C3AED")
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))
                }
                .padding(.horizontal, 4)
            }
            .background(Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("Air Quality")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        }
    }

    private var aqiTips: [(String, String, String)] {
        switch airQuality.level {
        case .good: return [("checkmark.circle.fill", "Air is clean", "No precautions needed — enjoy outdoor activities.")]
        case .fair: return [("figure.walk", "Acceptable quality", "Unusually sensitive people should reduce prolonged outdoor exertion.")]
        case .moderate: return [
            ("exclamationmark.triangle.fill", "Sensitive groups at risk", "People with respiratory conditions should limit outdoor exposure."),
            ("window.horizontal.closed", "Ventilate wisely", "Open windows during low-traffic hours (early morning)."),
        ]
        case .poor: return [
            ("lungs.fill", "Reduce outdoor activity", "Everyone should reduce prolonged outdoor exertion."),
            ("facemask.fill", "Wear a mask", "Consider an N95 mask if you must be outdoors."),
        ]
        case .veryPoor, .hazardous: return [
            ("exclamationmark.octagon.fill", "Stay indoors", "Avoid all outdoor physical activity."),
            ("facemask.fill", "Mask required outdoors", "Use N95/P2 mask for any outdoor exposure."),
            ("air.purifier.fill", "Run air purifier", "Keep indoor air clean with HEPA filtration."),
        ]
        }
    }

    private func aqiLegendRow(_ name: String, _ range: String, _ color: String) -> some View {
        HStack(spacing: 8) {
            Circle().fill(Color(hex: color)).frame(width: 8, height: 8)
            Text(name).font(.caption).fontWeight(.medium).frame(width: 80, alignment: .leading)
            Text(range).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct AQIScaleBar: View {
    let currentAQI: Int
    private let maxAQI: Double = 300

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let progress = min(Double(currentAQI) / maxAQI, 1.0)
                ZStack(alignment: .leading) {
                    LinearGradient(colors: [
                        Color(hex: "34D399"), Color(hex: "FBBF24"), Color(hex: "FB923C"),
                        Color(hex: "F87171"), Color(hex: "A855F7"), Color(hex: "7C3AED")
                    ], startPoint: .leading, endPoint: .trailing)
                    .frame(height: 6)
                    .clipShape(Capsule())

                    Circle().fill(.white).frame(width: 12, height: 12)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .offset(x: CGFloat(progress) * geo.size.width - 6)
                }
            }
            .frame(height: 12)
            HStack { Text("0").font(.system(size: 8)).foregroundStyle(.tertiary); Spacer(); Text("300+").font(.system(size: 8)).foregroundStyle(.tertiary) }
        }
    }
}

private struct ParticulateRow: View {
    let name: String; let value: Double; let unit: String; let description: String; let threshold: Double
    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(name).font(.subheadline).fontWeight(.semibold)
                    Text(String(format: "%.1f", value) + " " + unit).font(.subheadline).foregroundStyle(value > threshold ? Color(hex: "F87171") : .secondary)
                }
                Text(description).font(.caption2).foregroundStyle(.tertiary)
            }
            Spacer()
            // Mini bar
            GeometryReader { geo in
                let pct = min(value / (threshold * 4), 1.0)
                ZStack(alignment: .leading) {
                    Capsule().fill(.white.opacity(0.08)).frame(height: 4)
                    Capsule().fill(value > threshold ? Color(hex: "F87171") : Color(hex: "34D399")).frame(width: CGFloat(pct) * geo.size.width, height: 4)
                }
                .frame(maxHeight: .infinity, alignment: .center)
            }
            .frame(width: 60, height: 16)
        }
    }
}

// MARK: - UV Detail Sheet

struct UVDetailSheet: View {
    let currentUV: Double
    let hourlyForecasts: [HourlyForecast]
    @Environment(\.dismiss) private var dismiss

    private var uvLevel: String {
        switch currentUV {
        case ..<3: return "Low"
        case 3..<6: return "Moderate"
        case 6..<8: return "High"
        case 8..<11: return "Very High"
        default: return "Extreme"
        }
    }

    private var uvColor: String {
        switch currentUV {
        case ..<3: return "34D399"
        case 3..<6: return "FBBF24"
        case 6..<8: return "FB923C"
        case 8..<11: return "F87171"
        default: return "A855F7"
        }
    }

    private var peakUV: (time: Date, value: Double)? {
        let today = hourlyForecasts.prefix(24)
        guard let max = today.max(by: { $0.uvIndex < $1.uvIndex }) else { return nil }
        return (max.time, max.uvIndex)
    }

    private var highUVHours: Int {
        hourlyForecasts.prefix(24).filter { $0.uvIndex >= 6 }.count
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current UV
                    VStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color(hex: uvColor).opacity(0.15)).frame(width: 100, height: 100)
                            VStack(spacing: 4) {
                                Text("\(Int(currentUV))").font(.system(size: 36, weight: .bold, design: .rounded)).foregroundStyle(Color(hex: uvColor))
                                Text(uvLevel).font(.caption).fontWeight(.semibold).foregroundStyle(Color(hex: uvColor))
                            }
                        }

                        // Peak info
                        if let peak = peakUV {
                            HStack(spacing: 20) {
                                VStack(spacing: 2) {
                                    Text("Peak").font(.caption2).foregroundStyle(.secondary)
                                    Text("\(Int(peak.value))").font(.title3).fontWeight(.bold)
                                    Text(WeatherFormatters.shortTime(peak.time)).font(.caption2).foregroundStyle(.secondary)
                                }
                                VStack(spacing: 2) {
                                    Text("High UV Hours").font(.caption2).foregroundStyle(.secondary)
                                    Text("\(highUVHours)h").font(.title3).fontWeight(.bold)
                                    Text("UV ≥ 6").font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // Hourly UV chart (interactive)
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("24-HOUR UV INDEX", icon: "chart.xyaxis.line")
                        InteractiveLineChart(
                            dataPoints: hourlyForecasts.prefix(24).map {
                                InteractiveLineChart.ChartDataPoint(time: $0.time, value: $0.uvIndex)
                            },
                            lineColor: Color(hex: uvColor),
                            fillColor: Color(hex: uvColor),
                            unit: "UV",
                            dangerThreshold: 6,
                            dangerColor: Color(hex: "F87171")
                        )
                        .frame(height: 120)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // Protection tips
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("PROTECTION", icon: "sun.max.trianglebadge.exclamationmark")
                        ForEach(Array(uvTips.enumerated()), id: \.offset) { _, tip in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: tip.0).font(.body).foregroundStyle(Color(hex: uvColor)).frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(tip.1).font(.subheadline).fontWeight(.medium)
                                    Text(tip.2).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))
                }
                .padding(.horizontal, 4)
            }
            .background(Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("UV Index")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        }
    }

    private var uvTips: [(String, String, String)] {
        switch currentUV {
        case ..<3: return [("checkmark.circle.fill", "Low risk", "No protection needed for most people.")]
        case 3..<6: return [
            ("eyeglasses", "Wear sunglasses", "Protect your eyes during midday hours."),
            ("tube.fill", "Apply SPF 30+", "Reapply every 2 hours if outdoors."),
        ]
        case 6..<8: return [
            ("tube.fill", "SPF 50+ essential", "Apply generously 15 minutes before going out."),
            ("tshirt.fill", "Cover up", "Wear protective clothing, hat, and sunglasses."),
            ("clock.fill", "Avoid midday sun", "Stay in shade between 10 AM – 4 PM."),
        ]
        default: return [
            ("exclamationmark.triangle.fill", "Minimize sun exposure", "Avoid being outside during peak hours."),
            ("tube.fill", "SPF 50+ mandatory", "Reapply every 90 minutes."),
            ("tshirt.fill", "Full coverage", "Long sleeves, wide-brim hat, UV-blocking sunglasses."),
            ("house.fill", "Seek shade", "Stay indoors when possible between 10 AM – 4 PM."),
        ]
        }
    }
}

private struct UVHourlyChart: View {
    let forecasts: [HourlyForecast]
    private static let hourFmt: DateFormatter = { let f = DateFormatter(); f.dateFormat = "ha"; return f }()

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let maxUV = max(forecasts.map(\.uvIndex).max() ?? 1, 11)
            let count = max(forecasts.count - 1, 1)

            ZStack(alignment: .topLeading) {
                // Danger zone (UV >= 6)
                let dangerY = h * (1 - 6.0 / CGFloat(maxUV))
                Rectangle().fill(Color(hex: "F87171").opacity(0.08))
                    .frame(height: dangerY).offset(y: 0)

                // Line
                Path { path in
                    for (i, f) in forecasts.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(count)
                        let y = h * (1 - CGFloat(f.uvIndex) / CGFloat(maxUV))
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color(hex: "FBBF24"), lineWidth: 2)

                // Time labels
                HStack {
                    Text("Now").font(.system(size: 8)).foregroundStyle(.tertiary)
                    Spacer()
                    Text("+24h").font(.system(size: 8)).foregroundStyle(.tertiary)
                }
                .offset(y: h + 4)
            }
        }
    }
}

// MARK: - Pressure Detail Sheet

struct PressureDetailSheet: View {
    let info: PressureInfo
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current reading
                    VStack(spacing: 12) {
                        ZStack {
                            Circle().fill(Color(hex: info.trend.color).opacity(0.15)).frame(width: 100, height: 100)
                            VStack(spacing: 4) {
                                Image(systemName: "gauge.open.with.lines.needle.33percent").font(.title).symbolRenderingMode(.hierarchical).foregroundStyle(Color(hex: info.trend.color))
                                Text(WeatherFormatters.pressure(info.currentPressure)).font(.subheadline).fontWeight(.bold)
                            }
                        }
                        Text(info.trend.rawValue).font(.title3).fontWeight(.semibold).foregroundStyle(Color(hex: info.trend.color))

                        let change = info.pressureIn10h - info.currentPressure
                        let sign = change >= 0 ? "+" : ""
                        Text("\(sign)\(String(format: "%.1f", change)) hPa in next 10 hours").font(.caption).foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // Pressure trend chart (interactive)
                    if info.hourlyReadings.count >= 2 {
                        VStack(alignment: .leading, spacing: 8) {
                            sectionLabel("12-HOUR PRESSURE", icon: "chart.xyaxis.line")
                            InteractiveLineChart(
                                dataPoints: info.hourlyReadings.map {
                                    InteractiveLineChart.ChartDataPoint(time: $0.date, value: $0.pressure)
                                },
                                lineColor: Color(hex: info.trend.color),
                                fillColor: Color(hex: info.trend.color),
                                unit: "hPa"
                            )
                            .frame(height: 120)
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))
                    }

                    // What it means
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("WHAT THIS MEANS", icon: "info.circle.fill")
                        ForEach(Array(pressureInfo.enumerated()), id: \.offset) { _, item in
                            HStack(alignment: .top, spacing: 10) {
                                Image(systemName: item.0).font(.body).foregroundStyle(Color(hex: info.trend.color)).frame(width: 24)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.1).font(.subheadline).fontWeight(.medium)
                                    Text(item.2).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // Reference
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("PRESSURE GUIDE", icon: "gauge.medium")
                        pressureRef("Low", "< 1000 hPa", "Unsettled, rainy weather likely")
                        pressureRef("Normal", "1000–1020 hPa", "Typical conditions")
                        pressureRef("High", "> 1020 hPa", "Fair, dry weather expected")
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))
                }
                .padding(.horizontal, 4)
            }
            .background(Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("Air Pressure")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        }
    }

    private var pressureInfo: [(String, String, String)] {
        switch info.trend {
        case .risingFast: return [("arrow.up.circle.fill", "Rapid rise", "Skies clearing quickly — possible strong winds as weather front passes."), ("sun.max.fill", "Improving fast", "Expect clear, dry conditions within hours.")]
        case .rising: return [("arrow.up.right", "Gradually rising", "Weather is improving — drier conditions moving in."), ("sun.max.fill", "Fair outlook", "Good conditions for outdoor plans.")]
        case .stable: return [("equal.circle.fill", "Holding steady", "Current weather pattern will persist."), ("clock.fill", "No change expected", "Conditions will remain similar for the next several hours.")]
        case .falling: return [("arrow.down.right", "Gradually falling", "Weather may deteriorate — clouds and rain possible."), ("umbrella.fill", "Prepare for change", "Consider bringing rain gear if heading out.")]
        case .fallingFast: return [("arrow.down.circle.fill", "Rapid drop", "Significant weather change incoming — possible storms."), ("cloud.bolt.rain.fill", "Storm potential", "Monitor conditions closely — strong weather possible.")]
        }
    }

    private func pressureRef(_ name: String, _ range: String, _ desc: String) -> some View {
        HStack(spacing: 8) {
            Text(name).font(.caption).fontWeight(.medium).frame(width: 55, alignment: .leading)
            Text(range).font(.caption2).foregroundStyle(.secondary).frame(width: 90, alignment: .leading)
            Text(desc).font(.caption2).foregroundStyle(.tertiary)
        }
    }
}

// MARK: - Wind Detail Sheet

struct WindDetailSheet: View {
    let wind: WindInfo
    let hourlyForecasts: [HourlyForecast]
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current wind
                    VStack(spacing: 12) {
                        Text(wind.beaufort.name).font(.title2).fontWeight(.bold)
                        Text(wind.beaufort.description).font(.caption).foregroundStyle(.secondary)

                        HStack(spacing: 30) {
                            windMetric("Speed", WeatherFormatters.windSpeed(wind.speed), "wind")
                            windMetric("Gusts", WeatherFormatters.windSpeed(wind.gusts), "wind.circle")
                            windMetric("Direction", "\(wind.compassDirection) \(wind.direction)°", "location.north.fill")
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // Hourly wind chart (interactive)
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("24-HOUR WIND", icon: "chart.xyaxis.line")
                        InteractiveLineChart(
                            dataPoints: hourlyForecasts.prefix(24).map {
                                InteractiveLineChart.ChartDataPoint(time: $0.time, value: $0.windSpeed)
                            },
                            lineColor: .blue,
                            fillColor: .blue,
                            unit: UnitSettings.shared.windSpeed
                        )
                        .frame(height: 120)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // Beaufort scale
                    VStack(alignment: .leading, spacing: 8) {
                        sectionLabel("BEAUFORT SCALE", icon: "gauge.medium")

                        let scales: [(String, String, String)] = [
                            ("Calm", "< 1", "Smoke rises vertically"),
                            ("Light Breeze", "4–7", "Leaves rustle"),
                            ("Moderate", "13–18", "Raises dust and paper"),
                            ("Fresh Breeze", "19–24", "Small trees sway"),
                            ("Strong Breeze", "25–31", "Large branches move"),
                            ("Gale", "39–46", "Walking difficult"),
                            ("Storm", "55–63", "Trees uprooted"),
                            ("Hurricane", "73+", "Devastating damage"),
                        ]

                        ForEach(Array(scales.enumerated()), id: \.offset) { _, s in
                            HStack(spacing: 8) {
                                Text(s.0).font(.caption).fontWeight(.medium).frame(width: 90, alignment: .leading)
                                Text(s.1 + " mph").font(.caption2).foregroundStyle(.secondary).frame(width: 65, alignment: .leading)
                                Text(s.2).font(.caption2).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))
                }
                .padding(.horizontal, 4)
            }
            .background(Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("Wind")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        }
    }

    private func windMetric(_ label: String, _ value: String, _ icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.body).foregroundStyle(.blue)
            Text(value).font(.subheadline).fontWeight(.semibold)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
    }
}

private struct WindHourlyChart: View {
    let forecasts: [HourlyForecast]

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width, h = geo.size.height
            let maxWind = max(forecasts.map(\.windSpeed).max() ?? 1, 5)
            let count = max(forecasts.count - 1, 1)

            ZStack(alignment: .topLeading) {
                Path { path in
                    for (i, f) in forecasts.enumerated() {
                        let x = w * CGFloat(i) / CGFloat(count)
                        let y = h * (1 - CGFloat(f.windSpeed) / CGFloat(maxWind))
                        if i == 0 { path.move(to: CGPoint(x: x, y: y)) } else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color.blue, lineWidth: 2)

                HStack {
                    Text("Now").font(.system(size: 8)).foregroundStyle(.tertiary)
                    Spacer()
                    Text("+24h").font(.system(size: 8)).foregroundStyle(.tertiary)
                }
                .offset(y: h + 4)
            }
        }
    }
}

// MARK: - Sunrise & Sunset Detail Sheet

struct SunDetailSheet: View {
    let sunriseDate: Date
    let sunsetDate: Date
    let tomorrowSunrise: Date?
    let tomorrowSunset: Date?
    let dailyForecasts: [DailyForecast]
    @Environment(\.dismiss) private var dismiss

    private var daylight: TimeInterval { sunsetDate.timeIntervalSince(sunriseDate) }
    private var firstLight: Date { sunriseDate.addingTimeInterval(-30 * 60) }
    private var lastLight: Date { sunsetDate.addingTimeInterval(30 * 60) }
    private var solarNoon: Date { sunriseDate.addingTimeInterval(daylight / 2) }
    private var goldenHourMorning: (start: Date, end: Date) { (sunriseDate, sunriseDate.addingTimeInterval(3600)) }
    private var goldenHourEvening: (start: Date, end: Date) { (sunsetDate.addingTimeInterval(-3600), sunsetDate) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Today's sun times
                    VStack(spacing: 16) {
                        HStack(spacing: 30) {
                            sunTimeBlock("Sunrise", sunriseDate, "sunrise.fill", .orange)
                            sunTimeBlock("Sunset", sunsetDate, "sunset.fill", .orange)
                        }

                        Divider().background(.white.opacity(0.1))

                        HStack(spacing: 30) {
                            sunTimeBlock("First Light", firstLight, "sparkles", .blue)
                            sunTimeBlock("Last Light", lastLight, "moon.haze.fill", .indigo)
                        }

                        Divider().background(.white.opacity(0.1))

                        HStack {
                            Image(systemName: "sun.max.fill").font(.caption).foregroundStyle(.yellow)
                            Text("Total Daylight").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(formatDuration(daylight)).font(.subheadline).fontWeight(.semibold)
                        }

                        HStack {
                            Image(systemName: "sun.and.horizon.fill").font(.caption).foregroundStyle(.orange)
                            Text("Solar Noon").font(.caption).foregroundStyle(.secondary)
                            Spacer()
                            Text(WeatherFormatters.shortTime(solarNoon)).font(.subheadline).fontWeight(.semibold)
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // Golden hour
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("GOLDEN HOUR", icon: "camera.fill")

                        HStack(spacing: 20) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Morning").font(.caption).foregroundStyle(.secondary)
                                Text("\(WeatherFormatters.shortTime(goldenHourMorning.start)) – \(WeatherFormatters.shortTime(goldenHourMorning.end))")
                                    .font(.subheadline).fontWeight(.medium).foregroundStyle(.orange)
                            }
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Evening").font(.caption).foregroundStyle(.secondary)
                                Text("\(WeatherFormatters.shortTime(goldenHourEvening.start)) – \(WeatherFormatters.shortTime(goldenHourEvening.end))")
                                    .font(.subheadline).fontWeight(.medium).foregroundStyle(.orange)
                            }
                        }

                        Text("Best natural light for photography — warm, soft, diffused.")
                            .font(.caption).foregroundStyle(.tertiary)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // Tomorrow
                    if let tmrRise = tomorrowSunrise, let tmrSet = tomorrowSunset {
                        VStack(alignment: .leading, spacing: 12) {
                            sectionLabel("TOMORROW", icon: "calendar")
                            HStack(spacing: 30) {
                                sunTimeBlock("Sunrise", tmrRise, "sunrise.fill", .orange)
                                sunTimeBlock("Sunset", tmrSet, "sunset.fill", .orange)
                            }

                            let tmrDaylight = tmrSet.timeIntervalSince(tmrRise)
                            let diff = tmrDaylight - daylight
                            let sign = diff >= 0 ? "+" : ""
                            HStack {
                                Text("Daylight change").font(.caption).foregroundStyle(.secondary)
                                Spacer()
                                Text("\(sign)\(Int(diff / 60))m vs today").font(.caption).fontWeight(.medium)
                                    .foregroundStyle(diff >= 0 ? Color(hex: "34D399") : Color(hex: "F87171"))
                            }
                        }
                        .padding(16)
                        .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))
                    }
                }
                .padding(.horizontal, 4)
            }
            .background(Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("Sunrise & Sunset")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        }
    }

    private func sunTimeBlock(_ label: String, _ date: Date, _ icon: String, _ color: Color) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon).font(.title3).foregroundStyle(color)
            Text(WeatherFormatters.shortTime(date)).font(.subheadline).fontWeight(.semibold)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let h = Int(interval) / 3600; let m = (Int(interval) % 3600) / 60
        return "\(h)h \(m)m"
    }
}

// MARK: - Shared Section Label Helper

func sectionLabel(_ title: String, icon: String) -> some View {
    HStack(spacing: 6) {
        Image(systemName: icon).font(.caption).foregroundStyle(.secondary)
        Text(title).font(.caption).fontWeight(.bold).foregroundStyle(.secondary).tracking(1)
    }
}
