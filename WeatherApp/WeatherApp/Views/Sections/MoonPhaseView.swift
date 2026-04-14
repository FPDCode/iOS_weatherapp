import SwiftUI

// MARK: - Moon Phase Card

struct MoonPhaseView: View {
    let date: Date

    private var phase: MoonPhase { MoonPhase.calculate(for: date) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Moon Phase", icon: "moon.fill")

            HStack(spacing: 16) {
                // Moon visual
                ZStack {
                    Circle()
                        .fill(.white.opacity(0.05))
                        .frame(width: 70, height: 70)

                    MoonVisual(illumination: phase.illumination, isWaxing: phase.isWaxing)
                        .frame(width: 50, height: 50)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(phase.name)
                        .font(.title3)
                        .fontWeight(.semibold)

                    Text("\(Int(phase.illumination * 100))% illuminated")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let nextFull = phase.daysUntilFull {
                        Text(nextFull == 0 ? "Full moon tonight" : "Full moon in \(nextFull) days")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }

                    if let nextNew = phase.daysUntilNew {
                        Text(nextNew == 0 ? "New moon tonight" : "New moon in \(nextNew) days")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Spacer()
            }
        }
    }
}

// MARK: - Moon Visual (crescent rendering)

private struct MoonVisual: View {
    let illumination: Double
    let isWaxing: Bool

    var body: some View {
        Canvas { context, size in
            let r = min(size.width, size.height) / 2
            let center = CGPoint(x: size.width / 2, y: size.height / 2)

            // Dark moon base
            context.fill(
                Path(ellipseIn: CGRect(x: center.x - r, y: center.y - r, width: r * 2, height: r * 2)),
                with: .color(.white.opacity(0.08))
            )

            // Lit portion
            let phase = illumination
            if phase > 0.01 {
                var path = Path()
                // Draw lit portion using two arcs
                let sweep = (phase - 0.5) * 2 // -1 to 1
                let controlX = r * CGFloat(sweep) * (isWaxing ? 1 : -1)

                // Full circle arc on one side
                if isWaxing {
                    // Right side lit
                    path.addArc(center: center, radius: r, startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
                    // Left edge shaped by illumination
                    path.addCurve(
                        to: CGPoint(x: center.x, y: center.y - r),
                        control1: CGPoint(x: center.x + controlX, y: center.y + r * 0.55),
                        control2: CGPoint(x: center.x + controlX, y: center.y - r * 0.55)
                    )
                } else {
                    // Left side lit
                    path.addArc(center: center, radius: r, startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: false)
                    path.addCurve(
                        to: CGPoint(x: center.x, y: center.y + r),
                        control1: CGPoint(x: center.x - controlX, y: center.y - r * 0.55),
                        control2: CGPoint(x: center.x - controlX, y: center.y + r * 0.55)
                    )
                }
                path.closeSubpath()

                context.fill(path, with: .color(.white.opacity(0.85)))
            }
        }
    }
}

// MARK: - Moon Phase Detail Sheet

struct MoonPhaseDetailSheet: View {
    let date: Date
    @Environment(\.dismiss) private var dismiss

    private var phase: MoonPhase { MoonPhase.calculate(for: date) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Current phase
                    VStack(spacing: 16) {
                        MoonVisual(illumination: phase.illumination, isWaxing: phase.isWaxing)
                            .frame(width: 100, height: 100)

                        Text(phase.name)
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("\(Int(phase.illumination * 100))% illuminated")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // Upcoming phases
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("UPCOMING PHASES", icon: "calendar")

                        let upcoming = MoonPhase.upcomingPhases(from: date)
                        ForEach(Array(upcoming.enumerated()), id: \.offset) { _, item in
                            HStack(spacing: 12) {
                                Image(systemName: item.icon)
                                    .font(.title3)
                                    .frame(width: 30)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(item.name).font(.subheadline).fontWeight(.medium)
                                    Text(item.dateStr).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                                Text(item.daysAway).font(.caption).foregroundStyle(.tertiary)
                            }
                        }
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))

