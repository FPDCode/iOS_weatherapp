import SwiftUI

struct PressureView: View {
    let info: PressureInfo
    @State private var selectedIndex: Int? = nil
    @State private var timeRange: PressureTimeRange = .twelve

    private var filteredReadings: [(date: Date, pressure: Double)] {
        Array(info.hourlyReadings.prefix(timeRange.hours))
    }

    /// The reading to display in the metrics area (selected or current)
    private var displayPressure: Double {
        if let idx = selectedIndex, idx < info.hourlyReadings.count {
            return info.hourlyReadings[idx].pressure
        }
        return info.currentPressure
    }

    private var displayChange: Double {
        if let idx = selectedIndex, idx < info.hourlyReadings.count {
            return info.hourlyReadings[idx].pressure - info.currentPressure
        }
        return info.pressureIn10h - info.currentPressure
    }

    private var displayLabel: String {
        if let idx = selectedIndex, idx < info.hourlyReadings.count {
            return WeatherFormatters.shortTime(info.hourlyReadings[idx].date)
        }
        return "Current"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with time indicator
            HStack {
                SectionHeader(title: "Air Pressure", icon: "gauge.medium")
                Spacer()
                if selectedIndex != nil {
                    Text(displayLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                        .transition(.opacity)
                } else {
                    Menu {
                        ForEach(PressureTimeRange.allCases) { range in
                            Button {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    timeRange = range
                                    selectedIndex = nil
                                }
                            } label: {
                                Label(range.label, systemImage: timeRange == range ? "checkmark" : "clock")
                            }
                        }
                    } label: {
                        Text(timeRange.label)
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(Capsule().fill(.white.opacity(0.08)))
                    }
                }
            }
            .animation(.easeInOut(duration: 0.15), value: selectedIndex)

            HStack(spacing: 16) {
                // Pressure value
                VStack(spacing: 6) {
                    Image(systemName: "gauge.open.with.lines.needle.33percent")
                        .font(.title)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.blue)

                    Text(WeatherFormatters.pressure(displayPressure))
                        .font(.title3)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())

                    Text(displayLabel)
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

                // Change
                VStack(spacing: 6) {
                    let change = displayChange
                    let sign = change >= 0 ? "+" : ""

                    Image(systemName: change >= 0 ? "arrow.up.right" : "arrow.down.right")
                        .font(.title2)
                        .foregroundStyle(.secondary)

                    Text("\(sign)\(String(format: "%.1f", change))")
                        .font(.title3)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())

                    Text(selectedIndex != nil ? "vs now" : "hPa change")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }

            // Interactive pressure chart
            if filteredReadings.count >= 2 {
                Divider().background(.white.opacity(0.1))

                InteractivePressureChart(
                    readings: filteredReadings,
                    trend: info.trend,
                    selectedIndex: $selectedIndex,
                    timeRange: timeRange
                )
                .frame(height: 70)
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
        case .risingFast: return "Rapid pressure rise — clearing skies likely, possible strong winds"
        case .rising: return "Pressure rising — weather improving, drier conditions ahead"
        case .stable: return "Pressure stable — current conditions likely to persist"
        case .falling: return "Pressure falling — clouds and rain may develop"
        case .fallingFast: return "Rapid pressure drop — stormy conditions possible"
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

// MARK: - Interactive Pressure Chart

private struct InteractivePressureChart: View {
    let readings: [(date: Date, pressure: Double)]
    let trend: PressureTrend
    @Binding var selectedIndex: Int?
    var timeRange: PressureTimeRange = .twelve

    private var pressureRange: (min: Double, max: Double) {
        let values = readings.map(\.pressure)
        let minVal = values.min() ?? 0
        let maxVal = values.max() ?? 1
        let padding = max((maxVal - minVal) * 0.2, 0.5)
        return (minVal - padding, maxVal + padding)
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
            let height = geo.size.height - 16 // Reserve space for time labels
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

                // Gradient fill
                Path { path in
                    for (index, reading) in readings.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(count)
                        let normalized = (reading.pressure - range.min) / totalRange
                        let y = height * (1 - CGFloat(normalized))
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                    path.addLine(to: CGPoint(x: width, y: height))
                    path.addLine(to: CGPoint(x: 0, y: height))
                    path.closeSubpath()
                }
                .fill(LinearGradient(
                    colors: [Color(hex: trend.color).opacity(0.3), Color(hex: trend.color).opacity(0.0)],
                    startPoint: .top, endPoint: .bottom
                ))

                // Pressure line
                Path { path in
                    for (index, reading) in readings.enumerated() {
                        let x = width * CGFloat(index) / CGFloat(count)
                        let normalized = (reading.pressure - range.min) / totalRange
                        let y = height * (1 - CGFloat(normalized))
                        if index == 0 { path.move(to: CGPoint(x: x, y: y)) }
                        else { path.addLine(to: CGPoint(x: x, y: y)) }
                    }
                }
                .stroke(Color(hex: trend.color), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                // Selected indicator
                if let idx = selectedIndex, idx < readings.count {
                    let x = width * CGFloat(idx) / CGFloat(count)
                    let normalized = (readings[idx].pressure - range.min) / totalRange
                    let y = height * (1 - CGFloat(normalized))

                    // Vertical line
                    Path { path in
                        path.move(to: CGPoint(x: x, y: 0))
                        path.addLine(to: CGPoint(x: x, y: height))
                    }
                    .stroke(.white.opacity(0.3), lineWidth: 1)

                    // Dot
                    Circle()
                        .fill(Color(hex: trend.color))
                        .frame(width: 8, height: 8)
                        .position(x: x, y: y)

                    // Value label
                    Text(WeatherFormatters.pressure(readings[idx].pressure))
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Capsule().fill(Color(hex: trend.color).opacity(0.8)))
                        .position(x: min(max(x, 35), width - 35), y: max(y - 14, 10))
                }

                // Time labels
                HStack {
                    Text("Now")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text("+\(timeRange.hours)h")
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
                .offset(y: height + 4)
            }
            // Long press + drag gesture
            .contentShape(Rectangle())
            .gesture(
                LongPressGesture(minimumDuration: 0.15)
                    .sequenced(before: DragGesture(minimumDistance: 0))
                    .onChanged { value in
                        switch value {
                        case .second(true, let drag):
                            if let drag {
                                let idx = Int(round(drag.location.x / width * CGFloat(count)))
                                let clamped = max(0, min(readings.count - 1, idx))
                                if clamped != selectedIndex {
                                    UIImpactFeedbackGenerator(style: .light).impactOccurred()
                                    selectedIndex = clamped
                                }
                            }
                        default: break
                        }
                    }
                    .onEnded { _ in
                        selectedIndex = nil
                    }
            )
        }
    }
}

// MARK: - Time Range

enum PressureTimeRange: String, CaseIterable, Identifiable {
    case six = "6h"
    case twelve = "12h"

    var id: String { rawValue }

    var hours: Int {
        switch self {
        case .six: return 6
        case .twelve: return 12
        }
    }

    var label: String {
        "Next \(rawValue)"
    }
}
