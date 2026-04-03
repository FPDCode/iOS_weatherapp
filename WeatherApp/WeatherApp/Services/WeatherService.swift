import Foundation

actor WeatherService {
    static let shared = WeatherService()

    private let forecastURL = "https://api.open-meteo.com/v1/forecast"
    private let airQualityURL = "https://air-quality-api.open-meteo.com/v1/air-quality"

    func fetchWeather(latitude: Double, longitude: Double) async throws -> WeatherResponse {
        let settings = await MainActor.run { UnitSettings.shared }

        let tempUnit = await MainActor.run { settings.selectedTemperature.apiValue }
        let windUnit = await MainActor.run { settings.selectedWindSpeed.apiValue }
        let precipUnit = await MainActor.run { settings.selectedPrecipitation.apiValue }

        var components = URLComponents(string: forecastURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: "temperature_2m,apparent_temperature,precipitation_probability,precipitation,weather_code,surface_pressure,relative_humidity_2m,visibility,wind_speed_10m,uv_index"),
            URLQueryItem(name: "daily", value: "weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max,sunrise,sunset,uv_index_max"),
            URLQueryItem(name: "current_weather", value: "true"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "14"),
            URLQueryItem(name: "temperature_unit", value: tempUnit),
            URLQueryItem(name: "windspeed_unit", value: windUnit),
            URLQueryItem(name: "precipitation_unit", value: precipUnit),
        ]

        guard let url = components.url else {
            throw WeatherError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WeatherError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(WeatherResponse.self, from: data)
    }

    func fetchAirQuality(latitude: Double, longitude: Double) async throws -> AirQualityResponse {
        var components = URLComponents(string: airQualityURL)!
        components.queryItems = [
            URLQueryItem(name: "latitude", value: String(latitude)),
            URLQueryItem(name: "longitude", value: String(longitude)),
            URLQueryItem(name: "hourly", value: "european_aqi,us_aqi,pm2_5,pm10,alder_pollen,birch_pollen,grass_pollen,mugwort_pollen,olive_pollen,ragweed_pollen"),
            URLQueryItem(name: "timezone", value: "auto"),
            URLQueryItem(name: "forecast_days", value: "3"),
        ]

        guard let url = components.url else {
            throw WeatherError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WeatherError.invalidResponse
        }

        let decoder = JSONDecoder()
        return try decoder.decode(AirQualityResponse.self, from: data)
    }
}

enum WeatherError: LocalizedError {
    case invalidURL
    case invalidResponse
    case decodingError

    var errorDescription: String? {
        switch self {
        case .invalidURL: return "Invalid URL"
        case .invalidResponse: return "Invalid server response"
        case .decodingError: return "Failed to decode weather data"
        }
    }
}
