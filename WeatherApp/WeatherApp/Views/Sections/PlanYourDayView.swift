import SwiftUI

struct PlanYourDayView: View {
    @EnvironmentObject var weatherViewModel: WeatherViewModel
    @EnvironmentObject var locationService: LocationService
    @StateObject private var calendarService = CalendarService()
    @AppStorage("commuteOutHour") var commuteOutHour: Int = 8
    @AppStorage("commuteReturnHour") var commuteReturnHour: Int = 18
    @State private var selectedActivity: OutdoorActivity = .running
    @State private var scoredWindows: [ScoredActivityWindow] = []
    @State private var briefing: MorningBriefing?
    @State private var showComfortDetail = false
    @State private var showGardenDetail = false

    var body: some View {
        NavigationStack {
            ZStack {
                BackgroundGradient.forTimeOfDay(
                    isDay: weatherViewModel.isDay,
                    weatherCode: weatherViewModel.currentWeatherCode
                )
                .ignoresSafeArea()

                if weatherViewModel.isLoading {
                    ProgressView()
                        .tint(.white)
                } else {
                    mainContent
                }
            }
            .preferredColorScheme(.dark)
            .navigationTitle(locationService.cityName)
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.visible, for: .navigationBar)
        }
        .onAppear {
            calendarService.requestAccess()
            generatePlan()
        }
        .onChange(of: weatherViewModel.hourlyForecasts) { _, _ in
            generatePlan()
        }
        .onChange(of: calendarService.hasCalendarAccess) { _, _ in
            generatePlan()
        }
        .sheet(isPresented: $showComfortDetail) {
            if let comfort = weatherViewModel.comfortInfo {
                ComfortDetailSheet(
                    comfort: comfort,
                    temp: weatherViewModel.currentTemp,
                    feelsLike: weatherViewModel.hourlyForecasts.first?.feelsLike,
                    humidity: comfort.humidity
                )
            }
        }
        .sheet(isPresented: $showGardenDetail) {
            if let garden = weatherViewModel.gardeningInfo {
                GardeningDetailSheet(info: garden)
            }
        }
    }

    private func generatePlan() {
        guard !weatherViewModel.hourlyForecasts.isEmpty else { return }

        // Generate morning briefing
        briefing = MorningBriefing.generate(
            phases: weatherViewModel.todayPhases,
            hourly: weatherViewModel.hourlyForecasts,
            high: weatherViewModel.todayHigh,
            low: weatherViewModel.todayLow,
            sunrise: weatherViewModel.sunrise,
            sunset: weatherViewModel.sunset,
            commuteOutHour: commuteOutHour,
            commuteReturnHour: commuteReturnHour
        )

        // Score activities over the next 36 hours
        let slots = calendarService.findFreeSlots(forNextHours: 36)
        scoredWindows = ActivityScorer.scoreActivities(
            slots: slots,
            hourlyForecasts: weatherViewModel.hourlyForecasts
        )
    }

    private var mainContent: some View {
        ScrollView(.vertical, showsIndicators: false) {
            VStack(spacing: 16) {
                // Weather alerts
                if let briefing, !briefing.alerts.isEmpty {
                    GlassCard {
                        AlertsSection(alerts: briefing.alerts)
                    }
                }

                // Morning briefing
                if let briefing {
                    GlassCard {
                        MorningBriefingSection(briefing: briefing)
                    }
                }

                // Commute snapshot
                if let briefing, (briefing.commuteOut != nil || briefing.commuteReturn != nil) {
                    GlassCard {
                        CommuteSection(briefing: briefing)
                    }
                }

                // Sunshine planner
                if let plan = weatherViewModel.sunshinePlan {
                    GlassCard {
                        SunshinePlannerView(plan: plan)
                    }
                }

                // Activity planner
                GlassCard {
                    ActivityPlannerSection(
                        selectedActivity: $selectedActivity,
                        scoredWindows: filteredWindows,
                        hasCalendarAccess: calendarService.hasCalendarAccess,
                        onRequestAccess: { calendarService.requestAccess() }
                    )
                }

                // Best time summary for each activity
                GlassCard {
                    BestTimeSummary(allWindows: scoredWindows)
                }

                // Comfort Level
                if let comfort = weatherViewModel.comfortInfo {
                    GlassCard {
                        ComfortIndexView(
                            comfort: comfort,
                            temp: weatherViewModel.currentTemp,
                            feelsLike: weatherViewModel.hourlyForecasts.first?.feelsLike,
                            windSpeed: weatherViewModel.windInfo?.speed,
                            uvIndex: weatherViewModel.todayUVIndex,
                            isDay: weatherViewModel.isDay,
                            weatherCode: weatherViewModel.currentWeatherCode
                        )
                    }
                    .onTapGesture { UIImpactFeedbackGenerator(style: .light).impactOccurred(); showComfortDetail = true }
                }

                // Garden & Soil
                if let garden = weatherViewModel.gardeningInfo {
                    GlassCard {
                        GardeningView(info: garden)
                    }
                    .onTapGesture { UIImpactFeedbackGenerator(style: .light).impactOccurred(); showGardenDetail = true }
                }

                Text("Weather data from Open-Meteo.com")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .padding(.top, 8)
                    .padding(.bottom, 40)
            }
            .padding(.horizontal, 16)
            .padding(.top, 8)
        }
    }

    private var filteredWindows: [ScoredActivityWindow] {
        scoredWindows.filter { $0.activity == selectedActivity }
    }
}

