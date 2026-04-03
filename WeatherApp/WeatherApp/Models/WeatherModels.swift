import Foundation

// MARK: - Open-Meteo Forecast API Response

struct WeatherResponse: Codable {
    let latitude: Double
    let longitude: Double
    let currentWeather: CurrentWeather?
    let minutely15: Minutely15Data?
    let hourly: HourlyData?
    let daily: DailyData?

    enum CodingKeys: String, CodingKey {
        case latitude, longitude
        case currentWeather = "current_weather"
        case minutely15 = "minutely_15"
        case hourly, daily
    }
}

struct Minutely15Data: Codable {
    let time: [String]
    let precipitation: [Double]
    let rain: [Double]?
    let snowfall: [Double]?
}

struct CurrentWeather: Codable {
    let temperature: Double
    let windspeed: Double
    let winddirection: Double
    let weathercode: Int
    let isDay: Int
    let time: String

    enum CodingKeys: String, CodingKey {
        case temperature, windspeed, winddirection, weathercode
        case isDay = "is_day"
        case time
    }
}

struct HourlyData: Codable {
    let time: [String]
    let temperature2m: [Double]
    let apparentTemperature: [Double]
    let precipitationProbability: [Int]
    let precipitation: [Double]
    let weatherCode: [Int]
    let surfacePressure: [Double]?
    let relativeHumidity2m: [Int]
    let visibility: [Double]
    let windSpeed10m: [Double]
    let windGusts10m: [Double]?
    let windDirection10m: [Int]?
    let uvIndex: [Double]?
    let dewPoint2m: [Double]?
    let cloudCover: [Int]?
    let cloudCoverLow: [Int]?
    let cloudCoverMid: [Int]?
    let cloudCoverHigh: [Int]?
    let shortwaveRadiation: [Double]?
    let cape: [Double]?
    let soilTemperature0cm: [Double]?
    let soilMoisture0to1cm: [Double]?

    enum CodingKeys: String, CodingKey {
        case time
        case temperature2m = "temperature_2m"
        case apparentTemperature = "apparent_temperature"
        case precipitationProbability = "precipitation_probability"
        case precipitation
        case weatherCode = "weather_code"
        case surfacePressure = "surface_pressure"
        case relativeHumidity2m = "relative_humidity_2m"
        case visibility
        case windSpeed10m = "wind_speed_10m"
        case windGusts10m = "wind_gusts_10m"
        case windDirection10m = "wind_direction_10m"
        case uvIndex = "uv_index"
        case dewPoint2m = "dew_point_2m"
        case cloudCover = "cloud_cover"
        case cloudCoverLow = "cloud_cover_low"
        case cloudCoverMid = "cloud_cover_mid"
        case cloudCoverHigh = "cloud_cover_high"
        case shortwaveRadiation = "shortwave_radiation"
        case cape
        case soilTemperature0cm = "soil_temperature_0cm"
        case soilMoisture0to1cm = "soil_moisture_0_to_1cm"
    }
}

struct DailyData: Codable {
    let time: [String]
    let weatherCode: [Int]
    let temperature2mMax: [Double]
    let temperature2mMin: [Double]
    let precipitationProbabilityMax: [Int]
    let sunrise: [String]
    let sunset: [String]
    let uvIndexMax: [Double]?
    let windSpeed10mMax: [Double]?
    let windGusts10mMax: [Double]?
    let windDirection10mDominant: [Int]?
    let sunshineDuration: [Double]?
    let daylightDuration: [Double]?
    let precipitationSum: [Double]?
    let precipitationHours: [Double]?

    enum CodingKeys: String, CodingKey {
        case time
        case weatherCode = "weather_code"
        case temperature2mMax = "temperature_2m_max"
        case temperature2mMin = "temperature_2m_min"
        case precipitationProbabilityMax = "precipitation_probability_max"
        case sunrise, sunset
        case uvIndexMax = "uv_index_max"
        case windSpeed10mMax = "wind_speed_10m_max"
        case windGusts10mMax = "wind_gusts_10m_max"
        case windDirection10mDominant = "wind_direction_10m_dominant"
        case sunshineDuration = "sunshine_duration"
        case daylightDuration = "daylight_duration"
        case precipitationSum = "precipitation_sum"
        case precipitationHours = "precipitation_hours"
    }
}

