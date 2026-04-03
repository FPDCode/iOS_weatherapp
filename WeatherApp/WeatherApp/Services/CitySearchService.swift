import Foundation
import MapKit
import SwiftUI

@MainActor
class CitySearchService: NSObject, ObservableObject, MKLocalSearchCompleterDelegate {
    @Published var results: [MKLocalSearchCompletion] = []
    @Published var isSearching: Bool = false

    private let completer = MKLocalSearchCompleter()

    override init() {
        super.init()
        completer.delegate = self
        completer.resultTypes = .address
    }

    func search(_ query: String) {
        guard !query.isEmpty else {
            results = []
            return
        }
        isSearching = true
        completer.queryFragment = query
    }

    nonisolated func completerDidUpdateResults(_ completer: MKLocalSearchCompleter) {
        Task { @MainActor in
            self.results = completer.results
            self.isSearching = false
        }
    }

    nonisolated func completer(_ completer: MKLocalSearchCompleter, didFailWithError error: Error) {
        Task { @MainActor in
            self.isSearching = false
        }
    }

    func getCoordinates(for completion: MKLocalSearchCompletion) async -> (latitude: Double, longitude: Double, name: String)? {
        let request = MKLocalSearch.Request(completion: completion)
        let search = MKLocalSearch(request: request)

        do {
            let response = try await search.start()
            guard let item = response.mapItems.first else { return nil }
            let coord = item.placemark.coordinate
            let name = item.placemark.locality ?? item.placemark.name ?? completion.title
            return (coord.latitude, coord.longitude, name)
        } catch {
            return nil
        }
    }
}