// MARK: - Alerts Section

struct AlertsSection: View {
    let alerts: [WeatherAlert]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            SectionHeader(title: "Alerts", icon: "exclamationmark.triangle.fill")

            ForEach(alerts) { alert in
                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: alert.icon)
                        .font(.body)
                        .foregroundStyle(alert.severity == .warning ? .red : .orange)
                        .frame(width: 28)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(alert.message)
                            .font(.subheadline)

                        if let timing = alert.timing {
                            Text(timing)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}

// MARK: - Morning Briefing Section

struct MorningBriefingSection: View {
    let briefing: MorningBriefing

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Getting Ready", icon: "tshirt.fill")

            // Clothing
            HStack(alignment: .top, spacing: 12) {
                Image(systemName: briefing.clothingSuggestion.icon)
                    .font(.title2)
                    .symbolRenderingMode(.multicolor)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 4) {
                    Text(briefing.clothingSuggestion.layers)
                        .font(.subheadline)
                        .fontWeight(.medium)

                    if !briefing.clothingSuggestion.extras.isEmpty {
                        FlowLayout(spacing: 6) {
                            ForEach(briefing.clothingSuggestion.extras, id: \.self) { extra in
                                Text(extra)
                                    .font(.caption)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(.white.opacity(0.1))
                                    .clipShape(Capsule())
                            }
                        }
                    }
                }
            }

            Divider().background(.white.opacity(0.1))

            // Umbrella
            HStack(spacing: 12) {
                Image(systemName: briefing.umbrellaNeeded ? "umbrella.fill" : "umbrella")
                    .font(.title3)
                    .foregroundStyle(briefing.umbrellaNeeded ? .blue : .secondary)
                    .frame(width: 36)

                VStack(alignment: .leading, spacing: 2) {
                    Text(briefing.umbrellaNeeded ? "Bring an umbrella" : "No umbrella needed")
                        .font(.subheadline)
                        .fontWeight(.medium)
                    Text("Max \(briefing.maxPrecipToday)% rain chance today")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Divider().background(.white.opacity(0.1))

            // Daylight
            HStack(spacing: 12) {
                Image(systemName: "sunrise.fill")
                    .font(.title3)
                    .foregroundStyle(.orange)
                    .frame(width: 36)

                Text(briefing.sunriseSunset)
                    .font(.subheadline)
            }
        }
    }
}

