import SwiftUI

struct WeatherNowView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var weatherViewModel: WeatherViewModel
    @ObservedObject var locationStore = LocationStore.shared
    @State private var showLocationPicker = false
    @State private var showNavTitle = false
    @State private var showAQIDetail = false
    @State private var showUVDetail = false
    @State private var showPressureDetail = false
    @State private var showWindDetail = false
    @State private var showSunDetail = false
    @State private var showPrecipDetail = false
    @State private var showCloudDetail = false
    var switchToRadar: (() -> Void)?

    var body: some View {
        NavigationStack {
            ZStack {
                // Near-black background matching the shader's dark ground
                Color(red: 0.04, green: 0.04, blue: 0.06)
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
            }
            .ignoresSafeArea(edges: .top)
            .navigationTitle(showNavTitle ? locationService.cityName : "")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(showNavTitle ? .visible : .hidden, for: .navigationBar)
            .toolbarColorScheme(.dark, for: .navigationBar)
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
        GeometryReader { outerGeo in
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 0) {
                // Edge-to-edge shader header — NO padding
                AdaptiveHorizonHeader(
                    cityName: locationService.cityName,
                    temperature: weatherViewModel.currentTemp,
                    condition: weatherViewModel.currentCondition,
                    high: weatherViewModel.todayHigh,
                    low: weatherViewModel.todayLow,
                    weatherCode: weatherViewModel.currentWeatherCode,
                    isDay: weatherViewModel.isDay,
                    sunrise: weatherViewModel.sunrise,
                    sunset: weatherViewModel.sunset,
                    sunriseDate: weatherViewModel.sunriseDate,
                    sunsetDate: weatherViewModel.sunsetDate,
                    lastUpdated: weatherViewModel.lastUpdated,
                    cloudCoverHigh: weatherViewModel.cloudCoverInfo?.high ?? 0,
                    cloudCoverMid: weatherViewModel.cloudCoverInfo?.mid ?? 0,
                    cloudCoverLow: weatherViewModel.cloudCoverInfo?.low ?? 0,
                    precipAmount: weatherViewModel.precipTimeline?.slots.first?.precipitation ?? 0,
                    isRaining: weatherViewModel.precipTimeline?.isRaining ?? false,
                    windSpeed: weatherViewModel.windInfo?.speed ?? 0,
                    visibility: weatherViewModel.currentVisibility,
                    humidity: weatherViewModel.currentHumidity
                )
                .background(
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: ScrollOffsetKey.self, value: geo.frame(in: .named("scroll")).minY)
                    }
                )

                // Cards with padding
                VStack(spacing: 16) {
                // Weather Warnings (NWS + Smart)
                    if !weatherViewModel.nwsAlerts.isEmpty || !weatherViewModel.smartWarnings.isEmpty {
                        GlassCard {
                            WeatherWarningsView(
                                nwsAlerts: weatherViewModel.nwsAlerts,
                                smartWarnings: weatherViewModel.smartWarnings,
                                airQuality: weatherViewModel.airQuality
                            )
                        }
                    }

                    // Precipitation Timeline (next 2 hours)
                    if let precip = weatherViewModel.precipTimeline {
                        GlassCard {
                            PrecipTimelineView(timeline: precip)
                        }
                        .onTapGesture { showPrecipDetail = true }
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
                        .onTapGesture { showSunDetail = true }
                    }

                    // Wind Gauge
                    if let wind = weatherViewModel.windInfo {
                        GlassCard {
                            WindGaugeView(wind: wind)
                        }
                        .onTapGesture { showWindDetail = true }
                    }

                    // Air Pressure
                    if let pressure = weatherViewModel.pressureInfo {
                        GlassCard {
                            PressureView(info: pressure)
                        }
                        .onTapGesture { showPressureDetail = true }
                    }

                    // Air Quality & UV
                    if let aq = weatherViewModel.airQuality {
                        GlassCard {
                            AirQualityView(
                                airQuality: aq,
                                uvIndex: weatherViewModel.todayUVIndex,
                                hourlyForecasts: weatherViewModel.hourlyForecasts
                            )
                        }
                        .onTapGesture { showAQIDetail = true }
                    }

                    // Cloud Cover + Storm Risk
                    if let clouds = weatherViewModel.cloudCoverInfo {
                        GlassCard {
                            CloudCoverView(info: clouds, stormRisk: weatherViewModel.stormRisk)
                        }
                        .onTapGesture { showCloudDetail = true }
                    }

                Text("Data from Open-Meteo.com")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
                }
                .padding(.horizontal, 16)
            }
            .frame(width: outerGeo.size.width)
        }
        .coordinateSpace(name: "scroll")
        .onPreferenceChange(ScrollOffsetKey.self) { offset in
            // Show nav title when the header scrolls past the top
            withAnimation(.easeInOut(duration: 0.2)) {
                showNavTitle = offset < -20
            }
        }
        .refreshable {
            if let lat = locationService.latitude,
               let lon = locationService.longitude {
                await weatherViewModel.fetchWeather(latitude: lat, longitude: lon)
            }
        }
        } // GeometryReader
        .sheet(isPresented: $showPrecipDetail) {
            if let precip = weatherViewModel.precipTimeline {
                PrecipDetailSheet(timeline: precip, hourlyForecasts: weatherViewModel.hourlyForecasts)
            }
        }
        .sheet(isPresented: $showCloudDetail) {
            if let clouds = weatherViewModel.cloudCoverInfo {
                CloudCoverDetailSheet(info: clouds, stormRisk: weatherViewModel.stormRisk)
            }
        }
        .sheet(isPresented: $showAQIDetail) {
            if let aq = weatherViewModel.airQuality {
                AQIDetailSheet(airQuality: aq, hourlyForecasts: weatherViewModel.hourlyForecasts)
            }
        }
        .sheet(isPresented: $showUVDetail) {
            UVDetailSheet(currentUV: weatherViewModel.todayUVIndex, hourlyForecasts: weatherViewModel.hourlyForecasts)
        }
        .sheet(isPresented: $showPressureDetail) {
            if let pressure = weatherViewModel.pressureInfo {
                PressureDetailSheet(info: pressure)
            }
        }
        .sheet(isPresented: $showWindDetail) {
            if let wind = weatherViewModel.windInfo {
                WindDetailSheet(wind: wind, hourlyForecasts: weatherViewModel.hourlyForecasts)
            }
        }
        .sheet(isPresented: $showSunDetail) {
            if let rise = weatherViewModel.sunriseDate, let set = weatherViewModel.sunsetDate {
                SunDetailSheet(
                    sunriseDate: rise, sunsetDate: set,
                    tomorrowSunrise: weatherViewModel.tomorrowSunriseDate,
                    tomorrowSunset: weatherViewModel.tomorrowSunsetDate,
                    dailyForecasts: weatherViewModel.dailyForecasts
                )
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

// MARK: - Scroll Offset Preference Key

private struct ScrollOffsetKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}
