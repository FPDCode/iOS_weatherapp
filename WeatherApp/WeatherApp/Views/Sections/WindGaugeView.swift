import SwiftUI
import CoreMotion
import CoreLocation

// MARK: - Heading Provider (Compass via CLLocationManager)

@MainActor
class HeadingProvider: NSObject, ObservableObject, CLLocationManagerDelegate {
    @Published var heading: Double = 0
    private let manager = CLLocationManager()

    override init() {
        super.init()
        manager.delegate = self
        if CLLocationManager.headingAvailable() {
            manager.headingFilter = 2 // update every 2 degrees
            manager.startUpdatingHeading()
        }
    }

    nonisolated func locationManager(_ manager: CLLocationManager, didUpdateHeading newHeading: CLHeading) {
        guard newHeading.headingAccuracy >= 0 else { return }
        let h = newHeading.trueHeading > 0 ? newHeading.trueHeading : newHeading.magneticHeading
        Task { @MainActor in
            withAnimation(.easeOut(duration: 0.3)) {
                self.heading = h
            }
        }
    }

    deinit {
        manager.stopUpdatingHeading()
    }
}

// MARK: - Wind Gauge View

struct WindGaugeView: View {
    let wind: WindInfo
    @StateObject private var headingProvider = HeadingProvider()

    /// Wind direction relative to where the phone is pointing
    private var relativeWindDirection: Double {
        let windDeg = Double(wind.direction)
        return windDeg - headingProvider.heading
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Wind", icon: "wind")

            HStack(spacing: 20) {
                // Compass gauge
                ZStack {
                    // Outer ring
                    Circle()
                        .stroke(.white.opacity(0.1), lineWidth: 2)
                        .frame(width: 140, height: 140)

                    // Cardinal direction marks
                    ForEach(0..<8, id: \.self) { i in
                        let angle = Double(i) * 45
                        let isMajor = i % 2 == 0
                        Rectangle()
                            .fill(.white.opacity(isMajor ? 0.4 : 0.15))
                            .frame(width: isMajor ? 2 : 1, height: isMajor ? 12 : 8)
                            .offset(y: -62)
                            .rotationEffect(.degrees(angle - headingProvider.heading))
                    }

                    // Cardinal labels (rotate with phone heading)
                    ForEach(Array(["N", "E", "S", "W"].enumerated()), id: \.offset) { index, label in
                        Text(label)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.white.opacity(0.5))
                            .offset(y: -50)
                            .rotationEffect(.degrees(Double(index) * 90 - headingProvider.heading))
                    }

                    // Wind direction arrow
                    WindArrow()
                        .fill(windArrowGradient)
                        .frame(width: 16, height: 60)
                        .offset(y: -20)
                        .rotationEffect(.degrees(relativeWindDirection))
                        .shadow(color: Color(hex: wind.beaufort.rawValue > 5 ? "F87171" : "60A5FA").opacity(0.5), radius: 6)

                    // Center dot
                    Circle()
                        .fill(.white)
                        .frame(width: 8, height: 8)

                    // Direction label at center bottom
                    VStack(spacing: 0) {
                        Spacer()
                        Text(wind.directionDescription)
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(.white.opacity(0.7))
                    }
                    .frame(height: 140)
                }
                .frame(width: 140, height: 140)

                // Wind metrics
                VStack(alignment: .leading, spacing: 10) {
                    // Beaufort name
                    VStack(alignment: .leading, spacing: 2) {
                        Text(wind.beaufort.name)
                            .font(.headline)
                            .fontWeight(.bold)
                        Text(wind.beaufort.description)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    Divider().background(.white.opacity(0.1))

                    // Speed
                    WindMetricRow(
                        icon: "wind",
                        label: "Speed",
                        value: WeatherFormatters.windSpeed(wind.speed)
                    )

                    // Gusts
                    WindMetricRow(
                        icon: "wind.circle",
                        label: "Gusts",
                        value: WeatherFormatters.windSpeed(wind.gusts)
                    )

                    // Direction
                    WindMetricRow(
                        icon: "location.north.fill",
                        label: "Direction",
                        value: wind.directionDescription
                    )
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }

            // Beaufort scale indicator
            BeaufortScaleBar(current: wind.beaufort)
        }
    }

    private var windArrowGradient: LinearGradient {
        LinearGradient(
            colors: [Color(hex: "60A5FA"), Color(hex: "3B82F6")],
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Wind Arrow Shape

struct WindArrow: Shape {
    func path(in rect: CGRect) -> Path {
        var path = Path()
        let w = rect.width
        let h = rect.height

        // Arrow pointing up
        path.move(to: CGPoint(x: w / 2, y: 0))
        path.addLine(to: CGPoint(x: w, y: h * 0.35))
        path.addLine(to: CGPoint(x: w * 0.65, y: h * 0.25))
        path.addLine(to: CGPoint(x: w * 0.65, y: h))
        path.addLine(to: CGPoint(x: w * 0.35, y: h))
        path.addLine(to: CGPoint(x: w * 0.35, y: h * 0.25))
        path.addLine(to: CGPoint(x: 0, y: h * 0.35))
        path.closeSubpath()

        return path
    }
}

// MARK: - Wind Metric Row

struct WindMetricRow: View {
    let icon: String
    let label: String
    let value: String

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.blue)
                .frame(width: 16)
            VStack(alignment: .leading, spacing: 0) {
                Text(label)
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
        }
    }
}

// MARK: - Beaufort Scale Bar

struct BeaufortScaleBar: View {
    let current: BeaufortScale

    private let colors: [Color] = [
        Color(hex: "34D399"), // 0 calm
        Color(hex: "34D399"), // 1
        Color(hex: "60A5FA"), // 2
        Color(hex: "60A5FA"), // 3
        Color(hex: "FBBF24"), // 4
        Color(hex: "FBBF24"), // 5
        Color(hex: "FB923C"), // 6
        Color(hex: "FB923C"), // 7
        Color(hex: "F87171"), // 8
        Color(hex: "F87171"), // 9
        Color(hex: "A855F7"), // 10
        Color(hex: "A855F7"), // 11
        Color(hex: "EC4899"), // 12
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("Beaufort Scale")
                .font(.caption2)
                .foregroundStyle(.secondary)

            GeometryReader { geo in
                let segmentWidth = geo.size.width / 13

                ZStack(alignment: .leading) {
                    // Scale bars
                    HStack(spacing: 1) {
                        ForEach(0..<13, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(colors[safe: i] ?? .gray)
                                .opacity(i <= current.rawValue ? 1.0 : 0.2)
                        }
                    }
                    .frame(height: 6)

                    // Current indicator
                    Circle()
                        .fill(.white)
                        .frame(width: 10, height: 10)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .offset(x: segmentWidth * CGFloat(current.rawValue) + segmentWidth / 2 - 5)
                }
            }
            .frame(height: 10)

            // Labels
            HStack {
                Text("Calm")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("Force \(current.rawValue)")
                    .font(.system(size: 8, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Hurricane")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}