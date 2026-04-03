import SwiftUI

struct AirQualityView: View {
    let airQuality: AirQualityInfo
    let uvIndex: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Air Quality & UV", icon: "aqi.medium")

            // AQI + UV side by side
            HStack(spacing: 12) {
                // AQI Card
                VStack(spacing: 8) {
                    Image(systemName: airQuality.level.icon)
                        .font(.title2)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color(hex: airQuality.level.color))

                    Text("\(airQuality.aqi)")
                        .font(.title)
                        .fontWeight(.bold)

                    Text("AQI")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(airQuality.level.rawValue)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(hex: airQuality.level.color))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.08))
                )

                // UV Index Card
                VStack(spacing: 8) {
                    Image(systemName: uvIcon)
                        .font(.title2)
                        .symbolRenderingMode(.multicolor)

                    Text(String(format: "%.0f", uvIndex))
                        .font(.title)
                        .fontWeight(.bold)

                    Text("UV Index")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    Text(uvLevel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundStyle(Color(hex: uvColor))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 12)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.08))
                )
            }

            // Particulates
            HStack(spacing: 16) {
                ParticulateLabel(label: "PM2.5", value: airQuality.pm25)
                ParticulateLabel(label: "PM10", value: airQuality.pm10)
            }

            // Pollen
            if let pollen = airQuality.pollenSummary {
                Divider().background(.white.opacity(0.1))

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "leaf.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("Pollen")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                    }

                    HStack(spacing: 16) {
                        PollenPill(type: "Grass", level: pollen.grassLevel)
                        PollenPill(type: "Tree", level: pollen.treeLevel)
                        PollenPill(type: "Weed", level: pollen.weedLevel)
                    }
                }
            }
        }
    }

    private var uvIcon: String {
        if uvIndex >= 8 { return "sun.max.trianglebadge.exclamationmark" }
        if uvIndex >= 3 { return "sun.max.fill" }
        return "sun.min.fill"
    }

    private var uvLevel: String {
        switch uvIndex {
        case ..<3: return "Low"
        case 3..<6: return "Moderate"
        case 6..<8: return "High"
        case 8..<11: return "Very High"
        default: return "Extreme"
        }
    }

    private var uvColor: String {
        switch uvIndex {
        case ..<3: return "34D399"
        case 3..<6: return "FBBF24"
        case 6..<8: return "FB923C"
        case 8..<11: return "F87171"
        default: return "A855F7"
        }
    }
}

struct ParticulateLabel: View {
    let label: String
    let value: Double

    var body: some View {
        HStack(spacing: 6) {
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(String(format: "%.1f", value))
                .font(.caption)
                .fontWeight(.medium)
            Text("µg/m³")
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
        }
    }
}

struct PollenPill: View {
    let type: String
    let level: PollenLevel

    var body: some View {
        VStack(spacing: 3) {
            Text(type)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(level.label)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(Color(hex: level.color))
        }
        .frame(maxWidth: .infinity)
    }
}
