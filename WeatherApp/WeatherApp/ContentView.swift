import SwiftUI

struct ContentView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var weatherViewModel: WeatherViewModel
    @EnvironmentObject var unitSettings: UnitSettings
    @State private var selectedTab = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            WeatherNowView(switchToRadar: { selectedTab = 2 })
                .tabItem {
                    Label("Now", systemImage: "cloud.sun.fill")
                }
                .tag(0)

            PlanYourDayView()
                .tabItem {
                    Label("Plan", systemImage: "calendar.badge.clock")
                }
                .tag(1)

            RadarTabView()
                .tabItem {
                    Label("Radar", systemImage: "dot.radiowaves.left.and.right")
                }
                .tag(2)

            SettingsView()
                .tabItem {
                    Label("Settings", systemImage: "gearshape")
                }
                .tag(3)

            // Search tab — separated from main tabs on iOS 26 (like Apple's design)
            searchTab
        }
        .tint(.white)
        .preferredColorScheme(.dark)
    }

    @ViewBuilder
    private var searchTab: some View {
        if #available(iOS 26, *) {
            SearchTabView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tabRole(.search)
                .tag(4)
        } else {
            SearchTabView()
                .tabItem {
                    Label("Search", systemImage: "magnifyingglass")
                }
                .tag(4)
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationService())
        .environmentObject(WeatherViewModel())
        .environmentObject(UnitSettings.shared)
}