// MARK: - Commute Section

struct CommuteSection: View {
    let briefing: MorningBriefing

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Commute Weather", icon: "car.fill")

            HStack(spacing: 16) {
                if let commute = briefing.commuteOut {
                    CommuteCard(commute: commute)
                }
                if let commute = briefing.commuteReturn {
                    CommuteCard(commute: commute)
                }
            }
        }
    }
}

struct CommuteCard: View {
    let commute: CommuteForecast

    var body: some View {
        VStack(spacing: 6) {
            Text(commute.label)
                .font(.caption)
                .foregroundStyle(.secondary)

            Image(systemName: WeatherCodeInfo.sfSymbol(for: commute.forecast.weatherCode))
                .font(.title2)
                .symbolRenderingMode(.multicolor)

            Text(WeatherFormatters.temperature(commute.forecast.temperature))
                .font(.title3)
                .fontWeight(.semibold)

            if commute.forecast.precipChance > 10 {
                HStack(spacing: 2) {
                    Image(systemName: "drop.fill")
                        .font(.system(size: 8))
                        .foregroundStyle(.blue)
                    Text("\(commute.forecast.precipChance)%")
                        .font(.caption2)
                        .foregroundStyle(.blue)
                }
            }

            Text(commute.time)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .background(
            RoundedRectangle(cornerRadius: 12, style: .continuous)
                .fill(.white.opacity(0.08))
        )
    }
}

// MARK: - Activity Planner

struct ActivityPlannerSection: View {
    @Binding var selectedActivity: OutdoorActivity
    let scoredWindows: [ScoredActivityWindow]
    let hasCalendarAccess: Bool
    let onRequestAccess: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Best Time For (Next 36h)", icon: "figure.run")

            // Activity picker
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(OutdoorActivity.allCases) { activity in
                        ActivityPill(
                            activity: activity,
                            isSelected: selectedActivity == activity
                        )
                        .onTapGesture {
                            UIImpactFeedbackGenerator(style: .light).impactOccurred()
                            withAnimation(.easeInOut(duration: 0.2)) {
                                selectedActivity = activity
                            }
                        }
                    }
                }
            }

            // Calendar access prompt
            if !hasCalendarAccess {
                HStack(spacing: 8) {
                    Image(systemName: "calendar.badge.plus")
                        .foregroundStyle(.blue)
                    Text("Connect calendar for personalized time slots")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button("Allow") {
                        onRequestAccess()
                    }
                    .font(.caption)
                    .buttonStyle(.bordered)
                    .tint(.blue)
                }
                .padding(.vertical, 4)
            }

            // Scored windows (next 36 hours)
            if scoredWindows.isEmpty {
                Text("No suitable time slots found for \(selectedActivity.rawValue.lowercased()) in the next 36 hours")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding(.vertical, 16)
            } else {
                let top = Array(scoredWindows.prefix(6))
                let grouped = Dictionary(grouping: top) { window in
                    Calendar.current.startOfDay(for: window.slot.start)
                }
                let sortedDays = grouped.keys.sorted()

                ForEach(sortedDays, id: \.self) { day in
                    if sortedDays.count > 1 {
                        Text(dayLabel(for: day))
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundStyle(.secondary)
                            .padding(.top, 4)
                    }
                    ForEach(grouped[day] ?? []) { window in
                        ActivityWindowRow(window: window)
                    }
                }
            }
        }
    }

    private func dayLabel(for day: Date) -> String {
        let calendar = Calendar.current
        if calendar.isDateInToday(day) {
            return "Today"
        } else if calendar.isDateInTomorrow(day) {
            return "Tomorrow"
        } else {
            let formatter = DateFormatter()
            formatter.dateFormat = "EEEE, MMM d"
            return formatter.string(from: day)
        }
    }
}

