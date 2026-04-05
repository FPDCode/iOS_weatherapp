import ActivityKit
import Foundation

/// Manages the rain Live Activity — starts when rain is detected in the
/// next 2 hours, updates every data refresh, ends when the window is clear.
@MainActor
final class RainActivityService {
    static let shared = RainActivityService()

    private var currentActivity: Activity<RainActivityAttributes>?

    // MARK: - Public API

    /// Called after every weather refresh. Decides whether to start, update, or end.
    func update(with timeline: PrecipitationTimeline?, locationName: String) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }

        guard let timeline, timeline.maxIntensity >= 0.1 else {
            // No rain — end any running activity
            endIfNeeded()
            return
        }

        let state = contentState(from: timeline, locationName: locationName)

        if let activity = currentActivity {
            // Update existing activity
            Task {
                await activity.update(
                    ActivityContent(state: state, staleDate: Date().addingTimeInterval(20 * 60))
                )
            }
        } else {
            // Start a new activity
            startActivity(state: state)
        }
    }

    /// Force-end the activity (e.g. when app terminates or user switches location).
    func endIfNeeded() {
        guard let activity = currentActivity else { return }
        let finalState = RainActivityAttributes.ContentState(
            summary: "No rain expected",
            nextChangeLabel: "Clear for now",
            isRaining: false,
            slots: [],
            locationName: "",
            updatedAt: Date()
        )
        Task {
            await activity.end(
                ActivityContent(state: finalState, staleDate: nil),
                dismissalPolicy: .immediate
            )
        }
        currentActivity = nil
    }

    // MARK: - Private

    private func startActivity(state: RainActivityAttributes.ContentState) {
        let attributes = RainActivityAttributes()
        let content = ActivityContent(state: state, staleDate: Date().addingTimeInterval(20 * 60))

        do {
            currentActivity = try Activity.request(
                attributes: attributes,
                content: content,
                pushType: nil
            )
        } catch {
            print("⛈️ Failed to start rain Live Activity: \(error)")
        }
    }

    private func contentState(
        from timeline: PrecipitationTimeline,
        locationName: String
    ) -> RainActivityAttributes.ContentState {
        let now = Date()
        let slots = timeline.slots.map { slot in
            RainActivityAttributes.RainSlot(
                minuteOffset: max(0, Int(slot.time.timeIntervalSince(now) / 60)),
                precipitation: slot.precipitation,
                intensity: slot.intensity.rawValue
            )
        }

        return RainActivityAttributes.ContentState(
            summary: timeline.summary,
            nextChangeLabel: timeline.nextChangeLabel ?? "Rain in the next 2h",
            isRaining: timeline.isRaining,
            slots: slots,
            locationName: locationName,
            updatedAt: now
        )
    }
}
