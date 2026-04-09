import SwiftUI

/// Immersive weather horizon header with 3-layer Metal shader pipeline:
/// atmosphericSky → proceduralClouds → weatherParticles
struct HorizonHeaderView: View {
    let cityName: String
    let temperature: Double
    let condition: String
    let high: Double
    let low: Double
    let weatherCode: Int
    let isDay: Bool
    let sunrise: String
    let sunset: String
    let sunriseDate: Date?
    let sunsetDate: Date?
    let lastUpdated: Date?
    // Additional weather data for shader
    var cloudCoverHigh: Int = 0
    var cloudCoverMid: Int = 0
    var cloudCoverLow: Int = 0
    var precipAmount: Double = 0
    var isRaining: Bool = false
    var windSpeed: Double = 0
    var visibility: Double = 10000
    var humidity: Int = 50

    // MARK: - Computed Shader Parameters

    /// 0 = midnight, 0.5 = noon, 1 = midnight
    private var timeOfDay: Double {
        let calendar = Calendar.current
        let now = Date()
        let startOfDay = calendar.startOfDay(for: now)
        let seconds = now.timeIntervalSince(startOfDay)
        return seconds / 86400.0
    }

    /// Sun elevation: -1 (well below horizon) to 1 (solar noon)
    private var sunElevation: Float {
        guard let rise = sunriseDate, let set = sunsetDate else { return isDay ? 0.5 : -0.5 }
        let now = Date()
        if now < rise {
            let timeToSunrise = rise.timeIntervalSince(now) / 3600.0
            return Float(-min(timeToSunrise, 1.0))
        } else if now > set {
            let timeSinceSunset = now.timeIntervalSince(set) / 3600.0
            return Float(-min(timeSinceSunset, 1.0))
        } else {
            let total = set.timeIntervalSince(rise)
            let elapsed = now.timeIntervalSince(rise)
            return Float(sin(elapsed / total * .pi))
        }
    }

    /// 0 = sunrise, 1 = sunset (position on arc)
    private var sunAzimuth: Float {
        guard let rise = sunriseDate, let set = sunsetDate else { return 0.5 }
        let now = Date()
        if now < rise { return 0.0 }
        if now > set { return 1.0 }
        let total = set.timeIntervalSince(rise)
        let elapsed = now.timeIntervalSince(rise)
        return Float(min(max(elapsed / total, 0), 1))
    }

    private var normalizedVisibility: Float {
        Float(min(visibility / 20000.0, 1.0))
    }

    private var normalizedHumidity: Float {
        Float(humidity) / 100.0
    }

    private var normalizedWindSpeed: Float {
        Float(min(windSpeed / 50.0, 1.0))
    }

    private var isSnow: Float {
        (71...86).contains(weatherCode) ? 1.0 : 0.0
    }

    private var groundRGB: SIMD3<Float> {
        let (r, g, b) = BackgroundGradient.groundColorComponents(isDay: isDay, weatherCode: weatherCode)
        return SIMD3<Float>(r, g, b)
    }

    var body: some View {
        ZStack(alignment: .bottom) {
            skyCanvas
            weatherOverlay
        }
        .frame(maxWidth: .infinity)
        .frame(height: 420)
        .clipped()
    }

    // MARK: - Sky Shader Canvas (3 layers)

