import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var unitSettings: UnitSettings
    @AppStorage("commuteOutHour") var commuteOutHour: Int = 8
    @AppStorage("commuteReturnHour") var commuteReturnHour: Int = 18
    @AppStorage("google_client_id") var googleClientID: String = ""
    @StateObject private var googleCal = GoogleCalendarService.shared

    var body: some View {
        NavigationStack {
            Form {
                // MARK: - Measurement System
                Section {
                    Picker("System", selection: Binding(
                        get: { unitSettings.selectedSystem },
                        set: { unitSettings.applySystem($0) }
                    )) {
                        Text("Imperial").tag(MeasurementSystem.imperial)
                        Text("Metric").tag(MeasurementSystem.metric)
                        Text("UK").tag(MeasurementSystem.ukMixed)
                        if unitSettings.selectedSystem == .custom {
                            Text("Custom").tag(MeasurementSystem.custom)
                        }
                    }
                    .pickerStyle(.segmented)
                } header: {
                    Text("Measurement System")
                } footer: {
                    Text("Changing this sets all units below. Edit individually to customize.")
                }

                // MARK: - Individual Units
                Section("Units") {
                    Picker("Temperature", selection: Binding(
                        get: { unitSettings.temperature },
                        set: { unitSettings.temperature = $0; unitSettings.markCustomIfNeeded() }
                    )) {
                        Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit.rawValue)
                        Text("Celsius (°C)").tag(TemperatureUnit.celsius.rawValue)
                    }

                    Picker("Wind Speed", selection: Binding(
                        get: { unitSettings.windSpeed },
                        set: { unitSettings.windSpeed = $0; unitSettings.markCustomIfNeeded() }
                    )) {
                        Text("mph").tag(WindSpeedUnit.mph.rawValue)
                        Text("km/h").tag(WindSpeedUnit.kmh.rawValue)
                        Text("m/s").tag(WindSpeedUnit.ms.rawValue)
                    }

                    Picker("Precipitation", selection: Binding(
                        get: { unitSettings.precipitation },
                        set: { unitSettings.precipitation = $0; unitSettings.markCustomIfNeeded() }
                    )) {
                        Text("Inches").tag(PrecipitationUnit.inches.rawValue)
                        Text("Millimeters").tag(PrecipitationUnit.mm.rawValue)
                    }

                    Picker("Pressure", selection: Binding(
                        get: { unitSettings.pressure },
                        set: { unitSettings.pressure = $0; unitSettings.markCustomIfNeeded() }
                    )) {
                        Text("inHg").tag(PressureUnit.inHg.rawValue)
                        Text("hPa").tag(PressureUnit.hPa.rawValue)
                        Text("mbar").tag(PressureUnit.mbar.rawValue)
                    }

                    Picker("Visibility", selection: Binding(
                        get: { unitSettings.visibility },
                        set: { unitSettings.visibility = $0; unitSettings.markCustomIfNeeded() }
                    )) {
                        Text("Miles").tag(VisibilityUnit.miles.rawValue)
                        Text("Kilometers").tag(VisibilityUnit.km.rawValue)
                    }

                    Picker("Time Format", selection: Binding(
                        get: { unitSettings.timeFormat },
                        set: { unitSettings.timeFormat = $0; unitSettings.markCustomIfNeeded() }
                    )) {
                        Text("12-hour (2:00 PM)").tag(TimeFormatPref.twelve.rawValue)
                        Text("24-hour (14:00)").tag(TimeFormatPref.twentyFour.rawValue)
                    }
                }

                // MARK: - Commute Times
                Section {
                    Picker("Departure", selection: $commuteOutHour) {
                        ForEach(5..<12, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                    Picker("Return", selection: $commuteReturnHour) {
                        ForEach(15..<22, id: \.self) { hour in
                            Text(formatHour(hour)).tag(hour)
                        }
                    }
                } header: {
                    Text("Commute Times")
                } footer: {
                    Text("Used for the commute weather forecast on the Plan tab.")
                }

                // MARK: - Calendar
                Section {
                    Label {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Calendar Integration")
                                .font(.subheadline)
                            Text("The Plan tab reads your device calendars including Google Calendar, Outlook, and iCloud — as long as they're added in iOS Settings > Calendar.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    } icon: {
                        Image(systemName: "calendar")
                            .foregroundStyle(.blue)
                    }

                    Link(destination: URL(string: UIApplication.openSettingsURLString)!) {
                        Label("Open Calendar Settings", systemImage: "gear")
                    }
                } header: {
                    Text("Calendars")
                }

                // MARK: - About
                Section {
                    HStack {
                        Text("Data Source")
                        Spacer()
                        Text("Open-Meteo")
                            .foregroundStyle(.secondary)
                    }
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0")
                            .foregroundStyle(.secondary)
                    }
                } header: {
                    Text("About")
                }

                // MARK: - Google Calendar
                Section {
                    if googleCal.isSignedIn {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Connected")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                if let email = googleCal.userEmail {
                                    Text(email)
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Button("Sign Out") {
                                googleCal.signOut()
                            }
                            .font(.caption)
                            .foregroundStyle(.red)
                        }
                    } else {
                        Button {
                            if let scene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                               let window = scene.windows.first {
                                googleCal.signIn(from: window)
                            }
                        } label: {
                            HStack {
                                Image(systemName: "calendar.badge.plus")
                                    .foregroundStyle(.blue)
                                Text("Sign in with Google")
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    }

                    if let error = googleCal.errorMessage {
                        Text(error)
                            .font(.caption)
                            .foregroundStyle(.red)
                    }
                } header: {
                    Text("Google Calendar")
                } footer: {
                    Text("Connect your Google Calendar to find the best weather windows in your free time.")
                }
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let f = DateFormatter()
        f.locale = Locale.current
        switch UnitSettings.shared.selectedTimeFormat {
        case .twelve:
            f.dateFormat = "h:mm a"
        case .twentyFour:
            f.dateFormat = "HH:mm"
        }
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return f.string(from: date)
    }
}
