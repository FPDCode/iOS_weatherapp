import SwiftUI

@main
struct WeatherAppApp: App {
    @StateObject private var locationService = LocationService()
    @StateObject private var weatherViewModel = WeatherViewModel()
    @StateObject private var unitSettings = UnitSettings.shared
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false

    init() {
        // Migration for existing users: if they already had a temperature unit saved,
        // skip onboarding and locale detection (they're upgrading, not new)
        if UserDefaults.standard.object(forKey: "temperatureUnit") != nil
            && !UserDefaults.standard.bool(forKey: "hasCompletedOnboarding") {
            UserDefaults.standard.set(true, forKey: "hasCompletedOnboarding")
            UserDefaults.standard.set(true, forKey: "hasAutoDetectedLocale")
            // Migrate old temperatureUnit to new key
            if let oldUnit = UserDefaults.standard.string(forKey: "temperatureUnit") {
                UserDefaults.standard.set(oldUnit, forKey: "unit_temperature")
            }
        }
    }

    var body: some Scene {
        WindowGroup {
            if hasCompletedOnboarding {
                ContentView()
                    .environmentObject(locationService)
                    .environmentObject(weatherViewModel)
                    .environmentObject(unitSettings)
                    .task {
                        locationService.requestLocation()
                    }
                    .onChange(of: locationService.latitude) { _, _ in
                        fetchWeatherIfReady()
                    }
                    .onChange(of: unitSettings.apiSignature) { _, _ in
                        fetchWeatherIfReady()
                    }
            } else {
                OnboardingView()
                    .environmentObject(locationService)
                    .environmentObject(weatherViewModel)
                    .environmentObject(unitSettings)
            }
        }
    }

    private func fetchWeatherIfReady() {
        if let lat = locationService.latitude,
           let lon = locationService.longitude {
            Task {
                await weatherViewModel.fetchWeather(latitude: lat, longitude: lon)
            }
        }
    }
}