    private var skyCanvas: some View {
        GeometryReader { geo in
            TimelineView(.animation(minimumInterval: 1.0 / 30.0)) { timeline in
                let time = Float(timeline.date.timeIntervalSince1970.truncatingRemainder(dividingBy: 10000))
                let w = Float(geo.size.width)
                let h = Float(geo.size.height)

                Canvas { context, size in
                    context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(.white))
                }
                .frame(width: geo.size.width, height: geo.size.height)
                // Layer 1: Atmospheric sky + sun/moon + arc + ground
                .colorEffect(ShaderLibrary.atmosphericSky(
                    .float2(w, h),
                    .float(sunElevation),
                    .float(sunAzimuth),
                    .float(time),
                    .float(normalizedVisibility),
                    .float(normalizedHumidity),
                    .float3(groundRGB.x, groundRGB.y, groundRGB.z),
                    .float(isDay ? 0.0 : 1.0)
                ))
                // Layer 2: Procedural clouds
                .colorEffect(ShaderLibrary.proceduralClouds(
                    .float2(w, h),
                    .float3(Float(cloudCoverLow) / 100.0,
                            Float(cloudCoverMid) / 100.0,
                            Float(cloudCoverHigh) / 100.0),
                    .float(normalizedWindSpeed),
                    .float(sunElevation),
                    .float(Float(weatherCode)),
                    .float(time)
                ))
                // Layer 3: Rain/snow particles
                .colorEffect(ShaderLibrary.weatherParticles(
                    .float2(w, h),
                    .float(Float(precipAmount)),
                    .float(isSnow),
                    .float(normalizedWindSpeed),
                    .float(time)
                ))
            }
        }
    }

    // MARK: - Weather Info Overlay

    private var weatherOverlay: some View {
        VStack(spacing: 4) {
            Spacer()

            Text(cityName)
                .font(.title2)
                .fontWeight(.medium)
                .shadow(color: .black.opacity(0.5), radius: 6, x: 0, y: 2)

            Text(WeatherFormatters.temperature(temperature))
                .font(.system(size: 72, weight: .thin, design: .rounded))
                .shadow(color: .black.opacity(0.5), radius: 8, x: 0, y: 2)

            Text(condition)
                .font(.title3)
                .fontWeight(.medium)
                .foregroundStyle(.white.opacity(0.85))
                .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 1)

            HStack(spacing: 16) {
                Label("H: \(WeatherFormatters.temperature(high))", systemImage: "arrow.up")
                    .font(.subheadline)
                Label("L: \(WeatherFormatters.temperature(low))", systemImage: "arrow.down")
                    .font(.subheadline)
            }
            .foregroundStyle(.white.opacity(0.85))
            .shadow(color: .black.opacity(0.6), radius: 6, x: 0, y: 1)
            .padding(.top, 2)

            // Sunrise/Sunset
            HStack(spacing: 24) {
                Label(sunrise, systemImage: "sunrise.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
                Label(sunset, systemImage: "sunset.fill")
                    .font(.caption)
                    .foregroundStyle(.orange)
            }
            .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 1)
            .padding(.top, 6)

            // Last updated
            if let lastUpdated {
                Text("Updated \(lastUpdated, style: .relative) ago")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.5))
                    .shadow(color: .black.opacity(0.7), radius: 4, x: 0, y: 1)
                    .padding(.top, 2)
            }
        }
        .padding(.bottom, 80)
    }
}

// MARK: - Adaptive Wrapper

struct AdaptiveHorizonHeader: View {
    let cityName: String
    let temperature: Double
    let condition: String
    let high: Double
    let low: Double
    let weatherCode: Int
    let isDay: Bool
    let sunrise: String
    let sunset: String
    let sunriseDate: Date?
    let sunsetDate: Date?
    let lastUpdated: Date?
    var cloudCoverHigh: Int = 0
    var cloudCoverMid: Int = 0
    var cloudCoverLow: Int = 0
    var precipAmount: Double = 0
    var isRaining: Bool = false
    var windSpeed: Double = 0
    var visibility: Double = 10000
    var humidity: Int = 50

    var body: some View {
        HorizonHeaderView(
            cityName: cityName,
            temperature: temperature,
            condition: condition,
            high: high, low: low,
            weatherCode: weatherCode,
            isDay: isDay,
            sunrise: sunrise, sunset: sunset,
            sunriseDate: sunriseDate, sunsetDate: sunsetDate,
            lastUpdated: lastUpdated,
            cloudCoverHigh: cloudCoverHigh,
            cloudCoverMid: cloudCoverMid,
            cloudCoverLow: cloudCoverLow,
            precipAmount: precipAmount,
            isRaining: isRaining,
            windSpeed: windSpeed,
            visibility: visibility,
            humidity: humidity
        )
    }
}
