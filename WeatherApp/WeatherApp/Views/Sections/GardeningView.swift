import SwiftUI

struct GardeningView: View {
    let info: GardeningInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Garden & Soil", icon: "leaf.fill")

            HStack(spacing: 16) {
                // Soil temp
                VStack(spacing: 4) {
                    Image(systemName: info.frostRisk ? "thermometer.snowflake" : "thermometer.sun.fill")
                        .font(.title2)
                        .symbolRenderingMode(.multicolor)

                    Text(WeatherFormatters.temperature(info.soilTemp))
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("Soil Temp")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(info.frostRisk ? .blue.opacity(0.1) : .white.opacity(0.05))
                )

                // Soil moisture
                VStack(spacing: 4) {
                    Image(systemName: moistureIcon)
                        .font(.title2)
                        .foregroundStyle(moistureColor)

                    Text(String(format: "%.0f%%", info.soilMoisture))
                        .font(.title3)
                        .fontWeight(.bold)

                    Text("Moisture")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 12, style: .continuous)
                        .fill(.white.opacity(0.05))
                )
            }

            // Frost alert
            if info.frostRisk {
                HStack(spacing: 8) {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(.blue)
                    Text("Frost risk — protect sensitive plants tonight")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }

            Divider().background(.white.opacity(0.1))

            // Advice
            HStack(spacing: 10) {
                Image(systemName: "drop.fill")
                    .font(.caption)
                    .foregroundStyle(.cyan)
                    .frame(width: 20)
                Text(info.wateringAdvice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 10) {
                Image(systemName: "leaf.fill")
                    .font(.caption)
                    .foregroundStyle(.green)
                    .frame(width: 20)
                Text(info.plantingAdvice)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var moistureIcon: String {
        if info.soilMoisture > 40 { return "drop.fill" }
        if info.soilMoisture > 15 { return "drop.halffull" }
        return "drop"
    }

    private var moistureColor: Color {
        if info.soilMoisture > 40 { return .cyan }
        if info.soilMoisture > 15 { return .blue }
        return .orange
    }
}
