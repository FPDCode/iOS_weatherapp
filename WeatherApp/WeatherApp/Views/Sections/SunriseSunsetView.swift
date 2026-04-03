import SwiftUI

struct SunriseSunsetView: View {
    let sunriseDate: Date
    let sunsetDate: Date
    let tomorrowSunrise: Date?
    let tomorrowSunset: Date?

    private let now = Date()

    // Civil twilight is ~30 minutes before sunrise / after sunset
    private let twilightOffset: TimeInterval = 30 * 60

    private var firstLight: Date { sunriseDate.addingTimeInterval(-twilightOffset) }
    private var lastLight: Date { sunsetDate.addingTimeInterval(twilightOffset) }

    private var isDaytime: Bool {
        now >= sunriseDate && now <= sunsetDate
    }

    private var totalDaylight: TimeInterval {
        sunsetDate.timeIntervalSince(sunriseDate)
    }

    private var remainingDaylight: TimeInterval? {
        guard isDaytime else { return nil }
        return sunsetDate.timeIntervalSince(now)
    }

    private var nextEvent: (label: String, time: Date, icon: String) {
        if now < sunriseDate {
            return ("Sunrise", sunriseDate, "sunrise.fill")
        } else if now < sunsetDate {
            return ("Sunset", sunsetDate, "sunset.fill")
        } else if let tomorrow = tomorrowSunrise {
            return ("Sunrise", tomorrow, "sunrise.fill")
        } else {
            return ("Sunrise", sunriseDate.addingTimeInterval(86400), "sunrise.fill")
        }
    }

    /// Sun position along the arc: 0 = sunrise, 1 = sunset
    private var sunProgress: Double {
        guard isDaytime, totalDaylight > 0 else {
            if now < sunriseDate { return -0.05 }
            return 1.05
        }
        let elapsed = now.timeIntervalSince(sunriseDate)
        return min(max(elapsed / totalDaylight, 0), 1)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Sunrise & Sunset", icon: "sun.horizon.fill")

            // Sun arc
            SunArcView(progress: sunProgress, isDaytime: isDaytime)
                .frame(height: 100)
                .padding(.horizontal, 8)

            // Sunrise / Sunset times below arc
            HStack {
                Label(WeatherFormatters.shortTime(sunriseDate), systemImage: "sunrise.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Spacer()
                Label(WeatherFormatters.shortTime(sunsetDate), systemImage: "sunset.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            .padding(.horizontal, 8)

            Divider().background(.white.opacity(0.1))

            // Info rows
            VStack(spacing: 8) {
                // Next event
                InfoRow(
                    icon: nextEvent.icon,
                    iconColor: .orange,
                    label: "Next \(nextEvent.label)",
                    value: WeatherFormatters.shortTime(nextEvent.time),
                    detail: timeUntil(nextEvent.time)
                )

                // Remaining daylight or total daylight
                if let remaining = remainingDaylight {
                    InfoRow(
                        icon: "sun.max.fill",
                        iconColor: .yellow,
                        label: "Remaining Daylight",
                        value: formatDuration(remaining),
                        detail: nil
                    )
                } else {
                    InfoRow(
                        icon: "sun.max.fill",
                        iconColor: .yellow,
                        label: "Total Daylight",
                        value: formatDuration(totalDaylight),
                        detail: nil
                    )
                }

                // First light / Last light
                InfoRow(
                    icon: "sparkles",
                    iconColor: .blue.opacity(0.7),
                    label: "First Light",
                    value: WeatherFormatters.shortTime(firstLight),
                    detail: "Civil twilight"
                )

                InfoRow(
                    icon: "moon.haze.fill",
                    iconColor: .indigo.opacity(0.7),
                    label: "Last Light",
                    value: WeatherFormatters.shortTime(lastLight),
                    detail: "Civil twilight"
                )
            }
        }
    }

    private func timeUntil(_ date: Date) -> String? {
        let interval = date.timeIntervalSince(now)
        guard interval > 0 else { return nil }
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "in \(hours)h \(minutes)m"
        }
        return "in \(minutes)m"
    }

    private func formatDuration(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Info Row

private struct InfoRow: View {
    let icon: String
    let iconColor: Color
    let label: String
    let value: String
    let detail: String?

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(iconColor)
                .frame(width: 20)

            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                if let detail {
                    Text(detail)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }
}

// MARK: - Sun Arc View

struct SunArcView: View {
    let progress: Double
    let isDaytime: Bool

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let arcHeight = height - 20 // Leave room for the sun circle

            ZStack {
                // Horizon line
                Path { path in
                    path.move(to: CGPoint(x: 0, y: arcHeight))
                    path.addLine(to: CGPoint(x: width, y: arcHeight))
                }
                .stroke(.white.opacity(0.15), style: StrokeStyle(lineWidth: 1, dash: [4, 4]))

                // Day arc (semi-circle above horizon)
                Path { path in
                    path.addArc(
                        center: CGPoint(x: width / 2, y: arcHeight),
                        radius: width / 2,
                        startAngle: .degrees(180),
                        endAngle: .degrees(0),
                        clockwise: false
                    )
                }
                .stroke(.white.opacity(0.08), lineWidth: 1.5)

                // Lit portion of arc (from sunrise to current position)
                if isDaytime && progress > 0 {
                    Path { path in
                        let endAngle = 180 - (progress * 180)
                        path.addArc(
                            center: CGPoint(x: width / 2, y: arcHeight),
                            radius: width / 2,
                            startAngle: .degrees(180),
                            endAngle: .degrees(endAngle),
                            clockwise: false
                        )
                    }
                    .stroke(
                        LinearGradient(
                            colors: [.orange.opacity(0.6), .yellow.opacity(0.8)],
                            startPoint: .leading,
                            endPoint: .trailing
                        ),
                        lineWidth: 2.5
                    )
                }

                // Sun position
                let sunAngle = Angle.degrees(180 - (clampedProgress * 180))
                let sunX = width / 2 + (width / 2) * cos(sunAngle.radians)
                let sunY = arcHeight - (width / 2) * sin(sunAngle.radians)

                // Sun glow
                Circle()
                    .fill(isDaytime ? .yellow.opacity(0.15) : .blue.opacity(0.1))
                    .frame(width: 30, height: 30)
                    .position(x: sunX, y: sunY)

                // Sun circle
                Image(systemName: isDaytime ? "sun.max.fill" : "moon.fill")
                    .font(.system(size: 16))
                    .symbolRenderingMode(.multicolor)
                    .position(x: sunX, y: sunY)
            }
        }
    }

    private var clampedProgress: Double {
        min(max(progress, 0), 1)
    }
}
