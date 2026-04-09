import SwiftUI

struct CloudCoverView: View {
    let info: CloudCoverInfo
    let stormRisk: StormRiskInfo?
    @State private var selectedIndex: Int? = nil
    @State private var timeRange: CloudTimeRange = .twelve

    private var filteredReadings: [(date: Date, total: Int, low: Int, mid: Int, high: Int)] {
        Array(info.hourlyReadings.prefix(timeRange.hours))
    }

    /// The reading to display in the metrics area
    private var displayTotal: Int {
        if let idx = selectedIndex, idx < info.hourlyReadings.count {
            return info.hourlyReadings[idx].total
        }
        return info.total
    }

    private var displayHigh: Int {
        if let idx = selectedIndex, idx < info.hourlyReadings.count {
            return info.hourlyReadings[idx].high
        }
        return info.high
    }

    private var displayMid: Int {
        if let idx = selectedIndex, idx < info.hourlyReadings.count {
            return info.hourlyReadings[idx].mid
        }
        return info.mid
    }

    private var displayLow: Int {
        if let idx = selectedIndex, idx < info.hourlyReadings.count {
            return info.hourlyReadings[idx].low
        }
        return info.low
    }

    private var displayLabel: String {
        if let idx = selectedIndex, idx < info.hourlyReadings.count {
            return WeatherFormatters.shortTime(info.hourlyReadings[idx].date)
        }
        return "Now"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with time indicator
            HStack {
                SectionHeader(title: "Cloud Cover", icon: "cloud.fill")
                Spacer()
                if selectedIndex != nil {
                    Text(displayLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(.orange)
                        .transition(.opacity)
                } else {
                    Menu {
                        ForEach(CloudTimeRange.allCases) { range in
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
                // Cloud percentage
                VStack(spacing: 4) {
                    Text("\(displayTotal)%")
                        .font(.title2)
                        .fontWeight(.bold)
                        .contentTransition(.numericText())
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                    Text(selectedIndex != nil ? displayLabel : "Coverage")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 60)

                // Cloud layers
                VStack(alignment: .leading, spacing: 6) {
                    CloudLayer(label: "High", value: displayHigh, color: "90CAF9")
                    CloudLayer(label: "Mid", value: displayMid, color: "78909C")
                    CloudLayer(label: "Low", value: displayLow, color: "546E7A")
                }
                .frame(maxWidth: .infinity)
            }

            // Interactive cloud timeline
            if filteredReadings.count >= 4 {
                Divider().background(.white.opacity(0.1))
                InteractiveCloudTimeline(
                    readings: filteredReadings,
                    selectedIndex: $selectedIndex,
                    timeRange: timeRange
                )
            }

            // Storm risk
            if let storm = stormRisk, storm.level != .none {
                Divider().background(.white.opacity(0.1))

                HStack(spacing: 10) {
                    Image(systemName: storm.level.icon)
                        .font(.body)
                        .symbolRenderingMode(.multicolor)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("Thunderstorm Risk: \(storm.level.rawValue)")
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .foregroundStyle(Color(hex: storm.level.color))
                        Text("CAPE: \(Int(storm.cape)) J/kg")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

struct CloudLayer: View {
    let label: String
    let value: Int
    let color: String

    var body: some View {
        HStack(spacing: 8) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(.white.opacity(0.08))
                        .frame(height: 8)

                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(hex: color))
                        .frame(width: max(geo.size.width * CGFloat(value) / 100, 2), height: 8)
                        .animation(.easeInOut(duration: 0.15), value: value)
                }
            }
            .frame(height: 8)

            Text("\(value)%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Interactive Cloud Timeline

private struct InteractiveCloudTimeline: View {
    let readings: [(date: Date, total: Int, low: Int, mid: Int, high: Int)]
    @Binding var selectedIndex: Int?
    var timeRange: CloudTimeRange = .twelve

    var body: some View {
        VStack(spacing: 10) {
            InteractiveCloudLayerChart(label: "High", values: readings.map(\.high), color: "90CAF9", readings: readings, selectedIndex: $selectedIndex)
            InteractiveCloudLayerChart(label: "Mid", values: readings.map(\.mid), color: "78909C", readings: readings, selectedIndex: $selectedIndex)
            InteractiveCloudLayerChart(label: "Low", values: readings.map(\.low), color: "546E7A", readings: readings, selectedIndex: $selectedIndex)

            // Time labels
            HStack {
                Text("Now")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("+\(timeRange.hours / 2)h")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("+\(timeRange.hours)h")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
        // Single gesture covering all 3 charts
        .contentShape(Rectangle())
        .gesture(
            LongPressGesture(minimumDuration: 0.15)
                .sequenced(before: DragGesture(minimumDistance: 0))
                .onChanged { value in
                    switch value {
                    case .second(true, let drag):
                        if let drag {
                            // Use the full timeline width
                            let fraction = drag.location.x / UIScreen.main.bounds.width
                            let idx = Int(round(fraction * CGFloat(readings.count - 1)))
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

private struct InteractiveCloudLayerChart: View {
    let label: String
    let values: [Int]
    let color: String
    let readings: [(date: Date, total: Int, low: Int, mid: Int, high: Int)]
    @Binding var selectedIndex: Int?

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .leading)

            GeometryReader { geo in
                let width = geo.size.width
                let height = geo.size.height

                ZStack {
                    // Area fill
                    Path { path in
                        guard values.count >= 2 else { return }
                        let step = width / CGFloat(values.count - 1)
                        path.move(to: CGPoint(x: 0, y: height))
                        for (i, val) in values.enumerated() {
                            let x = step * CGFloat(i)
                            let y = height * (1 - CGFloat(val) / 100)
                            path.addLine(to: CGPoint(x: x, y: y))
                        }
                        path.addLine(to: CGPoint(x: width, y: height))
                        path.closeSubpath()
                    }
                    .fill(Color(hex: color).opacity(0.25))

                    // Line
                    Path { path in
                        guard values.count >= 2 else { return }
                        let step = width / CGFloat(values.count - 1)
                        for (i, val) in values.enumerated() {
                            let x = step * CGFloat(i)
                            let y = height * (1 - CGFloat(val) / 100)
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(Color(hex: color).opacity(0.7), lineWidth: 1.5)

                    // Selected indicator line
                    if let idx = selectedIndex, idx < values.count {
                        let step = width / CGFloat(max(values.count - 1, 1))
                        let x = step * CGFloat(idx)
                        let y = height * (1 - CGFloat(values[idx]) / 100)

                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: height))
                        }
                        .stroke(.white.opacity(0.3), lineWidth: 1)

                        Circle()
                            .fill(Color(hex: color))
                            .frame(width: 6, height: 6)
                            .position(x: x, y: y)
                    }
                }
            }
            .frame(height: 28)

            // Show selected or current value
            Text("\(selectedIndex != nil && selectedIndex! < values.count ? values[selectedIndex!] : (values.first ?? 0))%")
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
                .frame(width: 30, alignment: .trailing)
                .contentTransition(.numericText())
        }
    }
}

// MARK: - Time Range

enum CloudTimeRange: String, CaseIterable, Identifiable {
    case six = "6h"
    case twelve = "12h"
    case twentyFour = "24h"

    var id: String { rawValue }

    var hours: Int {
        switch self {
        case .six: return 6
        case .twelve: return 12
        case .twentyFour: return 24
        }
    }

    var label: String {
        "Next \(rawValue)"
    }
}
