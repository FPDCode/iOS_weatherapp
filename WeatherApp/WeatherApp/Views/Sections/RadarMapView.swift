import SwiftUI
import MapKit

// MARK: - Radar Tab View

struct RadarTabView: View {
    @EnvironmentObject var locationService: LocationService
    @StateObject private var viewModel = RadarViewModel()
    @State private var mapMode: RadarMapMode = .radar

    var body: some View {
        ZStack(alignment: .bottom) {
            // Map with radar overlay
            RadarMap(
                viewModel: viewModel,
                latitude: locationService.latitude ?? 40.7128,
                longitude: locationService.longitude ?? -74.006
            )
            .ignoresSafeArea()

            // Controls overlay
            VStack(spacing: 0) {
                // Top bar: mode toggle
                HStack {
                    Picker("Mode", selection: $mapMode) {
                        Text("Radar").tag(RadarMapMode.radar)
                        Text("Satellite").tag(RadarMapMode.satellite)
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 200)
                    .onChange(of: mapMode) { _, newMode in
                        viewModel.switchMode(newMode)
                    }
                }
                .padding(.top, 60)
                .padding(.horizontal, 20)

                Spacer()

                // Bottom controls
                VStack(spacing: 8) {
                    // Time label
                    HStack {
                        if viewModel.isLoading {
                            ProgressView()
                                .tint(.white)
                                .scaleEffect(0.8)
                            Text("Loading radar...")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        } else if let frame = viewModel.currentFrame {
                            Image(systemName: frame.type == .forecast ? "clock.badge.fill" : "clock")
                                .font(.caption)
                                .foregroundStyle(frame.type == .forecast ? .cyan : .secondary)
                            Text(formatFrameTime(frame.date))
                                .font(.subheadline)
                                .fontWeight(.medium)
                            if frame.type == .forecast {
                                Text("FORECAST")
                                    .font(.system(size: 8, weight: .bold))
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 2)
                                    .background(.cyan.opacity(0.2))
                                    .clipShape(Capsule())
                                    .foregroundStyle(.cyan)
                            }
                        }
                        Spacer()
                        Text("RainViewer")
                            .font(.system(size: 8))
                            .foregroundStyle(.tertiary)
                    }

                    // Timeline slider
                    if viewModel.frameCount > 1 {
                        Slider(
                            value: Binding(
                                get: { Double(viewModel.currentFrameIndex) },
                                set: { viewModel.seekTo(Int($0)) }
                            ),
                            in: 0...Double(max(viewModel.frameCount - 1, 1)),
                            step: 1
                        )
                        .tint(.cyan)

                        // Timeline markers
                        HStack {
                            Text(viewModel.oldestFrameLabel)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                            Spacer()
                            if viewModel.nowFrameIndex > 0 {
                                Text("Now")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                                    .offset(x: nowOffset(totalWidth: UIScreen.main.bounds.width - 56))
                            }
                            Spacer()
                            Text(viewModel.newestFrameLabel)
                                .font(.system(size: 9))
                                .foregroundStyle(.tertiary)
                        }
                    }

                    // Play/pause + speed
                    HStack(spacing: 20) {
                        // Step back
                        Button {
                            viewModel.stepBackward()
                        } label: {
                            Image(systemName: "backward.frame.fill")
                                .font(.title3)
                        }

                        // Play/pause
                        Button {
                            viewModel.togglePlayback()
                        } label: {
                            Image(systemName: viewModel.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                                .font(.largeTitle)
                        }

                        // Step forward
                        Button {
                            viewModel.stepForward()
                        } label: {
                            Image(systemName: "forward.frame.fill")
                                .font(.title3)
                        }
                    }
                    .foregroundStyle(.white)
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
            }

            // Legend
            VStack {
                HStack {
                    Spacer()
                    RadarLegend(mode: mapMode)
                        .padding(.top, 110)
                        .padding(.trailing, 16)
                }
                Spacer()
            }
        }
        .preferredColorScheme(.dark)
        .task {
            await viewModel.loadFrames()
        }
    }

    private func formatFrameTime(_ date: Date) -> String {
        WeatherFormatters.shortTime(date)
    }

    private func nowOffset(totalWidth: CGFloat) -> CGFloat {
        guard viewModel.frameCount > 1 else { return 0 }
        let ratio = CGFloat(viewModel.nowFrameIndex) / CGFloat(viewModel.frameCount - 1)
        return (ratio - 0.5) * totalWidth * 0.7
    }
}

enum RadarMapMode {
    case radar
    case satellite
}

// MARK: - Radar Legend

struct RadarLegend: View {
    let mode: RadarMapMode

    var body: some View {
        VStack(alignment: .trailing, spacing: 3) {
            if mode == .radar {
                Text("dBZ")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
                HStack(spacing: 1) {
                    ForEach(radarColors, id: \.self) { color in
                        Rectangle()
                            .fill(color)
                            .frame(width: 8, height: 12)
                    }
                }
                .clipShape(RoundedRectangle(cornerRadius: 2))
                HStack {
                    Text("Light")
                        .font(.system(size: 7))
                    Spacer()
                    Text("Heavy")
                        .font(.system(size: 7))
                }
                .foregroundStyle(.secondary)
                .frame(width: CGFloat(radarColors.count) * 9)
            } else {
                Text("IR")
                    .font(.system(size: 8, weight: .bold))
                    .foregroundStyle(.secondary)
            }
        }
        .padding(6)
        .background(.ultraThinMaterial)
        .clipShape(RoundedRectangle(cornerRadius: 6))
    }

