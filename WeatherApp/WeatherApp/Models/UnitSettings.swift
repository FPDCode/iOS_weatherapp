import Foundation
import SwiftUI

// MARK: - Unit Enums

enum TemperatureUnit: String, CaseIterable {
    case fahrenheit
    case celsius

    var symbol: String { self == .fahrenheit ? "°F" : "°C" }
    var shortSymbol: String { self == .fahrenheit ? "F" : "C" }
    var apiValue: String { rawValue }
}

enum WindSpeedUnit: String, CaseIterable {
    case mph
    case kmh
    case ms

    var label: String {
        switch self {
        case .mph: return "mph"
        case .kmh: return "km/h"
        case .ms: return "m/s"
        }
    }

    var apiValue: String {
        switch self {
        case .mph: return "mph"
        case .kmh: return "kmh"
        case .ms: return "ms"
        }
    }
}

enum PrecipitationUnit: String, CaseIterable {
    case inches
    case mm

    var label: String { self == .inches ? "in" : "mm" }
    var apiValue: String { self == .inches ? "inch" : "mm" }
}

enum PressureUnit: String, CaseIterable {
    case inHg
    case hPa
    case mbar

    var label: String { rawValue }
}

enum VisibilityUnit: String, CaseIterable {
    case miles
    case km

    var label: String { self == .miles ? "mi" : "km" }
}

enum TimeFormatPref: String, CaseIterable {
    case twelve = "12h"
    case twentyFour = "24h"

    var displayName: String {
        self == .twelve ? "12-hour" : "24-hour"
    }
}

enum MeasurementSystem: String, CaseIterable {
    case imperial = "Imperial"
    case metric = "Metric"
    case ukMixed = "UK"
    case custom = "Custom"
}

// MARK: - UnitSettings (Single Source of Truth)

class UnitSettings: ObservableObject {
    static let shared = UnitSettings()

    @AppStorage("unit_temperature") var temperature: String = TemperatureUnit.fahrenheit.rawValue
    @AppStorage("unit_windSpeed") var windSpeed: String = WindSpeedUnit.mph.rawValue
    @AppStorage("unit_precipitation") var precipitation: String = PrecipitationUnit.inches.rawValue
    @AppStorage("unit_pressure") var pressure: String = PressureUnit.inHg.rawValue
    @AppStorage("unit_visibility") var visibility: String = VisibilityUnit.miles.rawValue
    @AppStorage("unit_timeFormat") var timeFormat: String = TimeFormatPref.twelve.rawValue
    @AppStorage("unit_system") var measurementSystem: String = MeasurementSystem.imperial.rawValue
    @AppStorage("hasAutoDetectedLocale") var hasAutoDetectedLocale: Bool = false

    // Typed accessors
    var selectedTemperature: TemperatureUnit { TemperatureUnit(rawValue: temperature) ?? .fahrenheit }
    var selectedWindSpeed: WindSpeedUnit { WindSpeedUnit(rawValue: windSpeed) ?? .mph }
    var selectedPrecipitation: PrecipitationUnit { PrecipitationUnit(rawValue: precipitation) ?? .inches }
    var selectedPressure: PressureUnit { PressureUnit(rawValue: pressure) ?? .inHg }
    var selectedVisibility: VisibilityUnit { VisibilityUnit(rawValue: visibility) ?? .miles }
    var selectedTimeFormat: TimeFormatPref { TimeFormatPref(rawValue: timeFormat) ?? .twelve }
    var selectedSystem: MeasurementSystem { MeasurementSystem(rawValue: measurementSystem) ?? .imperial }

    /// Combined string of API-affecting units — watch this to know when to refetch
    var apiSignature: String {
        "\(temperature)|\(windSpeed)|\(precipitation)"
    }

    // MARK: - Locale Auto-Detection

    func autoDetectFromLocale() {
        guard !hasAutoDetectedLocale else { return }

        let regionCode = Locale.current.region?.identifier ?? ""

        switch regionCode {
        case "US":
            applySystem(.imperial)
        case "GB":
            applySystem(.ukMixed)
        default:
            // Check if the locale uses metric
            let usesMetric = Locale.current.measurementSystem == .metric
            applySystem(usesMetric ? .metric : .imperial)
        }

        hasAutoDetectedLocale = true
    }

