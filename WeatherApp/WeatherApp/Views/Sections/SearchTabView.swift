import SwiftUI
import MapKit

struct SearchTabView: View {
    @StateObject private var searchService = CitySearchService()
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var weatherViewModel: WeatherViewModel
    @ObservedObject var locationStore = LocationStore.shared

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Saved Locations
                if searchText.isEmpty {
                    Section {
                        ForEach(locationStore.savedLocations) { location in
                            SavedLocationRow(
                                location: location,
                                isActive: location.id == locationStore.activeLocationId,
                                onSelect: { selectSavedLocation(location) }
                            )
                        }
                        .onDelete(perform: deleteLocations)
                    } header: {
                        HStack {
                            Text("My Locations")
                            Spacer()
                            Text("\(locationStore.savedLocations.count)")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                // MARK: - Search Results
                if !searchText.isEmpty {
                    Section {
                        if searchService.isSearching {
                            HStack {
                                Spacer()
                                ProgressView()
                                Spacer()
                            }
                        }

                        ForEach(searchService.results, id: \.self) { result in
                            SearchResultRow(
                                result: result,
                                isSaved: isAlreadySaved(result),
                                onSelect: { selectSearchResult(result) },
                                onSave: { saveSearchResult(result) }
                            )
                        }

                        if searchService.results.isEmpty && !searchService.isSearching {
                            Text("No results found")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                        }
                    } header: {
                        Text("Results")
                    }
                }
            }
            .searchable(text: $searchText, placement: .navigationBarDrawer(displayMode: .always), prompt: "Search city or location")
            .onChange(of: searchText) { _, newValue in
                searchService.search(newValue)
            }
            .navigationTitle("Search")
            .toolbar {
                if searchText.isEmpty && !locationStore.savedLocations.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        EditButton()
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func selectSavedLocation(_ location: SavedLocation) {
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        locationStore.switchTo(location)
        if location.isCurrentLocation {
            locationService.requestLocation()
        } else {
            locationService.setManualLocation(
                latitude: location.latitude,
                longitude: location.longitude,
                cityName: location.name
            )
        }
    }

    private func selectSearchResult(_ completion: MKLocalSearchCompletion) {
        Task {
            guard let result = await searchService.getCoordinates(for: completion) else { return }
            let location = SavedLocation(
                name: result.name,
                latitude: result.latitude,
                longitude: result.longitude
            )
            locationStore.addLocation(location)
            locationStore.switchTo(location)
            locationService.setManualLocation(
                latitude: result.latitude,
                longitude: result.longitude,
                cityName: result.name
            )
            searchText = ""
        }
    }

    private func saveSearchResult(_ completion: MKLocalSearchCompletion) {
        Task {
            guard let result = await searchService.getCoordinates(for: completion) else { return }
            let location = SavedLocation(
                name: result.name,
                latitude: result.latitude,
                longitude: result.longitude
            )
            locationStore.addLocation(location)
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
        }
    }

    private func deleteLocations(at offsets: IndexSet) {
        for index in offsets {
            locationStore.removeLocation(locationStore.savedLocations[index])
        }
    }

    private func isAlreadySaved(_ result: MKLocalSearchCompletion) -> Bool {
        locationStore.savedLocations.contains { $0.name.lowercased() == result.title.lowercased() }
    }
}
