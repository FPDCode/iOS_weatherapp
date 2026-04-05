import AppIntents
import SwiftUI
import WidgetKit

// MARK: - Activity Selection Intent

struct SelectActivityIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Activity"
    static var description = IntentDescription("Choose which outdoor activity to show the best time for.")

    @Parameter(title: "Activity", default: .running)
    var activity: ActivityOption
}

enum ActivityOption: String, AppEnum {
    case running = "Running"
    case walking = "Walking"
    case cycling = "Cycling"
    case errands = "Errands"

    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Activity")

    static var caseDisplayRepresentations: [ActivityOption: DisplayRepresentation] = [
        .running: DisplayRepresentation(title: "Running", image: .init(systemName: "figure.run")),
        .walking: DisplayRepresentation(title: "Walking", image: .init(systemName: "figure.walk")),
        .cycling: DisplayRepresentation(title: "Cycling", image: .init(systemName: "figure.outdoor.cycle")),
        .errands: DisplayRepresentation(title: "Errands", image: .init(systemName: "bag.fill")),
    ]

    var icon: String {
        switch self {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .errands: return "bag.fill"
        }
    }
}

// MARK: - Widget

struct BestTimeForWidget: Widget {
    let kind = "BestTimeFor"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectActivityIntent.self, provider: BestTimeProvider()) { entry in
            BestTimeForWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Best Time For")
        .description("Best upcoming time slot for your chosen activity.")
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Timeline Provider

struct BestTimeEntry: TimelineEntry {
    let date: Date
    let activity: ActivityOption
    let windows: [SharedActivityWindow]
    let locationName: String?
}

struct BestTimeProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> BestTimeEntry {
        BestTimeEntry(date: .now, activity: .running, windows: [], locationName: "Loading...")
    }

    func snapshot(for configuration: SelectActivityIntent, in context: Context) async -> BestTimeEntry {
        makeEntry(for: configuration.activity)
    }

    func timeline(for configuration: SelectActivityIntent, in context: Context) async -> Timeline<BestTimeEntry> {
        let entry = makeEntry(for: configuration.activity)
        let nextUpdate = Calendar.current.date(byAdding: .minute, value: 30, to: .now) ?? .now
        return Timeline(entries: [entry], policy: .after(nextUpdate))
    }

    private func makeEntry(for activity: ActivityOption) -> BestTimeEntry {
        let data = WidgetDataStore.read()
        let windows = data?.activityWindows.filter { $0.activity == activity.rawValue } ?? []
        // Sort by score descending, take top 3
        let top = windows.sorted { $0.score > $1.score }.prefix(3)
        return BestTimeEntry(
            date: .now,
            activity: activity,
            windows: Array(top),
            locationName: data?.locationName
        )
    }
}

// MARK: - View

struct BestTimeForWidgetView: View {
    let entry: BestTimeEntry

    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "h:mma"
        return f
    }()

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Header
            HStack {
                Image(systemName: entry.activity.icon)
                    .font(.caption)
                    .foregroundStyle(.orange)
                Text("BEST TIME FOR \(entry.activity.rawValue.uppercased())")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if let loc = entry.locationName {
                    Text(loc)
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
            }

            if entry.windows.isEmpty {
                Spacer()
                Text("No good times found. Open the app to refresh.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                Spacer()
            } else {
                ForEach(Array(entry.windows.enumerated()), id: \.offset) { _, window in
                    HStack(spacing: 10) {
                        // Rating badge
                        ZStack {
                            Circle()
                                .fill(Color(hex: window.ratingColor).opacity(0.2))
                                .frame(width: 32, height: 32)
                            Text("\(Int(window.score))")
                                .font(.system(size: 11, weight: .bold))
                                .foregroundStyle(Color(hex: window.ratingColor))
                        }

                        VStack(alignment: .leading, spacing: 1) {
                            HStack(spacing: 4) {
                                Text("\(Self.timeFormatter.string(from: window.startTime).lowercased()) – \(Self.timeFormatter.string(from: window.endTime).lowercased())")
                                    .font(.caption)
                                    .fontWeight(.medium)

                                if !window.isToday {
                                    Text("Tomorrow")
                                        .font(.system(size: 8))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 4)
                                        .padding(.vertical, 1)
                                        .background(Capsule().fill(.quaternary))
                                }
                            }

                            HStack(spacing: 6) {
                                Text("\(Int(round(window.temp)))°")
                                    .font(.caption2)
                                if window.precipChance > 10 {
                                    HStack(spacing: 1) {
                                        Image(systemName: "drop.fill")
                                            .font(.system(size: 7))
                                            .foregroundStyle(.blue)
                                        Text("\(window.precipChance)%")
                                            .font(.system(size: 10))
                                    }
                                }
                            }
                            .foregroundStyle(.secondary)
                        }

                        Spacer()

                        Text(window.rating)
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(Color(hex: window.ratingColor))
                    }
                }
            }
        }
    }
}

// MARK: - Color Helper (duplicated for widget target)

private extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r, g, b: UInt64
        if hex.count == 6 {
            (r, g, b) = (int >> 16, int >> 8 & 0xFF, int & 0xFF)
        } else {
            (r, g, b) = (0, 0, 0)
        }
        self.init(.sRGB, red: Double(r) / 255, green: Double(g) / 255, blue: Double(b) / 255)
    }
}
