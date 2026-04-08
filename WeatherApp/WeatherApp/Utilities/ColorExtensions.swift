import SwiftUI

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let a, r, g, b: UInt64
        switch hex.count {
        case 6:
            (a, r, g, b) = (255, int >> 16, int >> 8 & 0xFF, int & 0xFF)
        case 8:
            (a, r, g, b) = (int >> 24, int >> 16 & 0xFF, int >> 8 & 0xFF, int & 0xFF)
        default:
            (a, r, g, b) = (255, 0, 0, 0)
        }
        self.init(
            .sRGB,
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255,
            opacity: Double(a) / 255
        )
    }
}

// MARK: - iOS 26 Liquid Glass Adaptive Modifier

extension View {
    @ViewBuilder
    func adaptiveGlass(cornerRadius: CGFloat = 16) -> some View {
        if #available(iOS 26, *) {
            self.glassEffect(in: RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        } else {
            self.background(.ultraThinMaterial)
        }
    }
}

// MARK: - Background Gradients

struct BackgroundGradient {
    /// Background gradient that complements the horizon shader header.
    /// Uses darker, more muted tones since the header provides the atmospheric color.
    static func forTimeOfDay(isDay: Bool, weatherCode: Int) -> LinearGradient {
        let hex = topColorHex(isDay: isDay, weatherCode: weatherCode)
        let colors: [Color]

        if !isDay {
            colors = [Color(hex: "0A1520"), Color(hex: "0F1D2B"), Color(hex: "0A1218")]
        } else {
            switch weatherCode {
            case 0, 1:
                colors = [Color(hex: "0D2137"), Color(hex: "132E4A"), Color(hex: "0F1F30")]
            case 2, 3:
                colors = [Color(hex: "1A2730"), Color(hex: "1E2F3A"), Color(hex: "15202A")]
            case 45, 48:
                colors = [Color(hex: "1E2428"), Color(hex: "252B30"), Color(hex: "1A2025")]
            case 51...67:
                colors = [Color(hex: "141D24"), Color(hex: "1A252E"), Color(hex: "111920")]
            case 71...86:
                colors = [Color(hex: "1A2530"), Color(hex: "202D38"), Color(hex: "161F28")]
            case 95, 96, 99:
                colors = [Color(hex: "0C0E18"), Color(hex: "10141F"), Color(hex: "080A12")]
            default:
                colors = [Color(hex: "0D2137"), Color(hex: "132E4A"), Color(hex: "0F1F30")]
            }
        }

        return LinearGradient(colors: colors, startPoint: .top, endPoint: .bottom)
    }

    /// Returns the top gradient stop hex for the given conditions
    private static func topColorHex(isDay: Bool, weatherCode: Int) -> String {
        if !isDay { return "0A1520" }
        switch weatherCode {
        case 0, 1: return "0D2137"
        case 2, 3: return "1A2730"
        case 45, 48: return "1E2428"
        case 51...67: return "141D24"
        case 71...86: return "1A2530"
        case 95, 96, 99: return "0C0E18"
        default: return "0D2137"
        }
    }

    /// RGB floats (0-1) of the top gradient color — used by Metal shader for
    /// seamless ground-to-background transition.
    static func groundColorComponents(isDay: Bool, weatherCode: Int) -> (Float, Float, Float) {
        let hex = topColorHex(isDay: isDay, weatherCode: weatherCode)
        let h = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: h).scanHexInt64(&int)
        let r = Float((int >> 16) & 0xFF) / 255.0
        let g = Float((int >> 8) & 0xFF) / 255.0
        let b = Float(int & 0xFF) / 255.0
        return (r, g, b)
    }
            startPoint: .top,
            endPoint: .bottom
        )
    }
}

// MARK: - Formatters (reads from UnitSettings.shared)

struct WeatherFormatters {
    private static var settings: UnitSettings { UnitSettings.shared }

    static func temperature(_ temp: Double) -> String {
        "\(Int(round(temp)))°"
    }

    static func temperatureFull(_ temp: Double) -> String {
        "\(Int(round(temp)))\(settings.selectedTemperature.symbol)"
    }

    static func percent(_ value: Int) -> String {
        "\(value)%"
    }

    static func precipitation(_ value: Double) -> String {
        switch settings.selectedPrecipitation {
        case .mm:
            if value < 0.1 { return "0 mm" }
            return String(format: "%.1f mm", value)
        case .inches:
            if value < 0.01 { return "0 in" }
            return String(format: "%.2f in", value)
        }
    }

    static func pressure(_ hPa: Double) -> String {
        switch settings.selectedPressure {
        case .inHg:
            let inHg = hPa * 0.02953
            return String(format: "%.2f inHg", inHg)
        case .hPa:
            return String(format: "%.0f hPa", hPa)
        case .mbar:
            return String(format: "%.0f mbar", hPa)
        }
    }

    static func visibility(_ meters: Double) -> String {
        switch settings.selectedVisibility {
        case .miles:
            let miles = meters / 1609.344
            if miles >= 10 { return "\(Int(miles)) mi" }
            return String(format: "%.1f mi", miles)
        case .km:
            let km = meters / 1000
            if km >= 10 { return "\(Int(km)) km" }
            return String(format: "%.1f km", km)
        }
    }

    static func humidity(_ value: Int) -> String {
        "\(value)%"
    }

    static func windSpeed(_ speed: Double) -> String {
        "\(Int(round(speed))) \(settings.selectedWindSpeed.label)"
    }

    // MARK: - Time Formatters (respect 12h/24h preference)

    static func hourTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        switch settings.selectedTimeFormat {
        case .twelve:
            f.dateFormat = "h a"
        case .twentyFour:
            f.dateFormat = "HH:mm"
        }
        return f.string(from: date).lowercased()
    }

    static func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        switch settings.selectedTimeFormat {
        case .twelve:
            f.dateFormat = "h:mm a"
        case .twentyFour:
            f.dateFormat = "HH:mm"
        }
        return f.string(from: date)
    }

    static func dayOfWeek(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EEE"
        return f.string(from: date)
    }

    static func fullDay(_ date: Date) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        f.dateFormat = "EEEE"
        return f.string(from: date)
    }

    static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}
