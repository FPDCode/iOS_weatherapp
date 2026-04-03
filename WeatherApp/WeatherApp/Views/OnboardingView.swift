import SwiftUI

struct OnboardingView: View {
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var weatherViewModel: WeatherViewModel
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding: Bool = false
    @State private var locationRequested = false

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "1A237E"), Color(hex: "283593"), Color(hex: "3949AB")],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                // Icon
                Image(systemName: "cloud.sun.rain.fill")
                    .font(.system(size: 80))
                    .symbolRenderingMode(.multicolor)

                // Title
                VStack(spacing: 8) {
                    Text("Welcome to Weather")
                        .font(.largeTitle)
                        .fontWeight(.bold)

                    Text("Beautiful forecasts, smart planning")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                // Location explanation
                VStack(spacing: 16) {
                    featureRow(icon: "location.fill", color: .blue,
                               title: "Local Weather",
                               subtitle: "Get accurate forecasts for your location")

                    featureRow(icon: "calendar.badge.clock", color: .orange,
                               title: "Smart Planning",
                               subtitle: "Find the best time for outdoor activities")

                    featureRow(icon: "globe", color: .green,
                               title: "Your Preferences",
                               subtitle: "Units auto-set based on your region")
                }
                .padding(.horizontal, 24)

                Spacer()

                // Buttons
                VStack(spacing: 12) {
                    Button {
                        completeOnboarding(allowLocation: true)
                    } label: {
                        Label("Allow Location", systemImage: "location.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.white)
                    .foregroundStyle(.black)

                    Button {
                        completeOnboarding(allowLocation: false)
                    } label: {
                        Text("Maybe Later")
                            .font(.subheadline)
                            .foregroundStyle(.white.opacity(0.7))
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 40)
            }
        }
        .preferredColorScheme(.dark)
    }

    private func featureRow(icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(spacing: 16) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundStyle(color)
                .frame(width: 40)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
    }

    private func completeOnboarding(allowLocation: Bool) {
        // Auto-detect locale and set unit defaults
        UnitSettings.shared.autoDetectFromLocale()

        if allowLocation {
            locationService.requestLocation()
        }

        withAnimation(.easeInOut(duration: 0.3)) {
            hasCompletedOnboarding = true
        }
    }
}
