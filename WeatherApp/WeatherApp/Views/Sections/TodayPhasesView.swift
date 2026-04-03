import SwiftUI

struct TodayPhasesView: View {
    let phases: [DayPhaseWeather]
    let isDay: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Today's Forecast", icon: "clock.fill")

            HStack(spacing: 10) {
                ForEach(phases) { phase in
                    PhaseCard(phase: phase, isDay: isDay)
                }
            }
        }
    }
}

struct PhaseCard: View {
    let phase: DayPhaseWeather
    let isDay: Bool

    private var isCurrentPhase: Bool {
        let hour = Calendar.current.component(.hour, from: Date())
        switch phase.phase {
        case .morning: return (6...11).contains(hour)
        case .afternoon: return (12...17).contains(hour)
        case .evening: return (18...21).contains(hour)
        case .night: return hour >= 22 || hour < 6
        }
    }

    var body: some View {
        VStack(spacing: 8) {
            Text(phase.phase.rawValue)
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundStyle(isCurrentPhase ? .primary : .secondary)

            Image(systemName: WeatherCodeInfo.sfSymbol(for: phase.weatherCode, isDay: phase.phase != .night))
                .font(.title2)
                .symbolRenderingMode(.multicolor)

            Text(WeatherFormatters.temperature(phase.temperature))
                .font(.title3)
                .fontWeight(.semibold)

            VStack(spacing: 2) {
                Label {
                    Text(WeatherFormatters.temperature(phase.feelsLike))
                        .font(.caption2)
                } icon: {
                    Image(systemName: "thermometer.medium")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)

                if phase.precipChance > 0 {
                    Label {
                        Text(WeatherFormatters.percent(phase.precipChance))
                            .font(.caption2)
                    } icon: {
                        Image(systemName: "drop.fill")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .background(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .fill(isCurrentPhase ? .white.opacity(0.15) : .clear)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14, style: .continuous)
                .stroke(isCurrentPhase ? .white.opacity(0.3) : .clear, lineWidth: 1)
        )
    }
}
