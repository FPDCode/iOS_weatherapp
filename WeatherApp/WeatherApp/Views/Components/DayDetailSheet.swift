import SwiftUI

struct DayDetailSheet: View {
    @EnvironmentObject var weatherViewModel: WeatherViewModel
    @Binding var selectedDate: Date
    let forecasts: [DailyForecast]
    @Environment(\.dismiss) private var dismiss
    @State private var selectedActivity: OutdoorActivity = .running

    private var selectedForecast: DailyForecast? {
        let calendar = Calendar.current
        return forecasts.first { calendar.isDate($0.date, inSameDayAs: selectedDate) }
    }

    private var hourlyData: [HourlyForecast] {
        weatherViewModel.hourlyForDate(selectedDate)
    }

    private var activityWindows: [ScoredActivityWindow] {
        guard !hourlyData.isEmpty else { return [] }
        // Create 2-hour slots from 6am to 10pm
        let calendar = Calendar.current
        let dayStart = calendar.startOfDay(for: selectedDate)
        var slots: [FreeTimeSlot] = []
        for h in stride(from: 6, to: 22, by: 1) {
            guard let start = calendar.date(byAdding: .hour, value: h, to: dayStart),
                  let end = calendar.date(byAdding: .hour, value: h + 2, to: dayStart) else { continue }
            slots.append(FreeTimeSlot(start: start, end: end, source: .default))
        }
        return ActivityScorer.scoreActivities(
            slots: slots,
            hourlyForecasts: hourlyData,
            activities: [selectedActivity]
        )
    }

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradient.forTimeOfDay(
                    isDay: weatherViewModel.isDay,
                    weatherCode: selectedForecast?.weatherCode ?? 0
                )
                .ignoresSafeArea()

                ScrollView(.vertical, showsIndicators: false) {
                    VStack(spacing: 16) {
                        // Date picker strip
                        DateStripPicker(
                            selectedDate: $selectedDate,
                            forecasts: forecasts
                        )
                        .padding(.top, 8)

                        if let forecast = selectedForecast {
                            // Header
                            DayDetailHeader(forecast: forecast)

                            // Temperature curve
                            if !hourlyData.isEmpty {
                                GlassCard {
                                    TemperatureCurveSection(hourly: hourlyData)
                                }
                            }

                            // Precipitation
                            GlassCard {
                                PrecipitationDetailSection(forecast: forecast, hourly: hourlyData)
                            }

                            // Wind
                            GlassCard {
                                WindDetailSection(forecast: forecast)
                            }

                            // Sun & UV
                            GlassCard {
                                SunDetailSection(forecast: forecast)
                            }

                            // Conditions grid
                            if !hourlyData.isEmpty {
                                GlassCard {
                                    ConditionsGridSection(hourly: hourlyData)
                                }
                            }

                            // Best time for activities
                            if !hourlyData.isEmpty {
                                GlassCard {
                                    DayActivitySection(
                                        selectedActivity: $selectedActivity,
                                        windows: activityWindows
                                    )
                                }
                            }
                        } else {
                            Text("No data available for this date")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                                .padding(.top, 40)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 40)
                }
            }
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
        }
    }
}

// MARK: - Date Strip Picker

struct DateStripPicker: View {
    @Binding var selectedDate: Date
    let forecasts: [DailyForecast]

    private let calendar = Calendar.current

    private var fullDateString: String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EEEE, d MMMM yyyy"
        return f.string(from: selectedDate)
    }

    var body: some View {
        VStack(spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(forecasts) { forecast in
                            let isSelected = calendar.isDate(forecast.date, inSameDayAs: selectedDate)

                            VStack(spacing: 4) {
                                // Day letter
                                Text(dayLetter(forecast.date))
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundStyle(isSelected ? .white : .secondary)

                                // Day number
                                Text("\(calendar.component(.day, from: forecast.date))")
                                    .font(.title3)
                                    .fontWeight(isSelected ? .bold : .regular)
                                    .foregroundStyle(isSelected ? .white : .primary)
                            }
                            .frame(width: 44, height: 60)
                            .background(
                                Circle()
                                    .fill(isSelected ? .cyan : .clear)
                                    .frame(width: 44, height: 44)
                                    .offset(y: 8)
                            )
                            .id(forecast.id)
                            .onTapGesture {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    selectedDate = forecast.date
                                }
                                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .onChange(of: selectedDate) { _, newDate in
                    if let match = forecasts.first(where: { calendar.isDate($0.date, inSameDayAs: newDate) }) {
                        withAnimation {
                            proxy.scrollTo(match.id, anchor: .center)
                        }
                    }
                }
            }

            Text(fullDateString)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }

    private func dayLetter(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EEEEE" // Single letter
        return f.string(from: date)
    }
}

