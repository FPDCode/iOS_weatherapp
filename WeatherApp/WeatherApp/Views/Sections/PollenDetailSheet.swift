import SwiftUI

struct PollenDetailSheet: View {
    let airQuality: AirQualityInfo

    @Environment(\.dismiss) private var dismiss

    private var pollen: PollenSummary? { airQuality.pollenSummary }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Overall level
                    overallSection

                    // Breakdown by type
                    breakdownSection

                    // Tips
                    tipsSection

                    // About
                    aboutSection
                }
                .padding(16)
            }
            .background(Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("Pollen")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }

    // MARK: - Overall Level

    private var overallSection: some View {
        VStack(spacing: 12) {
            if let pollen {
                // Large overall indicator
                ZStack {
                    Circle()
                        .fill(Color(hex: pollen.overallLevel.color).opacity(0.15))
                        .frame(width: 100, height: 100)

                    VStack(spacing: 4) {
                        Image(systemName: "leaf.fill")
                            .font(.title)
                            .foregroundStyle(Color(hex: pollen.overallLevel.color))
                        Text(pollen.overallLevel.label)
                            .font(.subheadline)
                            .fontWeight(.bold)
                            .foregroundStyle(Color(hex: pollen.overallLevel.color))
                    }
                }

                // Level scale
                PollenLevelScale(currentLevel: pollen.overallLevel)
            } else {
                Text("No pollen data available")
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.05)))
    }

    // MARK: - Breakdown

    private var breakdownSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "chart.bar.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("POLLEN BREAKDOWN")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }

            if let pollen {
                PollenTypeRow(name: "Grass", icon: "leaf.fill", level: pollen.grassLevel, description: "Grasses, lawns, meadows")
                Divider().background(.white.opacity(0.1))
                PollenTypeRow(name: "Trees", icon: "tree.fill", level: pollen.treeLevel, description: "Birch, alder, olive")
                Divider().background(.white.opacity(0.1))
                PollenTypeRow(name: "Weeds", icon: "sparkles", level: pollen.weedLevel, description: "Ragweed, mugwort")
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.05)))
    }

    // MARK: - Tips

    private var tipsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 6) {
                Image(systemName: "heart.text.square.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("TIPS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }

            let tips = tipsForLevel(pollen?.overallLevel ?? .none)
            ForEach(Array(tips.enumerated()), id: \.offset) { _, tip in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: tip.icon)
                        .font(.body)
                        .foregroundStyle(Color(hex: tip.color))
                        .frame(width: 24)

                    VStack(alignment: .leading, spacing: 2) {
                        Text(tip.title)
                            .font(.subheadline)
                            .fontWeight(.medium)
                        Text(tip.message)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(.vertical, 2)
            }
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.05)))
    }

    // MARK: - About

    private var aboutSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "info.circle.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("ABOUT POLLEN LEVELS")
                    .font(.caption)
                    .fontWeight(.bold)
                    .foregroundStyle(.secondary)
                    .tracking(1)
            }

            Text("Pollen levels are measured in grains per cubic meter (grains/m³). Data is sourced from the Open-Meteo Air Quality API, covering grass, tree (birch, alder, olive), and weed (ragweed, mugwort) pollen types.")
                .font(.caption)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 4) {
                pollenLevelLegend("None", "< 1 grains/m³", "34D399")
                pollenLevelLegend("Low", "1–25 grains/m³", "60A5FA")
                pollenLevelLegend("Moderate", "25–50 grains/m³", "FBBF24")
                pollenLevelLegend("High", "50–100 grains/m³", "FB923C")
                pollenLevelLegend("Very High", "> 100 grains/m³", "F87171")
            }
            .padding(.top, 4)
        }
        .padding(16)
        .background(RoundedRectangle(cornerRadius: 16, style: .continuous).fill(.white.opacity(0.05)))
    }

    private func pollenLevelLegend(_ name: String, _ range: String, _ color: String) -> some View {
        HStack(spacing: 8) {
            Circle()
                .fill(Color(hex: color))
                .frame(width: 8, height: 8)
            Text(name)
                .font(.caption)
                .fontWeight(.medium)
                .frame(width: 70, alignment: .leading)
            Text(range)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Tips Data

    private struct Tip {
        let icon: String
        let color: String
        let title: String
        let message: String
    }

    private func tipsForLevel(_ level: PollenLevel) -> [Tip] {
        switch level {
        case .none, .low:
            return [
                Tip(icon: "checkmark.circle.fill", color: "34D399", title: "Low risk", message: "Enjoy outdoor activities — pollen levels are minimal."),
            ]
        case .moderate:
            return [
                Tip(icon: "eye.fill", color: "FBBF24", title: "Monitor symptoms", message: "If you're sensitive to pollen, keep medication handy."),
                Tip(icon: "wind", color: "60A5FA", title: "Check wind", message: "Windy days can spread pollen further."),
            ]
        case .high:
            return [
                Tip(icon: "pills.fill", color: "FB923C", title: "Take antihistamines", message: "Start medication before symptoms appear for best effect."),
                Tip(icon: "window.horizontal.closed", color: "FB923C", title: "Keep windows closed", message: "Reduce indoor pollen by keeping windows shut."),
                Tip(icon: "tshirt.fill", color: "60A5FA", title: "Change clothes", message: "Change after being outdoors to remove pollen from clothing."),
            ]
        case .veryHigh:
            return [
                Tip(icon: "exclamationmark.triangle.fill", color: "F87171", title: "Limit outdoor time", message: "Stay indoors during peak hours (10 AM – 4 PM)."),
                Tip(icon: "pills.fill", color: "F87171", title: "Take antihistamines", message: "Essential for allergy sufferers — take before going out."),
                Tip(icon: "window.horizontal.closed", color: "FB923C", title: "Keep windows closed", message: "Use air conditioning instead of opening windows."),
                Tip(icon: "washer.fill", color: "60A5FA", title: "Shower after outdoors", message: "Wash hair and skin to remove pollen after being outside."),
                Tip(icon: "car.fill", color: "60A5FA", title: "Car windows up", message: "Keep car windows closed and use recirculated air."),
            ]
        }
    }
}

// MARK: - Pollen Type Row

private struct PollenTypeRow: View {
    let name: String
    let icon: String
    let level: PollenLevel
    let description: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(Color(hex: level.color))
                .frame(width: 30)

            VStack(alignment: .leading, spacing: 2) {
                Text(name)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(description)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            Text(level.label)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundStyle(Color(hex: level.color))
                .padding(.horizontal, 10)
                .padding(.vertical, 4)
                .background(Capsule().fill(Color(hex: level.color).opacity(0.15)))
        }
    }
}

// MARK: - Pollen Level Scale

private struct PollenLevelScale: View {
    let currentLevel: PollenLevel
    private let allLevels: [PollenLevel] = [.none, .low, .moderate, .high, .veryHigh]

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geo in
                let segWidth = geo.size.width / CGFloat(allLevels.count)
                let currentIndex = allLevels.firstIndex(of: currentLevel) ?? 0

                ZStack(alignment: .leading) {
                    HStack(spacing: 2) {
                        ForEach(Array(allLevels.enumerated()), id: \.offset) { i, level in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(Color(hex: level.color))
                                .opacity(i <= currentIndex ? 1.0 : 0.2)
                        }
                    }
                    .frame(height: 6)

                    Circle()
                        .fill(.white)
                        .frame(width: 10, height: 10)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .offset(x: segWidth * CGFloat(currentIndex) + segWidth / 2 - 5)
                }
            }
            .frame(height: 10)

            HStack {
                Text("None")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("Very High")
                    .font(.system(size: 8))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
