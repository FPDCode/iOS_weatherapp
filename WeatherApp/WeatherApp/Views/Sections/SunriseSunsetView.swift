import SwiftUI

struct SunriseSunsetView: View {
    let sunriseDate: Date
    let sunsetDate: Date
    let tomorrowSunrise: Date?
    let tomorrowSunset: Date?

    private let now = Date()
    private let twilightOffset: TimeInterval = 30 * 60

    private var firstLight: Date { sunriseDate.addingTimeInterval(-twilightOffset) }
    private var lastLight: Date { sunsetDate.addingTimeInterval(twilightOffset) }

    private var isDaytime: Bool {
        now >= sunriseDate && now <= sunsetDate
    }

    private var totalDaylight: TimeInterval {
        sunsetDate.timeIntervalSince(sunriseDate)
    }

    // Night duration: from today's sunset to tomorrow's sunrise
    private var totalNight: TimeInterval {
        let nextSunrise = tomorrowSunrise ?? sunriseDate.addingTimeInterval(86400)
        return nextSunrise.timeIntervalSince(sunsetDate)
    }

    private var remainingDaylight: TimeInterval? {
        guard isDaytime else { return nil }
        return sunsetDate.timeIntervalSince(now)
    }

    private var remainingNight: TimeInterval? {
        guard !isDaytime else { return nil }
        let nextSunrise: Date
        if now < sunriseDate {
            nextSunrise = sunriseDate
        } else {
            nextSunrise = tomorrowSunrise ?? sunriseDate.addingTimeInterval(86400)
        }
        return nextSunrise.timeIntervalSince(now)
    }

    /// Sun progress: 0 = sunrise, 1 = sunset (daytime arc)
    private var sunProgress: Double {
        guard isDaytime, totalDaylight > 0 else { return 0 }
        let elapsed = now.timeIntervalSince(sunriseDate)
        return min(max(elapsed / totalDaylight, 0), 1)
    }

    /// Moon progress: 0 = sunset, 1 = sunrise (nighttime arc)
    private var moonProgress: Double {
        guard !isDaytime, totalNight > 0 else { return 0 }
        let elapsed: TimeInterval
        if now >= sunsetDate {
            elapsed = now.timeIntervalSince(sunsetDate)
        } else {
            // Before today's sunrise — measure from yesterday's sunset
            let yesterdaySunset = sunsetDate.addingTimeInterval(-86400)
            elapsed = now.timeIntervalSince(yesterdaySunset)
        }
        return min(max(elapsed / totalNight, 0), 1)
    }

    /// The center text in the arc
    private var arcCenterText: String {
        if isDaytime, let remaining = remainingDaylight {
            return formatDuration(remaining)
        } else if let remaining = remainingNight {
            return formatDuration(remaining)
        }
        return formatDuration(totalDaylight)
    }

