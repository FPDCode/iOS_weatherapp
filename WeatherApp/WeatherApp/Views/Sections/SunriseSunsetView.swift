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
                .offset(y: -20)
            }
            .frame(height: 150)
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
            let horizonY = height - 6
            let arcWidth = width - 20        // Horizontal span of the ellipse
            let arcHeight = height - 24       // Vertical span (flat ellipse)
            let centerX = width / 2
            let progress = isDaytime ? sunProgress : moonProgress

            ZStack {
                // Horizon dashed line
                Path { path in
                    path.move(to: CGPoint(x: 10, y: horizonY))
                    path.addLine(to: CGPoint(x: width - 10, y: horizonY))
                }
                .stroke(.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                // Remaining arc (white, faint — the "to go" portion)
                ellipticalArc(
                    centerX: centerX, horizonY: horizonY,
                    arcWidth: arcWidth, arcHeight: arcHeight,
                    fromProgress: progress, toProgress: 1.0
                )
                .stroke(.white.opacity(0.12), lineWidth: 2)

                // Completed arc (colored — the "past" portion)
                if progress > 0 {
                    ellipticalArc(
                        centerX: centerX, horizonY: horizonY,
                        arcWidth: arcWidth, arcHeight: arcHeight,
                        fromProgress: 0, toProgress: progress
                    )
                    .stroke(
                        isDaytime
                            ? LinearGradient(colors: [.orange.opacity(0.7), .yellow.opacity(0.9)], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.indigo.opacity(0.5), .blue.opacity(0.6)], startPoint: .leading, endPoint: .trailing),
                        lineWidth: 2.5
                    )
                }

                // Sun/Moon icon at current position
                iconAtProgress(
                    progress: min(max(progress, 0.02), 0.98),
                    centerX: centerX, horizonY: horizonY,
                    arcWidth: arcWidth, arcHeight: arcHeight
                )
            }
        }
    }

    /// Build an elliptical arc path from one progress to another (0 = left, 1 = right)
    private func ellipticalArc(
        centerX: CGFloat, horizonY: CGFloat,
        arcWidth: CGFloat, arcHeight: CGFloat,
        fromProgress: Double, toProgress: Double
    ) -> Path {
        Path { path in
            let steps = 60
            let startStep = Int(fromProgress * Double(steps))
            let endStep = Int(toProgress * Double(steps))
            guard endStep > startStep else { return }

            for i in startStep...endStep {
                let t = Double(i) / Double(steps)
                let angle = Double.pi * (1 - t) // π to 0 (left to right)
                let x = centerX + CGFloat(cos(angle)) * arcWidth / 2
                let y = horizonY - CGFloat(sin(angle)) * arcHeight

                if i == startStep {
                    path.move(to: CGPoint(x: x, y: y))
                } else {
                    path.addLine(to: CGPoint(x: x, y: y))
                }
            }
        }
    }

    /// Position the icon on the elliptical arc
    private func iconAtProgress(
        progress: Double, centerX: CGFloat, horizonY: CGFloat,
        arcWidth: CGFloat, arcHeight: CGFloat
    ) -> some View {
        let angle = Double.pi * (1 - progress)
        let x = centerX + CGFloat(cos(angle)) * arcWidth / 2
        let y = horizonY - CGFloat(sin(angle)) * arcHeight
        let icon = isDaytime ? "sun.max.fill" : "moon.fill"
        let glowColor: Color = isDaytime ? .yellow : .blue

        return ZStack {
            Circle()
                .fill(glowColor.opacity(isDaytime ? 0.15 : 0.1))
                .frame(width: 30, height: 30)
                .position(x: x, y: y)

            Image(systemName: icon)
                .font(.system(size: 16))
                .symbolRenderingMode(.multicolor)
                .position(x: x, y: y)
        }
    }
}
