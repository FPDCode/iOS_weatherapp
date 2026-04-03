import SwiftUI

struct SunshinePlannerView: View {
    let plan: SunshinePlan

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Sunshine Planner", icon: "sun.max.fill")

            // Summary
            HStack(spacing: 12) {
                // Sunshine donut
                ZStack {
                    Circle()
                        .stroke(.white.opacity(0.1), lineWidth: 6)
                        .frame(width: 64, height: 64)

                    Circle()
                        .trim(from: 0, to: CGFloat(min(plan.sunshinePercent / 100, 1)))
                        .stroke(
                            LinearGradient(
                                colors: [.yellow, .orange],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            style: StrokeStyle(lineWidth: 6, lineCap: .round)
                        )
                        .frame(width: 64, height: 64)
                        .rotationEffect(.degrees(-90))

                    VStack(spacing: 0) {
                        Text("\(Int(plan.sunshinePercent))%")
                            .font(.system(size: 14, weight: .bold))
                        Text("sunny")
                            .font(.system(size: 8))
                            .foregroundStyle(.secondary)
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(plan.summary)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    HStack(spacing: 12) {
                        Label(formatDuration(plan.todaySunshineDuration), systemImage: "sun.max.fill")
                            .font(.caption)
                            .foregroundStyle(.yellow)
                        Label(formatDuration(plan.todayDaylightDuration), systemImage: "sun.horizon.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            // Best window
            if let window = plan.bestWindow {
                HStack(spacing: 8) {
                    Image(systemName: "star.fill")
                        .font(.caption)
                        .foregroundStyle(.yellow)
                    Text("Best sunshine: \(WeatherFormatters.shortTime(window.start)) – \(WeatherFormatters.shortTime(window.end))")
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(
                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                        .fill(.yellow.opacity(0.1))
                )
            }

            // Hourly sunshine timeline
            if !plan.slots.isEmpty {
                SunshineTimeline(slots: plan.slots)
                    .frame(height: 60)
            }
        }
    }

    private func formatDuration(_ seconds: Double) -> String {
        let hours = Int(seconds) / 3600
        let minutes = (Int(seconds) % 3600) / 60
        return "\(hours)h \(minutes)m"
    }
}

// MARK: - Sunshine Timeline

struct SunshineTimeline: View {
    let slots: [SunshineSlot]

    var body: some View {
        VStack(spacing: 4) {
            // Cloud cover bars (inverted: less cloud = taller yellow bar)
            GeometryReader { geo in
                let barWidth = (geo.size.width - CGFloat(max(slots.count - 1, 0)) * 2) / CGFloat(max(slots.count, 1))
                let height = geo.size.height

                HStack(alignment: .bottom, spacing: 2) {
                    ForEach(slots) { slot in
                        let sunPercent = Double(100 - slot.cloudCover) / 100.0

                        VStack(spacing: 0) {
                            Spacer(minLength: 0)
                            RoundedRectangle(cornerRadius: 2, style: .continuous)
                                .fill(barColor(for: slot))
                                .frame(width: barWidth, height: max(CGFloat(sunPercent) * height, 3))
                        }
                    }
                }
            }

            // Time labels
            HStack {
                if let first = slots.first {
                    Text(WeatherFormatters.hourTime(first.time))
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                Text("Noon")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Spacer()
                if let last = slots.last {
                    Text(WeatherFormatters.hourTime(last.time))
                        .font(.system(size: 8))
                        .foregroundStyle(.tertiary)
                }
            }
        }
    }

    private func barColor(for slot: SunshineSlot) -> LinearGradient {
        if slot.isSunny {
            return LinearGradient(
                colors: [.yellow.opacity(0.5), .yellow],
                startPoint: .bottom,
                endPoint: .top
            )
        }
        let cloudPercent = Double(slot.cloudCover) / 100
        return LinearGradient(
            colors: [.gray.opacity(0.2), .gray.opacity(0.1 + cloudPercent * 0.3)],
            startPoint: .bottom,
            endPoint: .top
        )
    }
}