// MARK: - Open-Meteo Air Quality API Response

struct AirQualityResponse: Codable {
    let latitude: Double
    let longitude: Double
    let hourly: AirQualityHourly?
}

struct AirQualityHourly: Codable {
    let time: [String]
    let europeanAqi: [Int?]?
    let usAqi: [Int?]?
    let pm25: [Double?]?
    let pm10: [Double?]?
    let alderPollen: [Double?]?
    let birchPollen: [Double?]?
    let grassPollen: [Double?]?
    let mugwortPollen: [Double?]?
    let olivePollen: [Double?]?
    let ragweedPollen: [Double?]?

    enum CodingKeys: String, CodingKey {
        case time
        case europeanAqi = "european_aqi"
        case usAqi = "us_aqi"
        case pm25 = "pm2_5"
        case pm10
        case alderPollen = "alder_pollen"
        case birchPollen = "birch_pollen"
        case grassPollen = "grass_pollen"
        case mugwortPollen = "mugwort_pollen"
        case olivePollen = "olive_pollen"
        case ragweedPollen = "ragweed_pollen"
    }
}

// MARK: - App Models

struct DayPhaseWeather: Identifiable {
    let id = UUID()
    let phase: DayPhase
    let temperature: Double
    let feelsLike: Double
    let weatherCode: Int
    let precipChance: Int
    let humidity: Int
    let windSpeed: Double?
    let uvIndex: Double?
}

enum DayPhase: String, CaseIterable {
    case morning = "Morning"
    case afternoon = "Afternoon"
    case evening = "Evening"
    case night = "Night"