    // MARK: - Apply System

    func applySystem(_ system: MeasurementSystem) {
        switch system {
        case .imperial:
            temperature = TemperatureUnit.fahrenheit.rawValue
            windSpeed = WindSpeedUnit.mph.rawValue
            precipitation = PrecipitationUnit.inches.rawValue
            pressure = PressureUnit.inHg.rawValue
            visibility = VisibilityUnit.miles.rawValue
            timeFormat = TimeFormatPref.twelve.rawValue
        case .metric:
            temperature = TemperatureUnit.celsius.rawValue
            windSpeed = WindSpeedUnit.kmh.rawValue
            precipitation = PrecipitationUnit.mm.rawValue
            pressure = PressureUnit.hPa.rawValue
            visibility = VisibilityUnit.km.rawValue
            timeFormat = TimeFormatPref.twentyFour.rawValue
        case .ukMixed:
            temperature = TemperatureUnit.celsius.rawValue
            windSpeed = WindSpeedUnit.mph.rawValue
            precipitation = PrecipitationUnit.mm.rawValue
            pressure = PressureUnit.hPa.rawValue
            visibility = VisibilityUnit.miles.rawValue
            timeFormat = TimeFormatPref.twentyFour.rawValue
        case .custom:
            break // Don't change individual settings
        }
        measurementSystem = system.rawValue
    }

    /// Call when any individual unit is changed manually
    func markCustomIfNeeded() {
        // Check if current settings match any preset
        let isImperial = temperature == TemperatureUnit.fahrenheit.rawValue
            && windSpeed == WindSpeedUnit.mph.rawValue
            && precipitation == PrecipitationUnit.inches.rawValue
            && pressure == PressureUnit.inHg.rawValue
            && visibility == VisibilityUnit.miles.rawValue
            && timeFormat == TimeFormatPref.twelve.rawValue

        let isMetric = temperature == TemperatureUnit.celsius.rawValue
            && windSpeed == WindSpeedUnit.kmh.rawValue
            && precipitation == PrecipitationUnit.mm.rawValue
            && pressure == PressureUnit.hPa.rawValue
            && visibility == VisibilityUnit.km.rawValue
            && timeFormat == TimeFormatPref.twentyFour.rawValue

        let isUK = temperature == TemperatureUnit.celsius.rawValue
            && windSpeed == WindSpeedUnit.mph.rawValue
            && precipitation == PrecipitationUnit.mm.rawValue
            && pressure == PressureUnit.hPa.rawValue
            && visibility == VisibilityUnit.miles.rawValue
            && timeFormat == TimeFormatPref.twentyFour.rawValue

        if isImperial {
            measurementSystem = MeasurementSystem.imperial.rawValue
        } else if isMetric {
            measurementSystem = MeasurementSystem.metric.rawValue
        } else if isUK {
            measurementSystem = MeasurementSystem.ukMixed.rawValue
        } else {
            measurementSystem = MeasurementSystem.custom.rawValue
        }
    }

    // MARK: - Temperature Threshold Helpers (for MorningBriefing/ActivityScorer)

    /// Convert a Fahrenheit threshold to the current temperature unit
    func threshold(fahrenheit f: Double) -> Double {
        if selectedTemperature == .celsius {
            return (f - 32) * 5 / 9
        }
        return f
    }

    /// Convert the API-returned temperature back to Fahrenheit for internal scoring
    func toFahrenheit(_ temp: Double) -> Double {
        if selectedTemperature == .celsius {
            return temp * 9 / 5 + 32
        }
        return temp
    }

    /// Convert the API-returned wind speed back to mph for internal scoring
    func toMph(_ speed: Double) -> Double {
        switch selectedWindSpeed {
        case .mph: return speed
        case .kmh: return speed / 1.60934
        case .ms: return speed * 2.23694
        }
    }
}
