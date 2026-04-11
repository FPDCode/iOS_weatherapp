import Foundation
import WatchConnectivity

/// Watch-side WatchConnectivity service.
/// Receives weather data from the iPhone app via application context.
@MainActor
class WatchConnectivityService: NSObject, ObservableObject {
    static let shared = WatchConnectivityService()

    @Published var weatherData: SharedWeatherData?
    @Published var lastSync: Date?

    private let session = WCSession.default

    override init() {
        super.init()
        if WCSession.isSupported() {
            session.delegate = self
            session.activate()
        }
    }

    /// Ask the iPhone to send fresh data
    func requestUpdate() {
        guard session.isReachable else { return }
        session.sendMessage(["request": "weatherUpdate"], replyHandler: nil)
    }

    /// Decode weather data from received context
    private func processContext(_ context: [String: Any]) {
        guard let jsonData = context["weatherData"] as? Data else { return }
        if let decoded = try? JSONDecoder().decode(SharedWeatherData.self, from: jsonData) {
            weatherData = decoded
            lastSync = Date()
        }
    }
}

// MARK: - WCSessionDelegate

extension WatchConnectivityService: WCSessionDelegate {
    nonisolated func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        if activationState == .activated {
            Task { @MainActor in
                processContext(session.receivedApplicationContext)
            }
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
        Task { @MainActor in
            processContext(applicationContext)
        }
    }

    nonisolated func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        Task { @MainActor in
            if let jsonData = message["weatherData"] as? Data,
               let decoded = try? JSONDecoder().decode(SharedWeatherData.self, from: jsonData) {
                weatherData = decoded
                lastSync = Date()
            }
        }
    }
}
