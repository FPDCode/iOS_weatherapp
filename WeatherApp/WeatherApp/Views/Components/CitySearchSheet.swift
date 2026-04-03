import SwiftUI
import MapKit

struct CitySearchSheet: View {
    @StateObject private var searchService = CitySearchService()
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var weatherViewModel: WeatherViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                // Current location option
                Button {
                    locationService.requestLocation()
                    dismiss()
                } label: {
                    Label("Current Location", systemImage: "location.fill")
                        .foregroundStyle(.blue)
                }

                // Search results
                if searchService.isSearching {
                    HStack {
                        Spacer()
                        ProgressView()
                        Spacer()
                    }
                }

                ForEach(searchService.results, id: \.self) { result in
                    Button {
                        selectCity(result)
                    } label: {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(result.title)
                                .foregroundStyle(.primary)
                            if !result.subtitle.isEmpty {
                                Text(result.subtitle)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search city or location")
            .onChange(of: searchText) { _, newValue in
                searchService.search(newValue)
            }
            .navigationTitle("Search Location")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
            }
        }
    }

    private func selectCity(_ completion: MKLocalSearchCompletion) {
        Task {
            if let result = await searchService.getCoordinates(for: completion) {
                locationService.setManualLocation(
                    latitude: result.latitude,
                    longitude: result.longitude,
                    cityName: result.name
                )
                dismiss()
            }
        }
    }
}
