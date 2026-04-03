import Foundation

// MARK: - RainViewer API (free, no key)

actor RadarService {
    static let shared = RadarService()

    private let mapsURL = "https://api.rainviewer.com/public/weather-maps.json"

    func fetchRadarFrames() async throws -> RadarData {
        guard let url = URL(string: mapsURL) else {
            throw WeatherError.invalidURL
        }

        let (data, response) = try await URLSession.shared.data(from: url)

        guard let httpResponse = response as? HTTPURLResponse,
              httpResponse.statusCode == 200 else {
            throw WeatherError.invalidResponse
        }

        let decoded = try JSONDecoder().decode(RainViewerResponse.self, from: data)

        let host = decoded.host

        // Past radar frames
        let pastFrames = decoded.radar.past.map { frame in
            RadarFrame(
                timestamp: frame.time,
                date: Date(timeIntervalSince1970: TimeInterval(frame.time)),
                tileURL: "\(host)\(frame.path)/256/{z}/{x}/{y}/2/1_1.png",
                type: .past
            )
        }

        // Forecast radar frames (nowcast)
        let forecastFrames = (decoded.radar.nowcast ?? []).map { frame in
            RadarFrame(
                timestamp: frame.time,
                date: Date(timeIntervalSince1970: TimeInterval(frame.time)),
                tileURL: "\(host)\(frame.path)/256/{z}/{x}/{y}/2/1_1.png",
                type: .forecast
            )
        }

        // Satellite infrared frames
        let satelliteFrames = (decoded.satellite?.infrared ?? []).map { frame in
            RadarFrame(
                timestamp: frame.time,
                date: Date(timeIntervalSince1970: TimeInterval(frame.time)),
                tileURL: "\(host)\(frame.path)/256/{z}/{x}/{y}/0/0_0.png",
                type: .satellite
            )
        }

        return RadarData(
            pastFrames: pastFrames,
            forecastFrames: forecastFrames,
            satelliteFrames: satelliteFrames,
            generated: Date()
        )
    }
}

// MARK: - RainViewer API Response Models

struct RainViewerResponse: Codable {
    let version: String
    let generated: Int
    let host: String
    let radar: RainViewerRadar
    let satellite: RainViewerSatellite?
}

struct RainViewerRadar: Codable {
    let past: [RainViewerFrame]
    let nowcast: [RainViewerFrame]?
}

struct RainViewerSatellite: Codable {
    let infrared: [RainViewerFrame]?
}

struct RainViewerFrame: Codable {
    let time: Int
    let path: String
}

// MARK: - App Models

struct RadarData {
    let pastFrames: [RadarFrame]
    let forecastFrames: [RadarFrame]
    let satelliteFrames: [RadarFrame]
    let generated: Date

    var allRadarFrames: [RadarFrame] {
        pastFrames + forecastFrames
    }
}

struct RadarFrame: Identifiable {
    let id = UUID()
    let timestamp: Int
    let date: Date
    let tileURL: String // Template with {z}/{x}/{y} placeholders
    let type: RadarFrameType
}

enum RadarFrameType {
    case past
    case forecast
    case satellite
}
