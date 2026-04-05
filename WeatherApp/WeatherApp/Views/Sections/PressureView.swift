import SwiftUI

struct PressureView: View {
    let info: PressureInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Air Pressure", icon: "gauge.medium")

            HStack(spacing: 16) {
                // Current pressure
                VStack(spacing: 6) {
                    Image(systemName: "gauge.open.with.lines.needle.33percent")
                        .font(.title)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.blue)

                    Text(WeatherFormatters.pressure(info.currentPressure))
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("Current")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                // Trend
                VStack(spacing: 6) {
                    Image(systemName: info.trend.icon)
                        .font(.title)
                        .foregroundStyle(Color(hex: info.trend.color))

                    Text(info.trend.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(hex: info.trend.color))

                    Text("Next 10 hours")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                // In 10h
                VStack(spacing: 6) {
                    let change = info.pressureIn10h - info.currentPressure
                    let sign = change >= 0 ? "+" : ""

                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text("\(sign)\(String(format: "%.1f", change))")
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("hPa change")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            // Mini pressure chart
            if info.hourlyReadings.count >= 2 {
                Divider().background(.white.opacity(0.1))

                VStack(alignment: .leading, spacing: 6) {
                    Text("12-Hour Trend")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    PressureMiniChart(readings: info.hourlyReadings, trend: info.trend)
                        .frame(height: 50)
                        .padding(.bottom, 14)
                }
            }

            // What it means
            HStack(spacing: 8) {
                Image(systemName: trendMeaningIcon)
                    .font(.caption)
                    .foregroundStyle(Color(hex: info.trend.color))
                Text(trendMeaning)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var trendMeaning: String {
        switch info.trend {
        case .risingFast:
            return "Rapid pressure rise — clearing skies likely, possible strong winds"
        case .rising:
            return "Pressure rising — weather improving, drier conditions ahead"
        case .stable:
            return "Pressure stable — current conditions likely to persist"
        case .falling:
            return "Pressure falling — clouds and rain may develop"
        case .fallingFast:
            return "Rapid pressure drop — stormy conditions possible"
        }
    }

    private var trendMeaningIcon: String {
        switch info.trend {
        case .risingFast, .rising: return "sun.max.fill"
        case .stable: return "equal.circle"
        case .falling: return "cloud.fill"
        case .fallingFast: return "cloud.bolt.rain.fill"
        }
    }
}

// MARK: - Mini Chart

struct PressureMiniChart: View {
    let readings: [(date: Date, pressure: Double)]
    let trend: PressureTrend

    private var pressureRange: (min: Double, max: Double) {
        let values = readings.map(\.pressure)
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 1
        // Add padding so the line doesn't touch edges
        let padding = max((maxVal - minVal) * 0.2, 0.5)
        return (minVal - padding, maxVal + padding)
    }

    /// Indices where we show a time label (every 3 hours, plus first and last)
    private var labelledIndices: [Int] {
        guard readings.count > 1 else { return [0] }
        var indices: [Int] = [0]
        // Every 3 hours
        var next = 3
        while next < readings.count - 1 {
            indices.append(next)
            next += 3
        }
        indices.append(readings.count - 1)
        return indices
    }

    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = UnitSettings.shared.selectedTimeFormat == .twentyFour ? "HH:mm" : "ha"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let height = geo.size.height
            let range = pressureRange
            let totalRange = max(range.max - range.min, 0.1)
            let count = max(readings.count - 1, 1)

            ZStack(alignment: .topLeading) {
                // Horizontal grid lines
                ForEach(0..<3, id: \.self) { i in
                    let y = height * CGFloat(i) / 2
                    Path { path in
                        path.move(to: CGPoint(x: 0, y: y))
                        path.addLine(to: CGPoint(x: width, y: y))
                    }
                    .stroke(.white.opacity(0.06), lineWidth: 1)
                }

                // Vertical grid lines at labelled hours
                ForEach(labelledIndices.filter { $0 > 0 && $0 < readings.count - 1 }, id: \.self) { idx in
                    let x = width * CGFloat(idx) / CGFloat(count)
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    .stroke(.white.opacity(0.06), lineWidth: 1)
                }

                // Gradient fill under the line
                Path { path in
                    for (index, reading) in readings.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(count)
                        let normalized = (reading.pressure - range.min) / totalRange
                        let y = height * (1 - CGFloat(normalized))

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
                .fill(
                    LinearGradient(
                        colors: [Color(hex: trend.color).opacity(0.3), Color(hex: trend.color).opacity(0.0)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )

                // Pressure line
                Path { path in
                    for (index, reading) in readings.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(count)
                        let normalized = (reading.pressure - range.min) / totalRange
                        let y = height * (1 - CGFloat(normalized))

                        if index == 0 {
                            path.move(to: CGPoint(x: x, y: y))
                        } else {
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                    }
                }
                .stroke(
                    Color(hex: trend.color),
                    style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                )

                // Data point dots at labelled hours
                ForEach(labelledIndices, id: \.self) { idx in
                    let x = width * CGFloat(idx) / CGFloat(count)
                    let normalized = (readings[idx].pressure - range.min) / totalRange
                    let y = height * (1 - CGFloat(normalized))
                    Circle()
                        .fill(Color(hex: trend.color))
                        .frame(width: 4, height: 4)
                        .position(x: x, y: y)
                }

                // Time labels along the bottom
                ForEach(labelledIndices, id: \.self) { idx in
                    let x = width * CGFloat(idx) / CGFloat(count)
                    let label = idx == 0 ? "Now" : Self.hourFormatter.string(from: readings[idx].date).lowercased()
                    Text(label)
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                        .position(x: x, y: height + 10)
                }
            }
        }
    }
}