// MARK: - Day Detail Header

struct DayDetailHeader: View {
    let forecast: DailyForecast

    var body: some View {
        VStack(spacing: 6) {
            Image(systemName: WeatherCodeInfo.sfSymbol(for: forecast.weatherCode))
                .font(.system(size: 48))
                .symbolRenderingMode(.multicolor)

            Text(WeatherCodeInfo.description(for: forecast.weatherCode))
                .font(.title3)
                .fontWeight(.medium)

            HStack(spacing: 20) {
                Label(WeatherFormatters.temperature(forecast.tempHigh), systemImage: "arrow.up")
                    .font(.title3)
                    .fontWeight(.semibold)
                Label(WeatherFormatters.temperature(forecast.tempLow), systemImage: "arrow.down")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(.vertical, 8)
    }
}

// MARK: - Temperature Curve

struct TemperatureCurveSection: View {
    let hourly: [HourlyForecast]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Temperature", icon: "thermometer")

            // Mini temp curve
            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height
                let temps = hourly.map(\.temperature)
                let feels = hourly.map(\.feelsLike)
                let minT = min(temps.min() ?? 0, feels.min() ?? 0) - 2
                let maxT = max(temps.max() ?? 1, feels.max() ?? 1) + 2
                let range = max(maxT - minT, 1)

                ZStack {
                    // Feels like line (dashed)
                    linePath(values: feels, minVal: minT, range: range, width: width, height: height)
                        .stroke(.white.opacity(0.2), style: StrokeStyle(lineWidth: 1.5, dash: [4, 4]))

                    // Temperature line
                    linePath(values: temps, minVal: minT, range: range, width: width, height: height)
                        .stroke(
                            LinearGradient(colors: [.blue, .yellow, .orange], startPoint: .leading, endPoint: .trailing),
                            lineWidth: 2.5
                        )
                }
            }
            .frame(height: 60)

            // Time labels
            HStack {
                ForEach([0, hourly.count / 4, hourly.count / 2, 3 * hourly.count / 4, hourly.count - 1], id: \.self) { i in
                    if i < hourly.count {
                        Text(WeatherFormatters.hourTime(hourly[i].time))
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }
                    if i != hourly.count - 1 { Spacer() }
                }
            }

            // Legend
            HStack(spacing: 16) {
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1).fill(.orange).frame(width: 16, height: 2)
                    Text("Temperature").font(.system(size: 9)).foregroundStyle(.secondary)
                }
                HStack(spacing: 4) {
                    RoundedRectangle(cornerRadius: 1).stroke(.white.opacity(0.3), style: StrokeStyle(lineWidth: 1, dash: [3, 3])).frame(width: 16, height: 2)
                    Text("Feels Like").font(.system(size: 9)).foregroundStyle(.secondary)
                }
            }
        }
    }

    private func linePath(values: [Double], minVal: Double, range: Double, width: CGFloat, height: CGFloat) -> Path {
        Path { path in
            for (i, val) in values.enumerated() {
                let x = width * CGFloat(i) / CGFloat(max(values.count - 1, 1))
                let y = height * (1 - CGFloat((val - minVal) / range))
                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                else { path.addLine(to: CGPoint(x: x, y: y)) }
            }
        }
    }
}

// MARK: - Precipitation Detail

struct PrecipitationDetailSection: View {
    let forecast: DailyForecast
    let hourly: [HourlyForecast]

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Precipitation", icon: "cloud.rain.fill")

            HStack(spacing: 0) {
                StatBox(label: "Chance", value: "\(forecast.precipChance)%", icon: "drop.fill", color: .cyan)
                StatBox(label: "Total", value: WeatherFormatters.precipitation(forecast.precipSum), icon: "drop.triangle.fill", color: .blue)
                StatBox(label: "Hours", value: String(format: "%.0fh", forecast.precipHours), icon: "clock.fill", color: .indigo)
            }

