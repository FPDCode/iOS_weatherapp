import SwiftUI

struct SettingsSheet: View {
    @AppStorage("temperatureUnit") var temperatureUnit: String = TemperatureUnit.fahrenheit.rawValue
    @AppStorage("commuteOutHour") var commuteOutHour: Int = 8
    @AppStorage("commuteReturnHour") var commuteReturnHour: Int = 18
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Temperature Unit") {
                    Picker("Unit", selection: $temperatureUnit) {
                        Text("Fahrenheit (°F)").tag(TemperatureUnit.fahrenheit.rawValue)
                        Text("Celsius (°C)").tag(TemperatureUnit.celsius.rawValue)
                    }
                    .pickerStyle(.segmented)
                }

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
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }

    private func formatHour(_ hour: Int) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "h:mm a"
        let calendar = Calendar.current
        let date = calendar.date(bySettingHour: hour, minute: 0, second: 0, of: Date()) ?? Date()
        return formatter.string(from: date)
    }
}
