import Foundation

// MARK: - Location Label

enum LocationLabel: String, Codable, CaseIterable, Identifiable {
    case none = ""
    case home = "Home"
    case work = "Work"
    case school = "School"
    case gym = "Gym"
    case family = "Family"
    case vacation = "Vacation"
    case partner = "Partner"
    case parents = "Parents"
    case outdoors = "Outdoors"
    case commute = "Commute"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .none: return "mappin.circle.fill"
        case .home: return "house.fill"
        case .work: return "briefcase.fill"
        case .school: return "graduationcap.fill"
        case .gym: return "dumbbell.fill"
        case .family: return "person.2.fill"
        case .vacation: return "airplane"
        case .partner: return "heart.fill"
        case .parents: return "figure.2.and.child"
        case .outdoors: return "tree.fill"
        case .commute: return "tram.fill"
        }
    }

    var displayName: String {
        self == .none ? "No Label" : rawValue
    }

    /// Labels available for picking (excludes .none since that's the default)
    static var pickable: [LocationLabel] {
        allCases
    }
}

// MARK: - Saved Location

struct SavedLocation: Identifiable, Codable, Equatable {
    let id: UUID
    let name: String
    let latitude: Double
    let longitude: Double
    let isCurrentLocation: Bool
    let addedAt: Date
    var label: LocationLabel

    init(id: UUID = UUID(), name: String, latitude: Double, longitude: Double, isCurrentLocation: Bool = false, addedAt: Date = Date(), label: LocationLabel = .none) {
        self.id = id
        self.name = name
        self.latitude = latitude
        self.longitude = longitude
        self.isCurrentLocation = isCurrentLocation
        self.addedAt = addedAt
        self.label = label
    }

    /// Icon based on label, falling back to location type
    var displayIcon: String {
        if isCurrentLocation { return "location.fill" }
        return label == .none ? "mappin.circle.fill" : label.icon
    }

    /// Display name: shows label prefix if set (e.g. "Home — Amsterdam")
    var displayName: String {
        if label != .none {
            return "\(label.rawValue) — \(name)"
        }
        return name
    }

    static let currentLocationPlaceholder = SavedLocation(
        id: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!,
        name: "Current Location",
        latitude: 0,
        longitude: 0,
        isCurrentLocation: true
    )
}

// MARK: - Location Store (persisted to UserDefaults)

@MainActor
class LocationStore: ObservableObject {
    static let shared = LocationStore()

    @Published var savedLocations: [SavedLocation] = []
    @Published var activeLocationId: UUID?

    private let savedLocationsKey = "saved_locations"
    private let activeLocationKey = "active_location_id"

    var activeLocation: SavedLocation? {
        savedLocations.first { $0.id == activeLocationId }
    }

    var isUsingCurrentLocation: Bool {
        activeLocation?.isCurrentLocation == true
    }

    init() {
        loadLocations()
    }

    // MARK: - CRUD

    func addLocation(_ location: SavedLocation) {
        // Don't add duplicates (same name + close coordinates)
        let isDuplicate = savedLocations.contains { saved in
            !saved.isCurrentLocation &&
            abs(saved.latitude - location.latitude) < 0.01 &&
            abs(saved.longitude - location.longitude) < 0.01
        }
        guard !isDuplicate else { return }

        savedLocations.append(location)
        saveLocations()
    }

    func updateLabel(for locationId: UUID, label: LocationLabel) {
        guard let idx = savedLocations.firstIndex(where: { $0.id == locationId }) else { return }
        savedLocations[idx].label = label
        saveLocations()
    }

    func removeLocation(_ location: SavedLocation) {
        guard !location.isCurrentLocation else { return } // Can't remove "Current Location"
        savedLocations.removeAll { $0.id == location.id }

        // If we removed the active location, switch to current location
        if activeLocationId == location.id {
            switchToCurrentLocation()
        }
        saveLocations()
    }

    func switchTo(_ location: SavedLocation) {
        activeLocationId = location.id
        UserDefaults.standard.set(location.id.uuidString, forKey: activeLocationKey)
    }

    func switchToCurrentLocation() {
        if let current = savedLocations.first(where: { $0.isCurrentLocation }) {
            switchTo(current)
        }
    }

    /// Update the "Current Location" entry with real device coordinates
    func updateCurrentLocation(latitude: Double, longitude: Double, name: String) {
        if let idx = savedLocations.firstIndex(where: { $0.isCurrentLocation }) {
            savedLocations[idx] = SavedLocation(
                id: savedLocations[idx].id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                isCurrentLocation: true,
                addedAt: savedLocations[idx].addedAt,
                label: savedLocations[idx].label
            )
        } else {
            // First time — add current location entry
            let current = SavedLocation(
                id: SavedLocation.currentLocationPlaceholder.id,
                name: name,
                latitude: latitude,
                longitude: longitude,
                isCurrentLocation: true
            )
            savedLocations.insert(current, at: 0)
        }

        // If no active location set, default to current
        if activeLocationId == nil {
            switchToCurrentLocation()
        }

        saveLocations()
    }

    // MARK: - Persistence

    private func loadLocations() {
        if let data = UserDefaults.standard.data(forKey: savedLocationsKey),
           let decoded = try? JSONDecoder().decode([SavedLocation].self, from: data) {
            savedLocations = decoded
        }

        if let idString = UserDefaults.standard.string(forKey: activeLocationKey),
           let id = UUID(uuidString: idString) {
            activeLocationId = id
        }
    }

    private func saveLocations() {
        if let encoded = try? JSONEncoder().encode(savedLocations) {
            UserDefaults.standard.set(encoded, forKey: savedLocationsKey)
        }
    }
}
