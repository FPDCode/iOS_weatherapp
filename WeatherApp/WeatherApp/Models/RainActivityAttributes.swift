import ActivityKit
import Foundation

struct RainActivityAttributes: ActivityAttributes {
    /// Fixed context — set when the activity starts
    struct ContentState: Codable, Hashable {
        let summary: String          // e.g. "Light rain expected"
        let nextChangeLabel: String   // e.g. "Stopping in 45 min"
        let isRaining: Bool
        let slots: [RainSlot]         // Up to 8 fifteen-minute slots
        let locationName: String
        let updatedAt: Date
    }

    /// One 15-minute precipitation slot for the timeline bar
    struct RainSlot: Codable, Hashable {
        let minuteOffset: Int         // Minutes from activity start (0, 15, 30...)
        let precipitation: Double     // mm per 15 min
        let intensity: String         // "None", "Light", "Moderate", "Heavy"
    }
}
