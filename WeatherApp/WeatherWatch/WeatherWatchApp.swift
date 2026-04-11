import SwiftUI

@main
struct WeatherWatchApp: App {
    @StateObject private var connectivity = WatchConnectivityService.shared

    var body: some Scene {
        WindowGroup {
            WatchHomeView()
                .environmentObject(connectivity)
        }
    }
}