            // Hourly precip bars
            if !hourly.isEmpty {
                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(hourly) { h in
                        let maxP = max(hourly.map(\.precipAmount).max() ?? 1, 0.5)
                        let ratio = h.precipAmount / maxP
                        RoundedRectangle(cornerRadius: 2)
                            .fill(h.precipAmount > 0.1 ? Color.blue.opacity(0.3 + ratio * 0.7) : .white.opacity(0.05))
                            .frame(height: max(CGFloat(ratio) * 30, 3))
                    }
                }
                .frame(height: 30)
            }
        }
    }
}

// MARK: - Wind Detail

struct WindDetailSection: View {
    let forecast: DailyForecast

    private var compassDir: String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((Double(forecast.windDirectionDominant) + 11.25) / 22.5) % 16
        return directions[index]
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Wind", icon: "wind")

            HStack(spacing: 0) {
                StatBox(label: "Max Speed", value: WeatherFormatters.windSpeed(forecast.windSpeedMax), icon: "wind", color: .blue)
                StatBox(label: "Max Gusts", value: WeatherFormatters.windSpeed(forecast.windGustsMax), icon: "wind.circle", color: .orange)
                StatBox(label: "Direction", value: "\(compassDir) \(forecast.windDirectionDominant)°", icon: "location.north.fill", color: .green)
            }
        }
    }
}

// MARK: - Sun Detail

struct SunDetailSection: View {
    let forecast: DailyForecast

    private var sunshineHours: String {
        let h = Int(forecast.sunshineDuration) / 3600
        let m = (Int(forecast.sunshineDuration) % 3600) / 60
        return "\(h)h \(m)m"
    }

    private var daylightHours: String {
        let h = Int(forecast.daylightDuration) / 3600
        let m = (Int(forecast.daylightDuration) % 3600) / 60
        return "\(h)h \(m)m"
    }

    private var sunshinePercent: Int {
        guard forecast.daylightDuration > 0 else { return 0 }
        return Int((forecast.sunshineDuration / forecast.daylightDuration) * 100)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Sun & UV", icon: "sun.max.fill")

            HStack(spacing: 0) {
                StatBox(label: "Sunshine", value: sunshineHours, icon: "sun.max.fill", color: .yellow)
                StatBox(label: "Daylight", value: daylightHours, icon: "sun.horizon.fill", color: .orange)
                StatBox(label: "UV Max", value: String(format: "%.0f", forecast.uvIndexMax), icon: "sun.max.trianglebadge.exclamationmark", color: forecast.uvIndexMax >= 6 ? .red : .yellow)
            }

            // Sunrise/Sunset
            HStack(spacing: 20) {
                Label(formatSunTime(forecast.sunrise), systemImage: "sunrise.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Label(formatSunTime(forecast.sunset), systemImage: "sunset.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Spacer()
                Text("\(sunshinePercent)% sunny")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.yellow)
            }
        }
    }

    private func formatSunTime(_ timeStr: String) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd'T'HH:mm"
        f.locale = Locale(identifier: "en_US_POSIX")
        guard let date = f.date(from: timeStr) else { return "" }
        return WeatherFormatters.shortTime(date)
    }
}

// MARK: - Conditions Grid

struct ConditionsGridSection: View {
    let hourly: [HourlyForecast]

    private var avgHumidity: Int { hourly.map(\.humidity).reduce(0, +) / max(hourly.count, 1) }
    private var avgPressure: Double { hourly.map(\.pressure).reduce(0, +) / Double(max(hourly.count, 1)) }
    private var avgVisibility: Double { hourly.map(\.visibility).reduce(0, +) / Double(max(hourly.count, 1)) }
    private var maxUV: Double { hourly.map(\.uvIndex).max() ?? 0 }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Conditions", icon: "list.bullet")

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 10) {
                ConditionCell(icon: "humidity.fill", label: "Humidity", value: "\(avgHumidity)%")
                ConditionCell(icon: "gauge.medium", label: "Pressure", value: WeatherFormatters.pressure(avgPressure))
                ConditionCell(icon: "eye.fill", label: "Visibility", value: WeatherFormatters.visibility(avgVisibility))
                ConditionCell(icon: "sun.max.fill", label: "UV Index", value: String(format: "%.0f", maxUV))
            }
        }
    }
}

