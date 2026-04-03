import SwiftUI

struct ComfortIndexView: View {
    let comfort: ComfortInfo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Comfort Level", icon: "person.fill")

            HStack(spacing: 16) {
                // Comfort icon + level
                VStack(spacing: 6) {
                    Image(systemName: comfort.level.icon)
                        .font(.title)
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(Color(hex: comfort.level.color))

                    Text(comfort.level.rawValue)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundStyle(Color(hex: comfort.level.color))
                }
                .frame(width: 90)

                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 12) {
                        MetricPair(label: "Dew Point", value: WeatherFormatters.temperature(comfort.dewPoint))
                        MetricPair(label: "Humidity", value: "\(comfort.humidity)%")
                    }

                    Text(comfortDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            // Comfort scale
            ComfortScaleBar(level: comfort.level)
        }
    }

    private var comfortDescription: String {
        switch comfort.level {
        case .dry: return "Very dry air — moisturize skin and stay hydrated"
        case .comfortable: return "Comfortable conditions — enjoy the outdoors"
        case .pleasant: return "Pleasant humidity level"
        case .sticky: return "Starting to feel sticky — light clothing recommended"
        case .humid: return "Noticeably humid — take it easy outdoors"
        case .muggy: return "Muggy conditions — limit strenuous activity"
        case .oppressive: return "Oppressive humidity — stay in air conditioning"
        }
    }
}

private struct MetricPair: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(.system(size: 9))
                .foregroundStyle(.tertiary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
    }
}

struct ComfortScaleBar: View {
    let level: ComfortLevel

    private let allLevels: [ComfortLevel] = [.dry, .comfortable, .pleasant, .sticky, .humid, .muggy, .oppressive]

    var body: some View {
        VStack(spacing: 3) {
            GeometryReader { geo in
                let segWidth = geo.size.width / CGFloat(allLevels.count)
                let currentIndex = allLevels.firstIndex(of: level) ?? 0

                ZStack(alignment: .leading) {
                    HStack(spacing: 1) {
                        ForEach(Array(allLevels.enumerated()), id: \.offset) { i, lvl in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(Color(hex: lvl.color))
                                .opacity(i <= currentIndex ? 1.0 : 0.2)
                        }
                    }
                    .frame(height: 5)

                    Circle()
                        .fill(.white)
                        .frame(width: 9, height: 9)
                        .shadow(color: .black.opacity(0.3), radius: 2)
                        .offset(x: segWidth * CGFloat(currentIndex) + segWidth / 2 - 4.5)
                }
            }
            .frame(height: 9)

            HStack {
                Text("Dry")
                    .font(.system(size: 7))
                    .foregroundStyle(.tertiary)
                Spacer()
                Text("Oppressive")
                    .font(.system(size: 7))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}
