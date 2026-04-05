import ActivityKit
import SwiftUI
import WidgetKit

struct RainActivityLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: RainActivityAttributes.self) { context in
            // MARK: - Lock Screen Banner
            lockScreenView(context: context)
                .activityBackgroundTint(.black.opacity(0.7))
                .activitySystemActionForegroundColor(.white)

        } dynamicIsland: { context in
            DynamicIsland {
                // MARK: - Expanded Dynamic Island
                DynamicIslandExpandedRegion(.leading) {
                    Image(systemName: context.state.isRaining ? "cloud.rain.fill" : "cloud.drizzle.fill")
                        .font(.title2)
                        .symbolRenderingMode(.multicolor)
                }

                DynamicIslandExpandedRegion(.trailing) {
                    VStack(alignment: .trailing, spacing: 2) {
                        Text(context.state.nextChangeLabel)
                            .font(.caption)
                            .fontWeight(.semibold)
                        Text(context.state.locationName)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                DynamicIslandExpandedRegion(.bottom) {
                    VStack(spacing: 6) {
                        // Mini precipitation bar
                        rainBars(slots: context.state.slots)
                            .frame(height: 24)

                        // Time labels
                        HStack {
                            Text("Now")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Spacer()
                            Text("+2h")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 4)
                }

                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.summary)
                        .font(.caption)
                        .lineLimit(1)
                }

            } compactLeading: {
                Image(systemName: context.state.isRaining ? "cloud.rain.fill" : "cloud.drizzle.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.caption)

            } compactTrailing: {
                Text(context.state.nextChangeLabel)
                    .font(.system(size: 10))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)

            } minimal: {
                Image(systemName: "cloud.rain.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.caption)
            }
        }
    }

    // MARK: - Lock Screen View

    @ViewBuilder
    private func lockScreenView(context: ActivityViewContext<RainActivityAttributes>) -> some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: context.state.isRaining ? "cloud.rain.fill" : "cloud.drizzle.fill")
                    .symbolRenderingMode(.multicolor)
                    .font(.title3)

                VStack(alignment: .leading, spacing: 1) {
                    Text(context.state.summary)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Text(context.state.nextChangeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Text(context.state.locationName)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }

            // Rain intensity bars
            rainBars(slots: context.state.slots)
                .frame(height: 20)

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
        }
        .padding(16)
    }

    // MARK: - Rain Bars

    @ViewBuilder
    private func rainBars(slots: [RainActivityAttributes.RainSlot]) -> some View {
        GeometryReader { geo in
            let barCount = max(slots.count, 1)
            let spacing: CGFloat = 2
            let barWidth = (geo.size.width - spacing * CGFloat(barCount - 1)) / CGFloat(barCount)
            let maxPrecip = max(slots.map(\.precipitation).max() ?? 1, 0.5)

            HStack(spacing: spacing) {
                ForEach(Array(slots.enumerated()), id: \.offset) { _, slot in
                    let height = slot.precipitation < 0.1
                        ? geo.size.height * 0.08
                        : geo.size.height * CGFloat(slot.precipitation / maxPrecip)

                    RoundedRectangle(cornerRadius: 2)
                        .fill(colorForIntensity(slot.intensity))
                        .frame(width: barWidth, height: max(height, 2))
                        .frame(maxHeight: .infinity, alignment: .bottom)
                }
            }
        }
    }

    private func colorForIntensity(_ intensity: String) -> Color {
        switch intensity {
        case "Light": return Color(red: 0.39, green: 0.70, blue: 0.93)    // #63B3ED
        case "Moderate": return Color(red: 0.26, green: 0.60, blue: 0.88) // #4299E1
        case "Heavy": return Color(red: 0.17, green: 0.42, blue: 0.69)    // #2B6CB0
        default: return Color.gray.opacity(0.3)
        }
    }
}
