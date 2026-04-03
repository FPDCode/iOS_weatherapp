import SwiftUI

struct WeatherNowView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var weatherViewModel: WeatherViewModel
    @ObservedObject var locationStore = LocationStore.shared
    @State private var showSearch = false
    @State private var showLocationPicker = false
    var switchToRadar: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
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
                ToolbarItemGroup(placement: .topBarLeading) {
                    // Location switcher
                    if locationStore.savedLocations.count > 1 {
                        Menu {
                            ForEach(locationStore.savedLocations) { location in
                                Button {
                                    switchLocation(location)
                                } label: {
                                    Label(
                                        location.name,
                                        systemImage: location.isCurrentLocation ? "location.fill" : "mappin.circle.fill"
                                    )
                                    if location.id == locationStore.activeLocationId {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        } label: {
                            HStack(spacing: 4) {
                                Image(systemName: locationStore.isUsingCurrentLocation ? "location.fill" : "mappin.circle.fill")
                                    .font(.caption)
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 8, weight: .bold))
                            }
                        }
                        .accessibilityLabel("Switch location")
                    }
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showSearch = true
                    } label: {
                        Image(systemName: "plus.circle")
                    }
                    .accessibilityLabel("Add location")
                }
            }
            .toolbarBackground(.hidden, for: .navigationBar)
            .sheet(isPresented: $showSearch) {
                CitySearchSheet()
                    .environmentObject(locationService)
                    .environmentObject(weatherViewModel)
            }
        }
    }

    private func switchLocation(_ location: SavedLocation) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        locationStore.switchTo(location)
        if location.isCurrentLocation {
            locationService.requestLocation()
        } else {
            locationService.setManualLocation(
                latitude: location.latitude,
                longitude: location.longitude,
                cityName: location.name
            )
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

                // Weather Warnings (NWS + Smart)
                if !weatherViewModel.nwsAlerts.isEmpty || !weatherViewModel.smartWarnings.isEmpty {
                    GlassCard {
                        WeatherWarningsView(
                            nwsAlerts: weatherViewModel.nwsAlerts,
                            smartWarnings: weatherViewModel.smartWarnings
                        )
                    }
                }

                // Precipitation Timeline (next 2 hours)
                if let precip = weatherViewModel.precipTimeline {
                    GlassCard {
                        PrecipTimelineView(timeline: precip)
                    }
                }

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

                // Radar preview map
                if let lat = locationService.latitude, let lon = locationService.longitude {
                    GlassCard {
                        RadarPreviewCard(
                            latitude: lat,
                            longitude: lon,
                            isCurrentLocation: locationStore.isUsingCurrentLocation,
                            onTap: { switchToRadar?() }
                        )
                    }
                }

                GlassCard {
                    DailyForecastView(
                        forecasts: weatherViewModel.dailyForecasts
                    )
                }

                // Sunrise & Sunset
                if let rise = weatherViewModel.sunriseDate,
                   let set = weatherViewModel.sunsetDate {
                    GlassCard {
                        SunriseSunsetView(
                            sunriseDate: rise,
                            sunsetDate: set,
                            tomorrowSunrise: weatherViewModel.tomorrowSunriseDate,
                            tomorrowSunset: weatherViewModel.tomorrowSunsetDate
                        )
                    }
                }

                // Wind Gauge
                if let wind = weatherViewModel.windInfo {
                    GlassCard {
                        WindGaugeView(wind: wind)
                    }
                }

                // Air Pressure
                if let pressure = weatherViewModel.pressureInfo {
                    GlassCard {
                        PressureView(info: pressure)
                    }
                }

                // Air Quality & UV
                if let aq = weatherViewModel.airQuality {
                    GlassCard {
                        AirQualityView(
                            airQuality: aq,
                            uvIndex: weatherViewModel.todayUVIndex
                        )
                    }
                }

                // Comfort Index
                if let comfort = weatherViewModel.comfortInfo {
                    GlassCard {
                        ComfortIndexView(comfort: comfort)
                    }
                }

                // Cloud Cover + Storm Risk
                if let clouds = weatherViewModel.cloudCoverInfo {
                    GlassCard {
                        CloudCoverView(info: clouds, stormRisk: weatherViewModel.stormRisk)
                    }
                }

                // Gardening
                if let garden = weatherViewModel.gardeningInfo {
                    GlassCard {
                        GardeningView(info: garden)
                    }
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
