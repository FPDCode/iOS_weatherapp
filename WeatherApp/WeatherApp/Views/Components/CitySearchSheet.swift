import SwiftUI
import MapKit

struct CitySearchSheet: View {
    @StateObject private var searchService = CitySearchService()
    @EnvironmentObject var locationService: LocationService
    @EnvironmentObject var weatherViewModel: WeatherViewModel
    @ObservedObject var locationStore = LocationStore.shared
    @Environment(\.dismiss) private var dismiss

    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Saved Locations
                if !locationStore.savedLocations.isEmpty && searchText.isEmpty {
                    Section {
                        ForEach(locationStore.savedLocations) { location in
                            SavedLocationRow(
                                location: location,
                                isActive: location.id == locationStore.activeLocationId,
                                onSelect: { selectSavedLocation(location) },
                                onLabelChanged: { newLabel in
                                    locationStore.updateLabel(for: location.id, label: newLabel)
                                }
                            )
                        }
                        .onDelete(perform: deleteLocations)
                    } header: {
                        Text("My Locations")
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
                    } header: {
                        Text("Search Results")
                    }
                }
            }
            .searchable(text: $searchText, prompt: "Search city or location")
            .onChange(of: searchText) { _, newValue in
                searchService.search(newValue)
            }
            .navigationTitle("Locations")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    EditButton()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .fontWeight(.semibold)
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
        dismiss()
    }

    private func selectSearchResult(_ completion: MKLocalSearchCompletion) {
        Task {
            guard let result = await searchService.getCoordinates(for: completion) else { return }

            let location = SavedLocation(
                name: result.name,
                latitude: result.latitude,
                longitude: result.longitude
            )

            // Auto-save when selecting from search
            locationStore.addLocation(location)
            locationStore.switchTo(location)
            locationService.setManualLocation(
                latitude: result.latitude,
                longitude: result.longitude,
                cityName: result.name
            )
            dismiss()
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
            let location = locationStore.savedLocations[index]
            locationStore.removeLocation(location)
        }
    }

    private func isAlreadySaved(_ result: MKLocalSearchCompletion) -> Bool {
        locationStore.savedLocations.contains { $0.name.lowercased() == result.title.lowercased() }
    }
}

// MARK: - Saved Location Row

struct SavedLocationRow: View {
    let location: SavedLocation
    let isActive: Bool
    let onSelect: () -> Void
    var onLabelChanged: ((LocationLabel) -> Void)? = nil

    @State private var showLabelPicker = false

    var body: some View {
        Button(action: onSelect) {
            HStack(spacing: 12) {
                Image(systemName: location.displayIcon)
                    .font(.title3)
                    .foregroundStyle(location.isCurrentLocation ? .blue : .orange)
                    .frame(width: 30)

                VStack(alignment: .leading, spacing: 2) {
                    Text(location.name)
                        .font(.body)
                        .foregroundStyle(.primary)

                    if location.isCurrentLocation {
                        Text("GPS Location")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    } else if location.label != .none {
                        Text(location.label.rawValue)
                            .font(.caption)
                            .foregroundStyle(.orange)
                    } else {
                        Text(String(format: "%.2f, %.2f", location.latitude, location.longitude))
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer()

                if isActive {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.green)
                }
            }
        }
        .deleteDisabled(location.isCurrentLocation)
        .swipeActions(edge: .leading, allowsFullSwipe: false) {
            if !location.isCurrentLocation {
                Button {
                    showLabelPicker = true
                } label: {
                    Label("Label", systemImage: "tag.fill")
                }
                .tint(.orange)
            }
        }
        .sheet(isPresented: $showLabelPicker) {
            LocationLabelPicker(
                currentLabel: location.label,
                locationName: location.name
            ) { newLabel in
                onLabelChanged?(newLabel)
            }
            .presentationDetents([.medium])
        }
    }
}

// MARK: - Location Label Picker

struct LocationLabelPicker: View {
    let currentLabel: LocationLabel
    let locationName: String
    let onSelect: (LocationLabel) -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List {
                ForEach(LocationLabel.pickable) { label in
                    Button {
                        onSelect(label)
                        dismiss()
                    } label: {
                        HStack(spacing: 12) {
                            Image(systemName: label.icon)
                                .font(.body)
                                .foregroundStyle(label == .none ? Color.secondary : Color.orange)
                                .frame(width: 28)

                            Text(label.displayName)
                                .foregroundStyle(.primary)

                            Spacer()

                            if label == currentLabel {
                                Image(systemName: "checkmark")
                                    .foregroundStyle(.blue)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Label for \(locationName)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}

// MARK: - Search Result Row

struct SearchResultRow: View {
    let result: MKLocalSearchCompletion
    let isSaved: Bool
    let onSelect: () -> Void
    let onSave: () -> Void

    var body: some View {
        HStack {
            Button(action: onSelect) {
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

            Spacer()

            if isSaved {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundStyle(.green)
                    .font(.body)
            } else {
                Button(action: onSave) {
                    Image(systemName: "plus.circle.fill")
                        .foregroundStyle(.blue)
                        .font(.title3)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
