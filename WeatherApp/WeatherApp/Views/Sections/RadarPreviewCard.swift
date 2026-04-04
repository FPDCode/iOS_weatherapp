import SwiftUI
import MapKit

struct RadarPreviewCard: View {
    let latitude: Double
    let longitude: Double
    let isCurrentLocation: Bool
    let onTap: () -> Void

    @StateObject private var previewModel = RadarPreviewModel()

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            SectionHeader(title: "Radar", icon: "dot.radiowaves.left.and.right")

            // Map preview
            Button(action: onTap) {
                ZStack(alignment: .bottomTrailing) {
                    RadarPreviewMap(
                        latitude: latitude,
                        longitude: longitude,
                        isCurrentLocation: isCurrentLocation,
                        tileURL: previewModel.currentTileURL
                    )
                    .frame(height: 180)
                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))

                    // "Open Radar" pill
                    HStack(spacing: 4) {
                        Image(systemName: "arrow.up.left.and.arrow.down.right")
                            .font(.system(size: 9, weight: .bold))
                        Text("Open Radar")
                            .font(.caption2)
                            .fontWeight(.semibold)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(.ultraThinMaterial)
                    .clipShape(Capsule())
                    .padding(8)
                }
            }
            .buttonStyle(.plain)
        }
        .task {
            await previewModel.loadLatestFrame()
        }
    }
}

// MARK: - Preview Model (loads just the latest radar frame)

@MainActor
class RadarPreviewModel: ObservableObject {
    @Published var currentTileURL: String?

    func loadLatestFrame() async {
        do {
            let data = try await RadarService.shared.fetchRadarFrames()
            // Use the most recent past frame
            if let latest = data.pastFrames.last {
                currentTileURL = latest.tileURL
            }
        } catch {
            // Silent fail — show map without radar
        }
    }
}

// MARK: - Static Radar Preview Map

struct RadarPreviewMap: UIViewRepresentable {
    let latitude: Double
    let longitude: Double
    let isCurrentLocation: Bool
    let tileURL: String?

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard
        mapView.overrideUserInterfaceStyle = .dark
        mapView.isScrollEnabled = false
        mapView.isZoomEnabled = false
        mapView.isRotateEnabled = false
        mapView.isPitchEnabled = false
        mapView.showsUserLocation = isCurrentLocation

        // Show at a zoom level good for seeing regional radar patterns
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5)
        )
        mapView.setRegion(region, animated: false)

        // Add pin for non-current locations
        if !isCurrentLocation {
            let pin = MKPointAnnotation()
            pin.coordinate = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
            mapView.addAnnotation(pin)
        }

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update radar overlay
        if let url = tileURL {
            context.coordinator.updateOverlay(on: mapView, tileURL: url)
        }

        // Re-center if location changed
        let center = CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
        if abs(mapView.centerCoordinate.latitude - latitude) > 0.01 ||
           abs(mapView.centerCoordinate.longitude - longitude) > 0.01 {
            let region = MKCoordinateRegion(
                center: center,
                span: MKCoordinateSpan(latitudeDelta: 2.5, longitudeDelta: 2.5)
            )
            mapView.setRegion(region, animated: false)

            // Update pin
            mapView.removeAnnotations(mapView.annotations.filter { !($0 is MKUserLocation) })
            if !isCurrentLocation {
                let pin = MKPointAnnotation()
                pin.coordinate = center
                mapView.addAnnotation(pin)
            }
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        private var currentOverlay: CachedTileOverlay?
        private var currentURL: String?

        func updateOverlay(on mapView: MKMapView, tileURL: String) {
            guard tileURL != currentURL else { return }
            currentURL = tileURL

            if let existing = currentOverlay {
                mapView.removeOverlay(existing)
            }

            let overlay = CachedTileOverlay(urlTemplate: tileURL)
            overlay.canReplaceMapContent = false
            overlay.minimumZ = 1
            overlay.maximumZ = 7
            mapView.addOverlay(overlay, level: .aboveRoads)
            currentOverlay = overlay
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
                renderer.alpha = 0.6
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: MKAnnotation) -> MKAnnotationView? {
            guard !(annotation is MKUserLocation) else { return nil }
            let view = MKMarkerAnnotationView(annotation: annotation, reuseIdentifier: "pin")
            view.markerTintColor = .systemBlue
            view.glyphImage = UIImage(systemName: "mappin")
            return view
        }
    }
}
