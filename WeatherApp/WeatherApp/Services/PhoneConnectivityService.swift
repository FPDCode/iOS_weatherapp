import Foundation
import WatchConnectivity

/// iPhone-side WatchConnectivity service.
/// Sends weather data to the Apple Watch via application context.
@MainActor
class PhoneConnectivityService: NSObject, ObservableObject {
    static let shared = PhoneConnectivityService()

    private let session = WCSession.default

    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    /// Send weather data to the Watch
    func sendWeatherData(_ data: SharedWeatherData) {
        guard WCSession.isSupported(), session.activationState == .activated else { return }

        guard let encoded = try? JSONEncoder().encode(data) else { return }

        // Use application context (persists, delivered when watch wakes)
        try? session.updateApplicationContext(["weatherData": encoded])

        // Also send as message if watch is reachable (immediate delivery)
        if session.isReachable {
            session.sendMessage(["weatherData": encoded], replyHandler: nil)
        }
    }
}

// MARK: - WCSessionDelegate

extension PhoneConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

    nonisolated func sessionDidBecomeInactive(_ session: WCSession) {}

    nonisolated func sessionDidDeactivate(_ session: WCSession) {
        session.activate()
    }

    /// Watch requested an update
    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if message["request"] as? String == "weatherUpdate" {
            // The ViewModel will send data on next refresh
            // For now, resend the last cached data from App Group
            Task { @MainActor in
                if let data = WidgetDataStore.read() {
                    self.sendWeatherData(data)
                }
            }
        }
    }
}
