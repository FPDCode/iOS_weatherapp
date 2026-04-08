import SwiftUI

struct CloudCoverView: View {
    let info: CloudCoverInfo
    let stormRisk: StormRiskInfo?

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Cloud Cover", icon: "cloud.fill")

            HStack(spacing: 16) {
                // Cloud percentage
                VStack(spacing: 4) {
                    Text("\(info.total)%")
                        .font(.title)
                        .fontWeight(.bold)
                    Text("Coverage")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(width: 70)

                // Cloud layers
                VStack(alignment: .leading, spacing: 6) {
                    CloudLayer(label: "High", value: info.high, color: "90CAF9")
                    CloudLayer(label: "Mid", value: info.mid, color: "78909C")
                    CloudLayer(label: "Low", value: info.low, color: "546E7A")
                }
                .frame(maxWidth: .infinity)
            }

            // 24h cloud timeline
            if info.hourlyReadings.count >= 4 {
                Divider().background(.white.opacity(0.1))
                CloudTimeline(readings: info.hourlyReadings)
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
                }
            }
            .frame(height: 8)

            Text("\(value)%")
                .font(.caption2)
                .foregroundStyle(.secondary)
                .frame(width: 32, alignment: .trailing)
        }
    }
}

struct CloudTimeline: View {
    let readings: [(date: Date, total: Int, low: Int, mid: Int, high: Int)]

    var body: some View {
        VStack(spacing: 10) {
            CloudLayerChart(label: "High", values: readings.map(\.high), color: "90CAF9")
            CloudLayerChart(label: "Mid", values: readings.map(\.mid), color: "78909C")
            CloudLayerChart(label: "Low", values: readings.map(\.low), color: "546E7A")

            // Time labels
            HStack {
                Text("Now")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("+12h")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("+24h")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

private struct CloudLayerChart: View {
    let label: String
    let values: [Int]
    let color: String

    var body: some View {
        VStack(spacing: 2) {
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
                    }
                }
                .frame(height: 28)

                Text("\(values.first ?? 0)%")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, alignment: .trailing)
            }
        }
    }
}
