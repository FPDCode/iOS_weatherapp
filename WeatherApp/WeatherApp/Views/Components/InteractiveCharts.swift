import SwiftUI

/// Reusable interactive line chart with long-press + drag scrubbing.
/// Shows a value tooltip and vertical indicator at the selected point.
struct InteractiveLineChart: View {
    let dataPoints: [ChartDataPoint]
    let lineColor: Color
    let fillColor: Color
    let unit: String
    var dangerThreshold: Double? = nil
    var dangerColor: Color = Color(hex: "F87171")

    @State private var selectedIndex: Int? = nil

    struct ChartDataPoint: Identifiable {
        let id = UUID()
        let time: Date
        let value: Double
    }

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = UnitSettings.shared.selectedTimeFormat == .twentyFour ? "HH:mm" : "h:mma"
        return f
    }()

    var body: some View {
        VStack(spacing: 4) {
            // Selected value display
            HStack {
                if let idx = selectedIndex, idx < dataPoints.count {
                    Text(Self.timeFmt.string(from: dataPoints[idx].time).lowercased())
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Spacer()
                    Text(String(format: "%.1f", dataPoints[idx].value) + " " + unit)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                } else {
                    Spacer()
                }
            }
            .frame(height: 14)

            // Chart
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let values = dataPoints.map(\.value)
                let minVal = (values.min() ?? 0) - (((values.max() ?? 1) - (values.min() ?? 0)) * 0.15)
                let maxVal = (values.max() ?? 1) + (((values.max() ?? 1) - (values.min() ?? 0)) * 0.15)
                let range = max(maxVal - minVal, 0.1)
                let count = max(dataPoints.count - 1, 1)

                ZStack(alignment: .topLeading) {
                    // Danger zone
                    if let threshold = dangerThreshold {
                        let thresholdY = h * (1 - CGFloat((threshold - minVal) / range))
                        if thresholdY > 0 {
                            Rectangle()
                                .fill(dangerColor.opacity(0.06))
                                .frame(height: max(thresholdY, 0))
                        }
                    }

                    // Gradient fill
                    Path { path in
                        for (i, dp) in dataPoints.enumerated() {
                            let x = w * CGFloat(i) / CGFloat(count)
                            let y = h * (1 - CGFloat((dp.value - minVal) / range))
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                        path.addLine(to: CGPoint(x: w, y: h))
                        path.addLine(to: CGPoint(x: 0, y: h))
                        path.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [fillColor.opacity(0.3), fillColor.opacity(0.0)], startPoint: .top, endPoint: .bottom))

                    // Line
                    Path { path in
                        for (i, dp) in dataPoints.enumerated() {
                            let x = w * CGFloat(i) / CGFloat(count)
                            let y = h * (1 - CGFloat((dp.value - minVal) / range))
                            if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                            else { path.addLine(to: CGPoint(x: x, y: y)) }
                        }
                    }
                    .stroke(lineColor, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))

                    // Selected indicator
                    if let idx = selectedIndex, idx < dataPoints.count {
                        let x = w * CGFloat(idx) / CGFloat(count)
                        let y = h * (1 - CGFloat((dataPoints[idx].value - minVal) / range))

                        // Vertical line
                        Path { path in
                            path.move(to: CGPoint(x: x, y: 0))
                            path.addLine(to: CGPoint(x: x, y: h))
                        }
                        .stroke(.white.opacity(0.25), lineWidth: 1)

                        // Dot
                        Circle()
                            .fill(lineColor)
                            .frame(width: 8, height: 8)
                            .position(x: x, y: y)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    LongPressGesture(minimumDuration: 0.15)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onChanged { value in
                            switch value {
                            case .second(true, let drag):
                                if let drag {
                                    let idx = Int(round(drag.location.x / w * CGFloat(count)))
                                    let clamped = max(0, min(dataPoints.count - 1, idx))
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

            // Time labels
            HStack {
                Text("Now")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("+\(dataPoints.count)h")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// Reusable interactive bar chart with scrubbing
struct InteractiveBarChart: View {
    let dataPoints: [BarDataPoint]
    let barColor: Color
    let unit: String

    @State private var selectedIndex: Int? = nil

    struct BarDataPoint: Identifiable {
        let id = UUID()
        let time: Date
        let value: Double
    }

    private static let timeFmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = UnitSettings.shared.selectedTimeFormat == .twentyFour ? "HH:mm" : "h:mma"
        return f
    }()

    var body: some View {
        VStack(spacing: 4) {
            // Selected value display
            HStack {
                if let idx = selectedIndex, idx < dataPoints.count {
                    Text(Self.timeFmt.string(from: dataPoints[idx].time).lowercased())
                        .font(.caption2)
                        .foregroundStyle(.orange)
                    Spacer()
                    Text(String(format: "%.1f", dataPoints[idx].value) + " " + unit)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.orange)
                } else {
                    Spacer()
                }
            }
            .frame(height: 14)

            // Bars
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let count = max(dataPoints.count, 1)
                let barW = (w - CGFloat(count - 1) * 2) / CGFloat(count)
                let maxVal = max(dataPoints.map(\.value).max() ?? 1, 0.1)

                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(Array(dataPoints.enumerated()), id: \.offset) { i, dp in
                        let barH = dp.value > 0.01 ? max(h * CGFloat(dp.value / maxVal), 3) : 2
                        let isSelected = selectedIndex == i
                        RoundedRectangle(cornerRadius: 2)
                            .fill(dp.value > 0.01 ? (isSelected ? barColor : barColor.opacity(0.7)) : Color.gray.opacity(0.2))
                            .frame(width: barW, height: barH)
                    }
                }
                .contentShape(Rectangle())
                .gesture(
                    LongPressGesture(minimumDuration: 0.15)
                        .sequenced(before: DragGesture(minimumDistance: 0))
                        .onChanged { value in
                            switch value {
                            case .second(true, let drag):
                                if let drag {
                                    let idx = Int(drag.location.x / w * CGFloat(count))
                                    let clamped = max(0, min(count - 1, idx))
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

            HStack {
                Text("Now").font(.system(size: 8)).foregroundStyle(.tertiary)
                Spacer()
                Text("+\(dataPoints.count)h").font(.system(size: 8)).foregroundStyle(.tertiary)
            }
        }
    }
}
