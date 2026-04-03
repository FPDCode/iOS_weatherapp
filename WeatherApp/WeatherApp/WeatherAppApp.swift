import SwiftUI

@main
struct WeatherAppApp: App {
    @StateObject private var locationService = LocationService()
    @StateObject private var weatherViewModel = WeatherViewModel()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(locationService)
                .environmentObject(weatherViewModel)
                .task {
                    locationService.requestLocation()
                }
                .onChange(of: locationService.latitude) { _, _ in
                    if let lat = locationService.latitude,
                       let lon = locationService.longitude {
                        Task {
                            await weatherViewModel.fetchWeather(latitude: lat, longitude: lon)
                        }
                    }
                }
        }
    }
}