    private var arcCenterLabel: String {
        if isDaytime {
            return "daylight left"
        } else {
            return "until sunrise"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Sunrise & Sunset", icon: "sun.horizon.fill")

            // Arc with center text
            ZStack {
                SunMoonArcView(
                    sunProgress: sunProgress,
                    moonProgress: moonProgress,
                    isDaytime: isDaytime
                )

                // Center text in the arc's negative space
                VStack(spacing: 2) {
                    Text(arcCenterText)
                        .font(.title2)
                        .fontWeight(.bold)
                    Text(arcCenterLabel)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .offset(y: -10)
            }
            .frame(height: 130)
            .padding(.horizontal, 8)

            // Sunrise + First Light | Sunset + Last Light
            HStack(alignment: .top) {
                // Left: Sunrise + First Light
                VStack(alignment: .leading, spacing: 4) {
                    Label(WeatherFormatters.shortTime(sunriseDate), systemImage: "sunrise.fill")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)

                    if isDaytime || now < sunriseDate {
                        Text(timeUntilOrSince(sunriseDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 9))
                            .foregroundStyle(.blue.opacity(0.7))
                        Text("\(WeatherFormatters.shortTime(firstLight))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Text("First light")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()

                // Right: Sunset + Last Light
                VStack(alignment: .trailing, spacing: 4) {
                    Label(WeatherFormatters.shortTime(sunsetDate), systemImage: "sunset.fill")
                        .font(.callout)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)

                    if isDaytime {
                        Text(timeUntilOrSince(sunsetDate))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 4) {
                        Text("Last light")
                            .font(.system(size: 9))
                            .foregroundStyle(.tertiary)
                        Text("\(WeatherFormatters.shortTime(lastLight))")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                        Image(systemName: "moon.haze.fill")
                            .font(.system(size: 9))
                            .foregroundStyle(.indigo.opacity(0.7))
                    }
                }
            }
            .padding(.horizontal, 8)

            Divider().background(.white.opacity(0.1))

            // Total daylight
            HStack(spacing: 10) {
                Image(systemName: "sun.max.fill")
                    .font(.caption)
                    .foregroundStyle(.yellow)
                    .frame(width: 20)
                Text("Total Daylight")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text(formatDuration(totalDaylight))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }
        }
    }

    private func timeUntilOrSince(_ date: Date) -> String {
        let interval = date.timeIntervalSince(now)
        if interval > 0 {
            let hours = Int(interval) / 3600
            let minutes = (Int(interval) % 3600) / 60
            return hours > 0 ? "in \(hours)h \(minutes)m" : "in \(minutes)m"
        } else {
            let elapsed = abs(interval)
            let hours = Int(elapsed) / 3600
            let minutes = (Int(elapsed) % 3600) / 60
            return hours > 0 ? "\(hours)h \(minutes)m ago" : "\(minutes)m ago"
        }
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Sun/Moon Arc View

struct SunMoonArcView: View {
    let sunProgress: Double
    let moonProgress: Double
    let isDaytime: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let horizonY = height - 10
            // Radius = min of half-width and available height, so arc fits as a 180° semi-circle
            let radius = min(width / 2 - 10, horizonY - 15)

            ZStack {
                // Horizon line
                Path { path in
                    path.move(to: CGPoint(x: 10, y: horizonY))
                    path.addLine(to: CGPoint(x: width - 10, y: horizonY))
                }
                .stroke(.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                if isDaytime {
                    // Day arc (above horizon)
                    dayArc(width: width, horizonY: horizonY, radius: radius)
                } else {
                    // Night arc (below horizon, inverted)
                    nightArc(width: width, horizonY: horizonY, radius: radius)
                }
            }
        }
    }

    private func dayArc(width: CGFloat, horizonY: CGFloat, radius: CGFloat) -> some View {
        let center = CGPoint(x: width / 2, y: horizonY)

        return ZStack {
            // Full arc outline
            Path { path in
                path.addArc(center: center, radius: radius,
                           startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            }
            .stroke(.white.opacity(0.08), lineWidth: 1.5)

            // Lit portion
            if sunProgress > 0 {
                Path { path in
                    let endAngle = 180 - (sunProgress * 180)
                    path.addArc(center: center, radius: radius,
                               startAngle: .degrees(180), endAngle: .degrees(endAngle), clockwise: false)
                }
                .stroke(
                    LinearGradient(colors: [.orange.opacity(0.6), .yellow.opacity(0.8)],
                                   startPoint: .leading, endPoint: .trailing),
                    lineWidth: 2.5
                )
            }

            // Sun position
            sunOrMoonIcon(
                progress: min(max(sunProgress, 0.02), 0.98),
                center: center, radius: radius,
                icon: "sun.max.fill", glowColor: .yellow, isDay: true
            )
        }
    }

    private func nightArc(width: CGFloat, horizonY: CGFloat, radius: CGFloat) -> some View {
        // Night arc goes below the horizon (inverted semi-circle)
        // But we show it above for visibility, just with night styling
        let center = CGPoint(x: width / 2, y: horizonY)

        return ZStack {
            // Full arc outline (dimmer for night)
            Path { path in
                path.addArc(center: center, radius: radius,
                           startAngle: .degrees(180), endAngle: .degrees(0), clockwise: false)
            }
            .stroke(.white.opacity(0.06), lineWidth: 1.5)

            // Lit portion (night progress)
            if moonProgress > 0 {
                Path { path in
                    let endAngle = 180 - (moonProgress * 180)
                    path.addArc(center: center, radius: radius,
                               startAngle: .degrees(180), endAngle: .degrees(endAngle), clockwise: false)
                }
                .stroke(
                    LinearGradient(colors: [.indigo.opacity(0.4), .blue.opacity(0.5)],
                                   startPoint: .leading, endPoint: .trailing),
                    lineWidth: 2.5
                )
            }

            // Moon position
            sunOrMoonIcon(
                progress: min(max(moonProgress, 0.02), 0.98),
                center: center, radius: radius,
                icon: "moon.fill", glowColor: .blue, isDay: false
            )
        }
    }

    private func sunOrMoonIcon(progress: Double, center: CGPoint, radius: CGFloat,
                                icon: String, glowColor: Color, isDay: Bool) -> some View {
        let angle = Angle.degrees(180 - (progress * 180))
        let x = center.x + radius * cos(angle.radians)
        let y = center.y - radius * sin(angle.radians)

        return ZStack {
            Circle()
                .fill(glowColor.opacity(isDay ? 0.15 : 0.1))
                .frame(width: 30, height: 30)
                .position(x: x, y: y)

            Image(systemName: icon)
                .font(.system(size: 16))
                .symbolRenderingMode(.multicolor)
                .position(x: x, y: y)
        }
    }
}
