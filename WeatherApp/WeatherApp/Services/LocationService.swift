import Foundation
import CoreLocation
import SwiftUI

@MainActor
class LocationService: NSObject, ObservableObject, CLLocationManagerDelegate {
    private let manager = CLLocationManager()

    @Published var latitude: Double?
    @Published var longitude: Double?
    @Published var cityName: String = "Loading..."
    @Published var authorizationStatus: CLAuthorizationStatus = .notDetermined
    @Published var error: String?

    override init() {
        super.init()
        manager.delegate = self
        manager.desiredAccuracy = kCLLocationAccuracyKilometer
    }

    func requestLocation() {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .notDetermined:
            manager.requestWhenInUseAuthorization()
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            error = "Location access denied. Please enable in Settings."
            // Fallback to New York
            setFallbackLocation()
        @unknown default:
            setFallbackLocation()
        }
    }

    private func setFallbackLocation() {
        latitude = 40.7128
        longitude = -74.0060
        cityName = "New York"
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.first else { return }
        latitude = location.coordinate.latitude
        longitude = location.coordinate.longitude
        reverseGeocode(location: location) { [weak self] name in
            // Update the "Current Location" entry in the store
            guard let self, let lat = self.latitude, let lon = self.longitude else { return }
            LocationStore.shared.updateCurrentLocation(latitude: lat, longitude: lon, name: name)
        }
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        self.error = error.localizedDescription
        setFallbackLocation()
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        authorizationStatus = manager.authorizationStatus
        switch manager.authorizationStatus {
        case .authorizedWhenInUse, .authorizedAlways:
            manager.requestLocation()
        case .denied, .restricted:
            setFallbackLocation()
        default:
            break
        }
    }

    func setManualLocation(latitude: Double, longitude: Double, cityName: String) {
        self.latitude = latitude
        self.longitude = longitude
        self.cityName = cityName
    }

    private func reverseGeocode(location: CLLocation, completion: ((String) -> Void)? = nil) {
        let geocoder = CLGeocoder()
        geocoder.reverseGeocodeLocation(location) { [weak self] placemarks, _ in
            Task { @MainActor in
                let name = placemarks?.first?.locality ?? placemarks?.first?.administrativeArea ?? "Unknown"
                self?.cityName = name
                completion?(name)
            }
        }
    }
}
