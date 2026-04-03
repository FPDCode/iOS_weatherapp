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
    func adaptiveGlass() -> some View {
        if #available(iOS 26, *) {
            self.glassEffect()
        } else {
            self.background(.ultraThinMaterial)
        }
    }
}

// MARK: - Background Gradients

struct BackgroundGradient {
    static func forTimeOfDay(isDay: Bool, weatherCode: Int) -> LinearGradient {
        let colors: [Color]

        if !isDay {
            colors = [Color(hex: "0F2027"), Color(hex: "203A43"), Color(hex: "2C5364")]
        } else {
            switch weatherCode {
            case 0, 1:
                colors = [Color(hex: "2196F3"), Color(hex: "64B5F6"), Color(hex: "90CAF9")]
            case 2, 3:
                colors = [Color(hex: "546E7A"), Color(hex: "78909C"), Color(hex: "90A4AE")]
            case 45, 48:
                colors = [Color(hex: "757575"), Color(hex: "9E9E9E"), Color(hex: "BDBDBD")]
            case 51...67:
                colors = [Color(hex: "37474F"), Color(hex: "455A64"), Color(hex: "546E7A")]
            case 71...86:
                colors = [Color(hex: "607D8B"), Color(hex: "90A4AE"), Color(hex: "CFD8DC")]
            case 95, 96, 99:
                colors = [Color(hex: "1A1A2E"), Color(hex: "16213E"), Color(hex: "0F3460")]
            default:
                colors = [Color(hex: "2196F3"), Color(hex: "64B5F6"), Color(hex: "90CAF9")]
            }
        }

        return LinearGradient(
            colors: colors,
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - Temperature Unit

enum TemperatureUnit: String, CaseIterable {
    case fahrenheit
    case celsius

    var symbol: String {
        self == .fahrenheit ? "F" : "C"
    }

    var apiValue: String {
        rawValue
    }
}

// MARK: - Formatters

struct WeatherFormatters {
    static func temperature(_ temp: Double) -> String {
        "\(Int(round(temp)))°"
    }

    static func temperatureFull(_ temp: Double, unit: TemperatureUnit = .fahrenheit) -> String {
        "\(Int(round(temp)))°\(unit.symbol)"
    }

    static func percent(_ value: Int) -> String {
        "\(value)%"
    }

    static func precipitation(_ mm: Double) -> String {
        if mm < 0.01 { return "0 in" }
        let inches = mm / 25.4
        return String(format: "%.2f in", inches)
    }

    static func pressure(_ hPa: Double) -> String {
        let inHg = hPa * 0.02953
        return String(format: "%.2f inHg", inHg)
    }

    static func visibility(_ meters: Double) -> String {
        let miles = meters / 1609.344
        if miles >= 10 {
            return "\(Int(miles)) mi"
        }
        return String(format: "%.1f mi", miles)
    }

    static func humidity(_ value: Int) -> String {
        "\(value)%"
    }

    static func windSpeed(_ mph: Double) -> String {
        "\(Int(round(mph))) mph"
    }

    private static let hourFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "ha"
        return f
    }()

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE"
        return f
    }()

    private static let fullDayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEEE"
        return f
    }()

    static func hourTime(_ date: Date) -> String {
        hourFormatter.string(from: date).lowercased()
    }

    static func dayOfWeek(_ date: Date) -> String {
        dayFormatter.string(from: date)
    }

    static func fullDay(_ date: Date) -> String {
        fullDayFormatter.string(from: date)
    }

    static func isToday(_ date: Date) -> Bool {
        Calendar.current.isDateInToday(date)
    }
}