struct ConditionCell: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .symbolRenderingMode(.multicolor)
                .frame(width: 20)
            VStack(alignment: .leading, spacing: 1) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.tertiary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
            Spacer()
        }
        .padding(8)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(.white.opacity(0.05))
        )
    }
}

// MARK: - Stat Box

struct StatBox: View {
    let label: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Day Activity Section

struct DayActivitySection: View {
    @Binding var selectedActivity: OutdoorActivity
    let windows: [ScoredActivityWindow]

    private var bestWindow: ScoredActivityWindow? {
        windows.first
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Best Time For Activities", icon: "figure.run")

            // Activity picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(OutdoorActivity.allCases) { activity in
                        HStack(spacing: 4) {
                            Image(systemName: activity.icon)
                                .font(.caption2)
                            Text(activity.rawValue)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(
                            Capsule()
                                .fill(selectedActivity == activity ? .white.opacity(0.25) : .white.opacity(0.08))
                        )
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(selectedActivity == activity ? 0.4 : 0.1), lineWidth: 1)
                        )
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedActivity = activity
                            }
                        }
                    }
                }
            }

            // Best pick highlight
            if let best = bestWindow, best.score >= 40 {
                HStack(spacing: 10) {
                    Image(systemName: "star.fill")
                        .font(.body)
                        .foregroundStyle(.yellow)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Best: \(WeatherFormatters.shortTime(best.slot.start)) – \(WeatherFormatters.shortTime(best.slot.end))")
                            .font(.subheadline)
                            .fontWeight(.semibold)

                        HStack(spacing: 6) {
                            Text(best.rating.rawValue)
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(Color(hex: best.rating.color))
                            Text("Score: \(Int(best.score))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    Spacer()

                    // Weather at that time
                    VStack(spacing: 2) {
                        Image(systemName: WeatherCodeInfo.sfSymbol(for: best.weatherCode))
                            .symbolRenderingMode(.multicolor)
                        Text(WeatherFormatters.temperature(best.avgTemp))
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                }
                .padding(10)
                .background(
                    RoundedRectangle(cornerRadius: 10, style: .continuous)
                        .fill(.yellow.opacity(0.08))
                        .overlay(
                            RoundedRectangle(cornerRadius: 10, style: .continuous)
                                .stroke(.yellow.opacity(0.15), lineWidth: 1)
                        )
                )
            }

            // All windows ranked
            if windows.isEmpty {
                Text("No suitable windows for \(selectedActivity.rawValue.lowercased()) this day")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 8)
            } else {
                ForEach(windows.prefix(5)) { window in
                    DayActivityRow(window: window)
                }
            }
        }
    }
}

struct DayActivityRow: View {
    let window: ScoredActivityWindow

    var body: some View {
        HStack(spacing: 10) {
            // Score circle
            ZStack {
                Circle()
                    .fill(Color(hex: window.rating.color).opacity(0.15))
                    .frame(width: 36, height: 36)
                Text("\(Int(window.score))")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(Color(hex: window.rating.color))
            }

            // Time + weather
            VStack(alignment: .leading, spacing: 2) {
                Text("\(WeatherFormatters.shortTime(window.slot.start)) – \(WeatherFormatters.shortTime(window.slot.end))")
                    .font(.subheadline)
                    .fontWeight(.medium)

                HStack(spacing: 6) {
                    Image(systemName: WeatherCodeInfo.sfSymbol(for: window.weatherCode))
                        .font(.caption2)
                        .symbolRenderingMode(.multicolor)
                    Text(WeatherFormatters.temperature(window.avgTemp))
                        .font(.caption)
                    if window.maxPrecipChance > 5 {
                        Label("\(window.maxPrecipChance)%", systemImage: "drop.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                    Label(WeatherFormatters.windSpeed(window.avgWind), systemImage: "wind")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            // Top reason
            if let reason = window.reasons.first {
                Text(reason)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.trailing)
                    .frame(maxWidth: 90)
            }
        }
        .padding(.vertical, 4)
    }
}