    private var radarColors: [Color] {
        [
            Color(hex: "69B34C"), Color(hex: "ACB334"), Color(hex: "FAB733"),
            Color(hex: "FF8E15"), Color(hex: "FF4E11"), Color(hex: "FF0D0D"),
            Color(hex: "A30000"),
        ]
    }
}

// MARK: - Radar ViewModel

@MainActor
class RadarViewModel: ObservableObject {
    @Published var isLoading = true
    @Published var currentFrameIndex = 0
    @Published var isPlaying = false
    @Published var frames: [RadarFrame] = []
    @Published var currentTileURL: String?

    private var radarData: RadarData?
    private var playTimer: Timer?
    private let radarService = RadarService.shared

    var frameCount: Int { frames.count }

    var currentFrame: RadarFrame? {
        guard currentFrameIndex < frames.count else { return nil }
        return frames[currentFrameIndex]
    }

    var nowFrameIndex: Int {
        // Find the last "past" frame (closest to now)
        guard let data = radarData else { return 0 }
        return data.pastFrames.count - 1
    }

    var oldestFrameLabel: String {
        guard let first = frames.first else { return "" }
        let minutes = Int(Date().timeIntervalSince(first.date) / 60)
        return "-\(minutes)m"
    }

    var newestFrameLabel: String {
        guard let last = frames.last else { return "" }
        if last.type == .forecast {
            let minutes = Int(last.date.timeIntervalSince(Date()) / 60)
            return "+\(minutes)m"
        }
        return "Now"
    }

    func loadFrames() async {
        isLoading = true
        do {
            let data = try await radarService.fetchRadarFrames()
            self.radarData = data
            self.frames = data.allRadarFrames
            // Start at "now" (last past frame)
            self.currentFrameIndex = max(data.pastFrames.count - 1, 0)
            updateTileURL()
        } catch {
            // Silently fail — show empty map
        }
        isLoading = false
    }

    func switchMode(_ mode: RadarMapMode) {
        guard let data = radarData else { return }
        switch mode {
        case .radar:
            frames = data.allRadarFrames
            currentFrameIndex = max(data.pastFrames.count - 1, 0)
        case .satellite:
            frames = data.satelliteFrames
            currentFrameIndex = max(frames.count - 1, 0)
        }
        updateTileURL()
    }

    func togglePlayback() {
        if isPlaying {
            stopPlayback()
        } else {
            startPlayback()
        }
    }

    func stepForward() {
        guard frameCount > 0 else { return }
        currentFrameIndex = (currentFrameIndex + 1) % frameCount
        updateTileURL()
    }

    func stepBackward() {
        guard frameCount > 0 else { return }
        currentFrameIndex = (currentFrameIndex - 1 + frameCount) % frameCount
        updateTileURL()
    }

    func seekTo(_ index: Int) {
        currentFrameIndex = min(max(index, 0), frameCount - 1)
        updateTileURL()
    }

    private func startPlayback() {
        isPlaying = true
        playTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                self?.stepForward()
            }
        }
    }

    private func stopPlayback() {
        isPlaying = false
        playTimer?.invalidate()
        playTimer = nil
    }

    private func updateTileURL() {
        currentTileURL = currentFrame?.tileURL
    }
}

// MARK: - MapKit Radar Map (UIViewRepresentable)

struct RadarMap: UIViewRepresentable {
    @ObservedObject var viewModel: RadarViewModel
    let latitude: Double
    let longitude: Double

    func makeUIView(context: Context) -> MKMapView {
        let mapView = MKMapView()
        mapView.delegate = context.coordinator
        mapView.mapType = .mutedStandard
        mapView.showsUserLocation = true
        mapView.isRotateEnabled = false

        // Dark map style
        mapView.overrideUserInterfaceStyle = .dark

        // Center on user location
        let region = MKCoordinateRegion(
            center: CLLocationCoordinate2D(latitude: latitude, longitude: longitude),
            span: MKCoordinateSpan(latitudeDelta: 3.0, longitudeDelta: 3.0)
        )
        mapView.setRegion(region, animated: false)

        return mapView
    }

    func updateUIView(_ mapView: MKMapView, context: Context) {
        // Update the tile overlay when the frame changes
        if let tileURL = viewModel.currentTileURL {
            context.coordinator.updateOverlay(on: mapView, tileURL: tileURL)
        }
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    class Coordinator: NSObject, MKMapViewDelegate {
        private var currentOverlay: MKTileOverlay?

        func updateOverlay(on mapView: MKMapView, tileURL: String) {
            // Remove existing overlay
            if let existing = currentOverlay {
                mapView.removeOverlay(existing)
            }

            // Add new tile overlay
            let overlay = MKTileOverlay(urlTemplate: tileURL)
            overlay.canReplaceMapContent = false
            overlay.minimumZ = 1
            overlay.maximumZ = 12
            mapView.addOverlay(overlay, level: .aboveRoads)
            currentOverlay = overlay
        }

        func mapView(_ mapView: MKMapView, rendererFor overlay: MKOverlay) -> MKOverlayRenderer {
            if let tileOverlay = overlay as? MKTileOverlay {
                let renderer = MKTileOverlayRenderer(tileOverlay: tileOverlay)
                renderer.alpha = 0.7
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }
    }
}
