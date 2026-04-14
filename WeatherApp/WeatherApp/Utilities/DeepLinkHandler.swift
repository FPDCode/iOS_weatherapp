import Foundation

/// Handles deep links from widgets, Live Activity, and notifications.
/// URL scheme: weatherapp://section/name
/// Examples:
///   weatherapp://now/precipitation
///   weatherapp://now/alerts
///   weatherapp://now/hourly
///   weatherapp://now/daily
///   weatherapp://now/sunrise
///   weatherapp://now/wind
///   weatherapp://now/pressure
///   weatherapp://now/airquality
///   weatherapp://now/cloudcover
///   weatherapp://plan
///   weatherapp://radar
///   weatherapp://settings

@MainActor
class DeepLinkHandler: ObservableObject {
    static let shared = DeepLinkHandler()

    @Published var selectedTab: Int = 0
    @Published var pendingDetail: DetailDestination?

    enum DetailDestination: String {
        case precipitation
        case alerts
        case hourly
        case daily
        case sunrise
        case wind
        case pressure
        case airquality
        case cloudcover
        case pollen
        case besttime
    }

    func handle(_ url: URL) {
        guard url.scheme == "weatherapp" else { return }
        let host = url.host ?? ""
        let path = url.pathComponents.dropFirst().first ?? ""

        switch host {
        case "now":
            selectedTab = 0
            if !path.isEmpty {
                pendingDetail = DetailDestination(rawValue: path)
            }
        case "plan":
            selectedTab = 1
        case "radar":
            selectedTab = 2
        case "settings":
            selectedTab = 3
        case "search":
            selectedTab = 4
        default:
            selectedTab = 0
        }
    }

    func clearPendingDetail() {
        pendingDetail = nil
    }
}