                    // Moon facts
                    VStack(alignment: .leading, spacing: 12) {
                        sectionLabel("ABOUT MOON PHASES", icon: "info.circle.fill")
                        moonFactRow("moon.fill", "New Moon", "Moon between Earth and Sun — not visible")
                        moonFactRow("moon.lefthalf.filled", "First Quarter", "Right half illuminated — waxing")
                        moonFactRow("circle.fill", "Full Moon", "Fully illuminated — opposite side from Sun")
                        moonFactRow("moon.righthalf.filled", "Last Quarter", "Left half illuminated — waning")
                    }
                    .padding(16)
                    .background(RoundedRectangle(cornerRadius: 16).fill(.white.opacity(0.05)))
                }
                .padding(.horizontal, 4)
            }
            .background(Color(red: 0.04, green: 0.04, blue: 0.06).ignoresSafeArea())
            .preferredColorScheme(.dark)
            .navigationTitle("Moon Phase")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .topBarTrailing) { Button("Done") { dismiss() }.fontWeight(.semibold) } }
        }
    }

    private func moonFactRow(_ icon: String, _ name: String, _ desc: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon).font(.body).foregroundStyle(.white.opacity(0.7)).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(name).font(.subheadline).fontWeight(.medium)
                Text(desc).font(.caption).foregroundStyle(.secondary)
            }
        }
    }
}

// MARK: - Moon Phase Calculation

struct MoonPhase {
    let name: String
    let illumination: Double  // 0.0 = new, 1.0 = full
    let isWaxing: Bool
    let age: Double           // Days into the cycle (0–29.53)
    let daysUntilFull: Int?
    let daysUntilNew: Int?

    /// Calculate moon phase for a given date using the synodic month algorithm
    static func calculate(for date: Date) -> MoonPhase {
        let age = lunarAge(for: date)
        let cycle = 29.53058770576
        let illumination = (1 - cos(2 * .pi * age / cycle)) / 2
        let isWaxing = age < cycle / 2

        let name: String
        switch age {
        case 0..<1.85:     name = "New Moon"
        case 1.85..<5.55:  name = "Waxing Crescent"
        case 5.55..<9.25:  name = "First Quarter"
        case 9.25..<12.95: name = "Waxing Gibbous"
        case 12.95..<16.65: name = "Full Moon"
        case 16.65..<20.35: name = "Waning Gibbous"
        case 20.35..<24.05: name = "Last Quarter"
        case 24.05..<27.75: name = "Waning Crescent"
        default:            name = "New Moon"
        }

        let daysToFull = age < cycle / 2 ? Int(cycle / 2 - age) : Int(cycle + cycle / 2 - age)
        let daysToNew = age > 0.5 ? Int(cycle - age) : 0

        return MoonPhase(
            name: name,
            illumination: illumination,
            isWaxing: isWaxing,
            age: age,
            daysUntilFull: daysToFull > 0 ? daysToFull : nil,
            daysUntilNew: daysToNew > 0 ? daysToNew : nil
        )
    }

    /// Calculate lunar age in days using a known new moon as reference
    private static func lunarAge(for date: Date) -> Double {
        // Reference new moon: January 6, 2000, 18:14 UTC
        let refComponents = DateComponents(
            calendar: Calendar(identifier: .gregorian),
            timeZone: TimeZone(identifier: "UTC"),
            year: 2000, month: 1, day: 6, hour: 18, minute: 14
        )
        let refDate = Calendar(identifier: .gregorian).date(from: refComponents)!
        let daysSinceRef = date.timeIntervalSince(refDate) / 86400
        let cycle = 29.53058770576
        let age = daysSinceRef.truncatingRemainder(dividingBy: cycle)
        return age < 0 ? age + cycle : age
    }

    /// Get the next 4 major phases from a date
    static func upcomingPhases(from date: Date) -> [(name: String, icon: String, dateStr: String, daysAway: String)] {
        let cycle = 29.53058770576
        let age = lunarAge(for: date)
        let formatter = DateFormatter()
        formatter.dateFormat = "MMM d"

        let phases: [(name: String, icon: String, targetAge: Double)] = [
            ("New Moon", "moon.fill", 0),
            ("First Quarter", "moon.lefthalf.filled", cycle / 4),
            ("Full Moon", "circle.fill", cycle / 2),
            ("Last Quarter", "moon.righthalf.filled", cycle * 3 / 4),
        ]

        var results: [(name: String, icon: String, dateStr: String, daysAway: String)] = []
        for phase in phases {
            var daysAway = phase.targetAge - age
            if daysAway <= 0 { daysAway += cycle }
            let phaseDate = date.addingTimeInterval(daysAway * 86400)
            let days = Int(daysAway)
            results.append((
                name: phase.name,
                icon: phase.icon,
                dateStr: formatter.string(from: phaseDate),
                daysAway: days == 0 ? "Today" : "in \(days)d"
            ))
        }

        return results.sorted { a, b in
            // Sort by soonest
            let dA = Int(a.daysAway.filter(\.isNumber)) ?? 0
            let dB = Int(b.daysAway.filter(\.isNumber)) ?? 0
            return dA < dB
        }
    }
}
