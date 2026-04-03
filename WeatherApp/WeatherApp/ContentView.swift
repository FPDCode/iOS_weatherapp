import SwiftUI

struct ContentView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var weatherViewModel: WeatherViewModel
    @EnvironmentObject var unitSettings: UnitSettings
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WeatherNowView()
                .tabItem {
                    Label("Now", systemImage: "cloud.sun.fill")
                }
                .tag(0)

            PlanYourDayView()
                .tabItem {
                    Label("Plan", systemImage: "calendar.badge.clock")
                }
                .tag(1)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(2)
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationService())
        .environmentObject(WeatherViewModel())
        .environmentObject(UnitSettings.shared)
}
