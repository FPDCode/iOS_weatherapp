import SwiftUI

struct PrecipTimelineView: View {
    let timeline: PrecipitationTimeline

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Next 2 Hours", icon: "cloud.rain.fill")

            // Status banner
            HStack(spacing: 10) {
                Image(systemName: timeline.isRaining ? "cloud.rain.fill" : "cloud.fill")
                    .font(.title3)
                    .symbolRenderingMode(.multicolor)

                VStack(alignment: .leading, spacing: 2) {
                    if let changeLabel = timeline.nextChangeLabel {
                        Text(changeLabel)
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text(timeline.summary)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // Bar chart
            PrecipBarChart(slots: timeline.slots, maxIntensity: timeline.maxIntensity)
                .frame(height: 80)

            // Time labels
            HStack {
                Text("Now")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("+1h")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("+2h")
                    .font(.system(size: 9))
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 2)

            // Intensity legend
            HStack(spacing: 12) {
                IntensityLegendDot(label: "None", color: PrecipIntensity.none.color)
                IntensityLegendDot(label: "Light", color: PrecipIntensity.light.color)
                IntensityLegendDot(label: "Moderate", color: PrecipIntensity.moderate.color)
                IntensityLegendDot(label: "Heavy", color: PrecipIntensity.heavy.color)
            }
            .frame(maxWidth: .infinity)

            // Snow indicator
            if timeline.slots.contains(where: { $0.snowfall > 0.1 }) {
                HStack(spacing: 6) {
                    Image(systemName: "snowflake")
                        .font(.caption2)
                        .foregroundStyle(.cyan)
                    Text("Snow expected during this period")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

// MARK: - Bar Chart

struct PrecipBarChart: View {
    let slots: [PrecipSlot]
    let maxIntensity: Double

    // Use a sensible max for the bar scale (at least 2mm per 15min for heavy rain)
    private var chartMax: Double {
        max(maxIntensity, 0.5)
    }

    var body: some View {
        GeometryReader { geo in
            let barWidth = (geo.size.width - CGFloat(slots.count - 1) * 3) / CGFloat(max(slots.count, 1))
            let height = geo.size.height

            HStack(alignment: .bottom, spacing: 3) {
                ForEach(slots) { slot in
                    VStack(spacing: 2) {
                        Spacer(minLength: 0)

                        // Chance % label above bar
                        if slot.precipChance > 0 {
                            Text("\(slot.precipChance)%")
                                .font(.system(size: 8, weight: .medium))
                                .foregroundStyle(.cyan.opacity(0.9))
                        }

                        // Rain amount label on top of tall bars
                        if slot.precipitation >= 0.3 {
                            Text(String(format: "%.1f", slot.precipitation))
                                .font(.system(size: 7, weight: .bold))
                                .foregroundStyle(.white.opacity(0.7))
                        }

                        // Bar
                        RoundedRectangle(cornerRadius: 3, style: .continuous)
                            .fill(barGradient(for: slot))
                            .frame(
                                width: barWidth,
                                height: barHeight(for: slot, totalHeight: height)
                            )
                    }
                }
            }
        }
    }

    private func barHeight(for slot: PrecipSlot, totalHeight: CGFloat) -> CGFloat {
        if slot.precipitation < 0.05 {
            return 4 // Minimum visible bar for "no rain"
        }
        let ratio = slot.precipitation / chartMax
        return max(CGFloat(ratio) * (totalHeight - 20), 8) // Reserve space for labels
    }

    private func barGradient(for slot: PrecipSlot) -> LinearGradient {
        if slot.precipitation < 0.05 {
            return LinearGradient(
                colors: [Color(hex: PrecipIntensity.none.color).opacity(0.3)],
                startPoint: .bottom,
                endPoint: .top
            )
        }

        let baseColor = Color(hex: slot.intensity.color)

        // Snow gets a different gradient
        if slot.snowfall > slot.rain {
            return LinearGradient(
                colors: [Color.cyan.opacity(0.6), Color.white.opacity(0.8)],
                startPoint: .bottom,
                endPoint: .top
            )
        }

        return LinearGradient(
            colors: [baseColor.opacity(0.5), baseColor],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}

// MARK: - Legend

struct IntensityLegendDot: View {
    let label: String
    let color: String

    var body: some View {
        HStack(spacing: 4) {
            Circle()
                .fill(Color(hex: color))
                .frame(width: 6, height: 6)
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.secondary)
        }
    }
}