struct ActivityPill: View {
    let activity: OutdoorActivity
    let isSelected: Bool

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: activity.icon)
                .font(.caption2)
            Text(activity.rawValue)
                .font(.caption)
                .fontWeight(.medium)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(
            Capsule()
                .fill(isSelected ? .white.opacity(0.25) : .white.opacity(0.08))
        )
        .overlay(
            Capsule()
                .stroke(.white.opacity(isSelected ? 0.4 : 0.1), lineWidth: 1)
        )
    }
}

struct ActivityWindowRow: View {
    let window: ScoredActivityWindow

    var body: some View {
        HStack(spacing: 12) {
            // Score badge
            ZStack {
                Circle()
                    .fill(Color(hex: window.rating.color).opacity(0.2))
                    .frame(width: 44, height: 44)
                VStack(spacing: 0) {
                    Image(systemName: window.rating.icon)
                        .font(.caption)
                        .foregroundStyle(Color(hex: window.rating.color))
                    Text("\(Int(window.score))")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(Color(hex: window.rating.color))
                }
            }

            VStack(alignment: .leading, spacing: 3) {
                // Time range
                HStack(spacing: 4) {
                    Text("\(WeatherFormatters.shortTime(window.slot.start)) – \(WeatherFormatters.shortTime(window.slot.end))")
                        .font(.subheadline)
                        .fontWeight(.medium)

                    Text("(\(window.slot.durationMinutes) min)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                // Weather summary
                HStack(spacing: 8) {
                    Image(systemName: WeatherCodeInfo.sfSymbol(for: window.weatherCode))
                        .font(.caption)
                        .symbolRenderingMode(.multicolor)
                    Text(WeatherFormatters.temperature(window.avgTemp))
                        .font(.caption)
                    if window.maxPrecipChance > 5 {
                        HStack(spacing: 2) {
                            Image(systemName: "drop.fill")
                                .font(.system(size: 8))
                                .foregroundStyle(.blue)
                            Text("\(window.maxPrecipChance)%")
                                .font(.caption)
                        }
                    }
                    HStack(spacing: 2) {
                        Image(systemName: "wind")
                            .font(.system(size: 8))
                        Text(WeatherFormatters.windSpeed(window.avgWind))
                            .font(.caption)
                    }
                    .foregroundStyle(.secondary)
                }

                // Top reason
                if let reason = window.reasons.first {
                    Text(reason)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()

            Text(window.rating.rawValue)
                .font(.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(Color(hex: window.rating.color))
        }
        .padding(.vertical, 6)
    }
}

// MARK: - Best Time Summary

struct BestTimeSummary: View {
    let allWindows: [ScoredActivityWindow]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            SectionHeader(title: "Quick Picks", icon: "sparkles")

            ForEach(OutdoorActivity.allCases) { activity in
                if let best = allWindows.first(where: { $0.activity == activity }) {
                    QuickPickRow(activity: activity, window: best)
                }
            }
        }
    }
}

struct QuickPickRow: View {
    let activity: OutdoorActivity
    let window: ScoredActivityWindow

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: activity.icon)
                .font(.body)
                .frame(width: 28)

            Text(activity.rawValue)
                .font(.subheadline)

            Spacer()

            VStack(alignment: .trailing, spacing: 1) {
                if !Calendar.current.isDateInToday(window.slot.start) {
                    Text(Calendar.current.isDateInTomorrow(window.slot.start) ? "Tomorrow" : window.slot.start.formatted(.dateTime.weekday(.abbreviated)))
                        .font(.system(size: 9))
                        .foregroundStyle(.tertiary)
                }
                Text(WeatherFormatters.hourTime(window.slot.start))
                    .font(.subheadline)
                    .fontWeight(.medium)
            }

            Image(systemName: window.rating.icon)
                .font(.caption)
                .foregroundStyle(Color(hex: window.rating.color))
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Flow Layout

struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y), proposal: .unspecified)
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (positions: [CGPoint], size: CGSize) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth && x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x)
        }

        return (positions, CGSize(width: maxX, height: y + rowHeight))
    }
}
