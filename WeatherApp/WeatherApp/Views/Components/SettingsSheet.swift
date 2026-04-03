import SwiftUI

struct SettingsSheet: View {
    @AppStorage("temperatureUnit") var temperatureUnit: String = TemperatureUnit.fahrenheit.rawValue
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
}