    var icon: String {
        switch self {
        case .morning: return "sunrise.fill"
        case .afternoon: return "sun.max.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }

    var hourRange: ClosedRange<Int> {
        switch self {
        case .morning: return 6...11
        case .afternoon: return 12...17
        case .evening: return 18...21
        case .night: return 22...29
        }
    }
}

// MARK: - Precipitation Timeline

struct PrecipitationTimeline {
    let slots: [PrecipSlot]
    let summary: String
    let isRaining: Bool
    let nextChangeTime: Date?
    let nextChangeLabel: String?
    let maxIntensity: Double
}

struct PrecipSlot: Identifiable {
    let id = UUID()
    let time: Date
    let precipitation: Double // total (rain + snow) in user's unit
    let rain: Double
    let snowfall: Double
    let intensity: PrecipIntensity
}

enum PrecipIntensity: String {
    case none = "None"
    case light = "Light"
    case moderate = "Moderate"
    case heavy = "Heavy"

    /// Threshold in mm (API always returns mm for minutely_15 regardless of unit param)
    static func from(mmPer15min: Double) -> PrecipIntensity {
        switch mmPer15min {
        case ..<0.1: return .none
        case 0.1..<0.5: return .light
        case 0.5..<2.0: return .moderate
        default: return .heavy
        }
    }

    var color: String {
        switch self {
        case .none: return "4A5568"
        case .light: return "63B3ED"
        case .moderate: return "4299E1"
        case .heavy: return "2B6CB0"
        }
    }
}

// MARK: - Wind Info

struct WindInfo {
    let speed: Double
    let gusts: Double
    let direction: Int // degrees
    let beaufort: BeaufortScale

    var compassDirection: String {
        let directions = ["N", "NNE", "NE", "ENE", "E", "ESE", "SE", "SSE",
                          "S", "SSW", "SW", "WSW", "W", "WNW", "NW", "NNW"]
        let index = Int((Double(direction) + 11.25) / 22.5) % 16
        return directions[index]
    }

    var directionDescription: String {
        "\(compassDirection) \(direction)°"
    }
}

/// Beaufort Wind Scale (thresholds in mph)
enum BeaufortScale: Int, CaseIterable {
    case calm = 0
    case lightAir = 1
    case lightBreeze = 2
    case gentleBreeze = 3
    case moderateBreeze = 4
    case freshBreeze = 5
    case strongBreeze = 6
    case nearGale = 7
    case gale = 8
    case strongGale = 9
    case storm = 10
    case violentStorm = 11
    case hurricane = 12

    var name: String {
        switch self {
        case .calm: return "Calm"
        case .lightAir: return "Light Air"
        case .lightBreeze: return "Light Breeze"
        case .gentleBreeze: return "Gentle Breeze"
        case .moderateBreeze: return "Moderate Breeze"
        case .freshBreeze: return "Fresh Breeze"
        case .strongBreeze: return "Strong Breeze"
        case .nearGale: return "Near Gale"
        case .gale: return "Gale"
        case .strongGale: return "Strong Gale"
        case .storm: return "Storm"
        case .violentStorm: return "Violent Storm"
        case .hurricane: return "Hurricane"
        }
    }

    var description: String {
        switch self {
        case .calm: return "Smoke rises vertically"
        case .lightAir: return "Smoke drifts slowly"
        case .lightBreeze: return "Wind felt on face, leaves rustle"
        case .gentleBreeze: return "Leaves and twigs in motion"
        case .moderateBreeze: return "Raises dust and loose paper"
        case .freshBreeze: return "Small trees begin to sway"
        case .strongBreeze: return "Large branches in motion"
        case .nearGale: return "Whole trees in motion"
        case .gale: return "Twigs break off trees"
        case .strongGale: return "Slight structural damage"
        case .storm: return "Trees uprooted"
        case .violentStorm: return "Widespread damage"
        case .hurricane: return "Devastation"
        }
    }

    var icon: String {
        switch self {
        case .calm: return "wind"
        case .lightAir, .lightBreeze: return "wind"
        case .gentleBreeze, .moderateBreeze: return "wind"
        case .freshBreeze, .strongBreeze: return "wind"
        case .nearGale, .gale: return "wind"
        case .strongGale, .storm: return "tropicalstorm"
        case .violentStorm, .hurricane: return "hurricane"
        }
    }

    /// Classify wind speed. Input is in the user's chosen unit — normalize to mph first.
    static func from(speedMph: Double) -> BeaufortScale {
        switch speedMph {
        case ..<1: return .calm
        case 1..<4: return .lightAir
        case 4..<8: return .lightBreeze
        case 8..<13: return .gentleBreeze
        case 13..<19: return .moderateBreeze
        case 19..<25: return .freshBreeze
        case 25..<32: return .strongBreeze
        case 32..<39: return .nearGale
        case 39..<47: return .gale
        case 47..<55: return .strongGale
        case 55..<64: return .storm
        case 64..<73: return .violentStorm
        default: return .hurricane
        }
    }
}

// MARK: - Pressure Trend

struct PressureInfo {
    let currentPressure: Double // hPa from API
    let pressureIn10h: Double
    let trend: PressureTrend
    let hourlyReadings: [(date: Date, pressure: Double)] // for mini chart
}

enum PressureTrend: String {
    case risingFast = "Rising Fast"
    case rising = "Rising"
    case stable = "Stable"
    case falling = "Falling"
    case fallingFast = "Falling Fast"

    var icon: String {
        switch self {
        case .risingFast: return "arrow.up.circle.fill"
        case .rising: return "arrow.up.right.circle.fill"
        case .stable: return "equal.circle.fill"
        case .falling: return "arrow.down.right.circle.fill"
        case .fallingFast: return "arrow.down.circle.fill"
        }
    }

    var color: String {
        switch self {
        case .risingFast: return "60A5FA"   // blue
        case .rising: return "34D399"       // green
        case .stable: return "A0AEC0"       // gray
        case .falling: return "FBBF24"      // yellow
        case .fallingFast: return "F87171"  // red
        }
    }

    /// Classify based on hPa change over 10 hours
    /// Meteorological convention: >6 hPa/10h = fast, 2-6 = gradual, <2 = stable
    static func from(change: Double) -> PressureTrend {
        switch change {
        case 6...: return .risingFast
        case 2..<6: return .rising
        case -2..<2: return .stable
        case -6 ..< -2: return .falling
        default: return .fallingFast
        }
    }
}

struct HourlyForecast: Identifiable, Equatable {
    let id = UUID()
    let time: Date
    let temperature: Double
    let feelsLike: Double
    let precipChance: Int
    let precipAmount: Double
    let weatherCode: Int
    let pressure: Double
    let humidity: Int
    let visibility: Double
    let windSpeed: Double
    let uvIndex: Double
}

struct DailyForecast: Identifiable {
    let id = UUID()
    let date: Date
    let weatherCode: Int
    let tempHigh: Double
    let tempLow: Double
    let precipChance: Int
    let uvIndexMax: Double
    let sunshineDuration: Double // seconds
    let daylightDuration: Double // seconds
    let precipSum: Double
    let precipHours: Double
    let windSpeedMax: Double
    let windGustsMax: Double
    let windDirectionDominant: Int
    let sunrise: String
    let sunset: String
}

struct AirQualityInfo {
    let aqi: Int
    let pm25: Double
    let pm10: Double
    let level: AQILevel
    let pollenSummary: PollenSummary?
}

enum AQILevel: String {
    case good = "Good"
    case fair = "Fair"
    case moderate = "Moderate"
    case poor = "Poor"
    case veryPoor = "Very Poor"
    case hazardous = "Hazardous"

    var color: String {
        switch self {
        case .good: return "34D399"
        case .fair: return "60A5FA"
        case .moderate: return "FBBF24"
        case .poor: return "FB923C"
        case .veryPoor: return "F87171"
        case .hazardous: return "A855F7"
        }
    }

    var icon: String {
        switch self {
        case .good: return "aqi.low"
        case .fair: return "aqi.medium"
        case .moderate: return "aqi.medium"
        case .poor: return "aqi.high"
        case .veryPoor: return "aqi.high"
        case .hazardous: return "aqi.high"
        }
    }

    static func from(usAqi: Int) -> AQILevel {
        switch usAqi {
        case 0...50: return .good
        case 51...100: return .fair
        case 101...150: return .moderate
        case 151...200: return .poor
        case 201...300: return .veryPoor
        default: return .hazardous
        }
    }
}

struct PollenSummary {
    let grassLevel: PollenLevel
    let treeLevel: PollenLevel
    let weedLevel: PollenLevel

    var overallLevel: PollenLevel {
        [grassLevel, treeLevel, weedLevel].max(by: { $0.rawValue < $1.rawValue }) ?? .none
    }
}

enum PollenLevel: Int, Comparable {
    case none = 0
    case low = 1
    case moderate = 2
    case high = 3
    case veryHigh = 4

    static func < (lhs: PollenLevel, rhs: PollenLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }

    var label: String {
        switch self {
        case .none: return "None"
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        case .veryHigh: return "Very High"
        }
    }

    var color: String {
        switch self {
        case .none: return "34D399"
        case .low: return "60A5FA"
        case .moderate: return "FBBF24"
        case .high: return "FB923C"
        case .veryHigh: return "F87171"
        }
    }

    /// Grains/m³ thresholds (approximate, varies by species)
    static func from(grainsPerM3: Double) -> PollenLevel {
        switch grainsPerM3 {
        case ..<1: return .none
        case 1..<25: return .low
        case 25..<50: return .moderate
        case 50..<100: return .high
        default: return .veryHigh
        }
    }
}

// MARK: - Comfort Index

struct ComfortInfo {
    let dewPoint: Double
    let humidity: Int
    let level: ComfortLevel
}

enum ComfortLevel: String {
    case dry = "Dry"
    case comfortable = "Comfortable"
    case pleasant = "Pleasant"
    case sticky = "Slightly Humid"
    case humid = "Humid"
    case muggy = "Muggy"
    case oppressive = "Oppressive"

    var icon: String {
        switch self {
        case .dry: return "drop.triangle"
        case .comfortable, .pleasant: return "face.smiling"
        case .sticky: return "humidity"
        case .humid, .muggy: return "humidity.fill"
        case .oppressive: return "thermometer.sun.fill"
        }
    }

    var color: String {
        switch self {
        case .dry: return "FB923C"
        case .comfortable: return "34D399"
        case .pleasant: return "60A5FA"
        case .sticky: return "FBBF24"
        case .humid: return "FB923C"
        case .muggy: return "F87171"
        case .oppressive: return "A855F7"
        }
    }

    /// Based on dew point in Fahrenheit
    static func from(dewPointF: Double) -> ComfortLevel {
        switch dewPointF {
        case ..<40: return .dry
        case 40..<50: return .comfortable
        case 50..<55: return .pleasant
        case 55..<60: return .sticky
        case 60..<65: return .humid
        case 65..<70: return .muggy
        default: return .oppressive
        }
    }
}

// MARK: - Cloud Cover

struct CloudCoverInfo {
    let total: Int
    let low: Int
    let mid: Int
    let high: Int
    let hourlyReadings: [(date: Date, total: Int, low: Int, mid: Int, high: Int)]
}

// MARK: - Sunshine Planner

struct SunshineSlot: Identifiable {
    let id = UUID()
    let time: Date
    let cloudCover: Int
    let radiation: Double
    let isSunny: Bool // cloud cover < 40%
}

struct SunshinePlan {
    let todaySunshineDuration: Double // seconds
    let todayDaylightDuration: Double // seconds
    let sunshinePercent: Double
    let slots: [SunshineSlot]
    let bestWindow: (start: Date, end: Date)?
    let summary: String
}

// MARK: - Soil / Gardening

struct GardeningInfo {
    let soilTemp: Double
    let soilMoisture: Double // volumetric %
    let frostRisk: Bool
    let wateringAdvice: String
    let plantingAdvice: String
}

// MARK: - Storm Risk

struct StormRiskInfo {
    let cape: Double // J/kg
    let level: StormRiskLevel
}

enum StormRiskLevel: String {
    case none = "None"
    case marginal = "Marginal"
    case slight = "Slight"
    case moderate = "Moderate"
    case high = "High"

    var color: String {
        switch self {
        case .none: return "34D399"
        case .marginal: return "60A5FA"
        case .slight: return "FBBF24"
        case .moderate: return "FB923C"
        case .high: return "F87171"
        }
    }

    var icon: String {
        switch self {
        case .none: return "cloud.fill"
        case .marginal: return "cloud.bolt"
        case .slight: return "cloud.bolt.fill"
        case .moderate, .high: return "cloud.bolt.rain.fill"
        }
    }

    /// CAPE thresholds in J/kg
    static func from(cape: Double) -> StormRiskLevel {
        switch cape {
        case ..<300: return .none
        case 300..<1000: return .marginal
        case 1000..<2500: return .slight
        case 2500..<4000: return .moderate
        default: return .high
        }
    }
}

// MARK: - Weather Code Helpers

struct WeatherCodeInfo {
    static func description(for code: Int) -> String {
        switch code {
        case 0: return "Clear sky"
        case 1: return "Mainly clear"
        case 2: return "Partly cloudy"
        case 3: return "Overcast"
        case 45, 48: return "Foggy"
        case 51, 53, 55: return "Drizzle"
        case 56, 57: return "Freezing drizzle"
        case 61, 63, 65: return "Rain"
        case 66, 67: return "Freezing rain"
        case 71, 73, 75: return "Snow"
        case 77: return "Snow grains"
        case 80, 81, 82: return "Rain showers"
        case 85, 86: return "Snow showers"
        case 95: return "Thunderstorm"
        case 96, 99: return "Thunderstorm with hail"
        default: return "Unknown"
        }
    }

    static func sfSymbol(for code: Int, isDay: Bool = true) -> String {
        switch code {
        case 0:
            return isDay ? "sun.max.fill" : "moon.stars.fill"
        case 1:
            return isDay ? "sun.min.fill" : "moon.fill"
        case 2:
            return isDay ? "cloud.sun.fill" : "cloud.moon.fill"
        case 3:
            return "cloud.fill"
        case 45, 48:
            return "cloud.fog.fill"
        case 51, 53, 55:
            return "cloud.drizzle.fill"
        case 56, 57:
            return "cloud.sleet.fill"
        case 61, 63, 65:
            return "cloud.rain.fill"
        case 66, 67:
            return "cloud.sleet.fill"
        case 71, 73, 75, 77:
            return "cloud.snow.fill"
        case 80, 81, 82:
            return "cloud.heavyrain.fill"
        case 85, 86:
            return "cloud.snow.fill"
        case 95, 96, 99:
            return "cloud.bolt.rain.fill"
        default:
            return "questionmark.circle"
        }
    }
}
