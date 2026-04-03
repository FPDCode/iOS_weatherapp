import SwiftUI

struct ContentView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var weatherViewModel: WeatherViewModel
    @State private var showRefreshHint = false

    var body: some View {
        ZStack {
            // Dynamic background
            BackgroundGradient.forTimeOfDay(
                isDay: weatherViewModel.isDay,
                weatherCode: weatherViewModel.currentWeatherCode
            )
            .ignoresSafeArea()

            if weatherViewModel.isLoading {
                loadingView
            } else if let error = weatherViewModel.errorMessage {
                errorView(error)
            } else {
                mainContent
            }
        }
        .preferredColorScheme(.dark)
    }

    // MARK: - Main Content

    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 20) {
                // Current weather header
                CurrentWeatherHeader(
                    cityName: locationService.cityName,
                    temperature: weatherViewModel.currentTemp,
                    condition: weatherViewModel.currentCondition,
                    high: weatherViewModel.todayHigh,
                    low: weatherViewModel.todayLow,
                    weatherCode: weatherViewModel.currentWeatherCode,
                    isDay: weatherViewModel.isDay,
                    sunrise: weatherViewModel.sunrise,
                    sunset: weatherViewModel.sunset
                )

                // Today's phases
                GlassCard {
                    TodayPhasesView(
                        phases: weatherViewModel.todayPhases,
                        isDay: weatherViewModel.isDay
                    )
                }

                // 48-hour forecast
                GlassCard {
                    HourlyForecastView(
                        forecasts: weatherViewModel.hourlyForecasts
                    )
                }

                // 10-day forecast
                GlassCard {
                    DailyForecastView(
                        forecasts: weatherViewModel.dailyForecasts
                    )
                }

                // Attribution
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
            ProgressView()
                .scaleEffect(1.5)
                .tint(.white)
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
