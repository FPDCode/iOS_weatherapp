import SwiftUI

struct ContentView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var weatherViewModel: WeatherViewModel
    @AppStorage("temperatureUnit") var temperatureUnit: String = TemperatureUnit.fahrenheit.rawValue
    @State private var showSettings = false
    @State private var showSearch = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Dynamic background
                BackgroundGradient.forTimeOfDay(
                    isDay: weatherViewModel.isDay,
                    weatherCode: weatherViewModel.currentWeatherCode
                )
                .ignoresSafeArea()

                if weatherViewModel.isLoading {
                    loadingView
                        .transition(.opacity)
                } else if let error = weatherViewModel.errorMessage {
                    errorView(error)
                        .transition(.opacity)
                } else {
                    mainContent
                        .transition(.opacity)
                }
            }
            .animation(.easeInOut(duration: 0.4), value: weatherViewModel.isLoading)
            .animation(.easeInOut(duration: 0.4), value: weatherViewModel.errorMessage)
            .preferredColorScheme(.dark)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "magnifyingglass")
                    }
                    .accessibilityLabel("Search location")

                    Button {
                        showSettings = true
                    } label: {
                        Image(systemName: "gearshape")
                    }
                    .accessibilityLabel("Settings")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSettings) {
                SettingsSheet()
            }
            .sheet(isPresented: $showSearch) {
                CitySearchSheet()
                    .environmentObject(locationService)
                    .environmentObject(weatherViewModel)
            }
            .onChange(of: temperatureUnit) { _, _ in
                if let lat = locationService.latitude,
                   let lon = locationService.longitude {
                    Task {
                        await weatherViewModel.fetchWeather(latitude: lat, longitude: lon)
                    }
                }
            }
        }
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                CurrentWeatherHeader(
                    cityName: locationService.cityName,
                    temperature: weatherViewModel.currentTemp,
                    condition: weatherViewModel.currentCondition,
                    high: weatherViewModel.todayHigh,
                    low: weatherViewModel.todayLow,
                    weatherCode: weatherViewModel.currentWeatherCode,
                    isDay: weatherViewModel.isDay,
                    sunrise: weatherViewModel.sunrise,
                    sunset: weatherViewModel.sunset,
                    lastUpdated: weatherViewModel.lastUpdated
                )

                GlassCard {
                    TodayPhasesView(
                        phases: weatherViewModel.todayPhases,
                        isDay: weatherViewModel.isDay
                    )
                }

                GlassCard {
                    HourlyForecastView(
                        forecasts: weatherViewModel.hourlyForecasts
                    )
                }

                GlassCard {
                    DailyForecastView(
                        forecasts: weatherViewModel.dailyForecasts
                    )
                }

                Text("Data from Open-Meteo.com")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 16)
        }
        .refreshable {
            if let lat = locationService.latitude,
               let lon = locationService.longitude {
                await weatherViewModel.fetchWeather(latitude: lat, longitude: lon)
            }
        }
    }

    // MARK: - Loading View

    private var loadingView: some View {
        VStack(spacing: 20) {
            Image(systemName: "cloud.sun.rain.fill")
                .font(.system(size: 50))
                .symbolRenderingMode(.multicolor)
                .symbolEffect(.pulse)
            Text("Fetching weather...")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
    }

    // MARK: - Error View

    private func errorView(_ message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.icloud.fill")
                .font(.system(size: 50))
                .foregroundStyle(.secondary)
            Text("Unable to Load Weather")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                if let lat = locationService.latitude,
                   let lon = locationService.longitude {
                    Task {
                        await weatherViewModel.fetchWeather(latitude: lat, longitude: lon)
                    }
                }
            }
            .buttonStyle(.bordered)
            .tint(.white)
        }
        .padding()
    }
}

#Preview {
    ContentView()
        .environmentObject(LocationService())
        .environmentObject(WeatherViewModel())
}
