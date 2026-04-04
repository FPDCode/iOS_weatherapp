import Foundation
import SwiftUI
#if canImport(FoundationModels)
import FoundationModels
#endif

// MARK: - Clothing Advisor (iOS 26 on-device LLM)

/// Generates personalised clothing suggestions using the iOS 26 Foundation Models
/// framework (on-device LLM). Falls back to static advice on older OS versions.
@MainActor
final class ClothingAdvisor: ObservableObject {
    @Published var suggestion: String?
    @Published var isGenerating: Bool = false

    // Debounce: only regenerate when inputs actually change
    private var lastInputHash: Int = 0

    /// Generate clothing advice from current weather conditions.
    func generate(
        temp: Double,
        humidity: Int,
        dewPoint: Double,
        comfortLevel: ComfortLevel,
        windSpeed: Double?,
        uvIndex: Double?,
        isDay: Bool,
        weatherCode: Int
    ) {
        let inputHash = "\(Int(temp))\(humidity)\(comfortLevel)\(Int(windSpeed ?? 0))\(Int(uvIndex ?? 0))\(isDay)\(weatherCode)".hashValue
        guard inputHash != lastInputHash else { return }
        lastInputHash = inputHash

        #if canImport(FoundationModels)
        if #available(iOS 26, *) {
            generateWithLLM(
                temp: temp, humidity: humidity, dewPoint: dewPoint,
                comfortLevel: comfortLevel, windSpeed: windSpeed,
                uvIndex: uvIndex, isDay: isDay, weatherCode: weatherCode
            )
            return
        }
        #endif
        suggestion = Self.staticAdvice(
            temp: temp, comfortLevel: comfortLevel,
            windSpeed: windSpeed, uvIndex: uvIndex
        )
    }

    // MARK: - iOS 26 Foundation Models

    #if canImport(FoundationModels)
    @available(iOS 26, *)
    private func generateWithLLM(
        temp: Double,
        humidity: Int,
        dewPoint: Double,
        comfortLevel: ComfortLevel,
        windSpeed: Double?,
        uvIndex: Double?,
        isDay: Bool,
        weatherCode: Int
    ) {
        isGenerating = true
        suggestion = nil

        Task {
            do {
                let session = LanguageModelSession()

                let units = UnitSettings.shared

                var conditions = "Temperature: \(WeatherFormatters.temperature(temp)), "
                conditions += "Humidity: \(humidity)%, "
                conditions += "Comfort: \(comfortLevel.rawValue)"
                if let wind = windSpeed {
                    conditions += ", Wind: \(Int(wind)) \(units.windSpeed)"
                }
                if let uv = uvIndex {
                    conditions += ", UV Index: \(Int(uv))"
                }
                conditions += ", \(isDay ? "Daytime" : "Nighttime")"
                conditions += ", Weather code: \(weatherCode)"

                let prompt = """
                You are a concise clothing advisor. Given the current weather, suggest \
                what to wear in ONE short sentence (max 15 words). Be specific about \
                clothing items. Do not repeat the weather data back.

                Current conditions: \(conditions)
                """

                let response = try await session.respond(to: prompt)
                self.suggestion = response.content
                self.isGenerating = false
            } catch {
                // Fall back to static advice on any LLM error
                self.suggestion = Self.staticAdvice(
                    temp: temp, comfortLevel: comfortLevel,
                    windSpeed: windSpeed, uvIndex: uvIndex
                )
                self.isGenerating = false
            }
        }
    }
    #endif

    // MARK: - Static fallback (pre-iOS 26)

    static func staticAdvice(
        temp: Double,
        comfortLevel: ComfortLevel,
        windSpeed: Double?,
        uvIndex: Double?
    ) -> String {
        let tempF = UnitSettings.shared.toFahrenheit(temp)
        let isWindy = (windSpeed ?? 0) > 25
        let highUV = (uvIndex ?? 0) >= 6

        var advice: String
        switch tempF {
        case ..<32:
            advice = "Heavy coat, gloves, scarf, and warm layers"
        case 32..<45:
            advice = "Warm jacket, long sleeves, and closed-toe shoes"
        case 45..<60:
            advice = isWindy
                ? "Windbreaker or light jacket with layers"
                : "Light jacket or sweater with long pants"
        case 60..<75:
            switch comfortLevel {
            case .humid, .muggy, .oppressive:
                advice = "Breathable fabrics — cotton tee and shorts"
            default:
                advice = "Comfortable layers — light shirt and pants"
            }
        case 75..<90:
            advice = "Light, breathable clothing — shorts and a tee"
        default:
            advice = "Minimal, loose-fitting, light-colored clothing"
        }

        if highUV {
            advice += ". Sunglasses and sunscreen recommended"
        }
        return advice
    }
}
