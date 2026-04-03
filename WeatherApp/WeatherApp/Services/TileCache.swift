import Foundation
import MapKit

// MARK: - Tile Cache (memory-bounded)

/// LRU cache for radar tile images. Evicts automatically when memory pressure
/// hits the configured limit. Tiles are keyed by full URL string.
final class TileCache {
    static let shared = TileCache()

    private let cache = NSCache<NSString, NSData>()
    private let session: URLSession

    init() {
        // Memory limit: 50 MB for tile data
        cache.totalCostLimit = 50 * 1024 * 1024
        // Max ~500 tiles in memory (each ~20-100 KB)
        cache.countLimit = 500
        cache.name = "com.weatherapp.tilecache"

        // Custom URLSession with disk cache for tiles
        let config = URLSessionConfiguration.default
        // 30 MB disk cache, 20 MB memory cache on the URLSession layer
        config.urlCache = URLCache(
            memoryCapacity: 20 * 1024 * 1024,
            diskCapacity: 30 * 1024 * 1024
        )
        config.requestCachePolicy = .returnCacheDataElseLoad
        config.timeoutIntervalForRequest = 10
        session = URLSession(configuration: config)
    }

    /// Get tile data from memory cache
    func get(_ urlString: String) -> Data? {
        cache.object(forKey: urlString as NSString) as Data?
    }

    /// Store tile data in memory cache (cost = byte count)
    func set(_ data: Data, for urlString: String) {
        cache.setObject(data as NSData, forKey: urlString as NSString, cost: data.count)
    }

    /// Fetch tile, checking memory cache first, then network
    func fetchTile(url: URL) async -> Data? {
        let key = url.absoluteString

        // 1. Check memory cache
        if let cached = get(key) {
            return cached
        }

        // 2. Fetch from network (URLSession disk cache may hit)
        do {
            let (data, response) = try await session.data(from: url)
            guard let httpResponse = response as? HTTPURLResponse,
                  httpResponse.statusCode == 200,
                  !data.isEmpty else {
                return nil
            }
            // Store in memory cache
            set(data, for: key)
            return data
        } catch {
            return nil
        }
    }

    /// Evict all tiles for a specific frame timestamp (when no longer needed)
    func evictFrame(tileURLTemplate: String) {
        // NSCache handles LRU eviction automatically, but we can help by
        // removing known entries. Since we don't track all z/x/y combos
        // per frame, we rely on NSCache's automatic eviction instead.
        // This is intentional — NSCache is designed for this.
    }

    /// Clear all cached tiles (e.g., when switching radar/satellite mode)
    func clearAll() {
        cache.removeAllObjects()
    }
}

// MARK: - Cached Tile Overlay

/// Custom MKTileOverlay that routes through our TileCache.
/// This ensures tiles are fetched once, served from memory on replay,
/// and automatically evicted under memory pressure.
final class CachedTileOverlay: MKTileOverlay {
    private let tileCache = TileCache.shared

    override func loadTile(at path: MKTileOverlayPath, result: @escaping (Data?, Error?) -> Void) {
        guard let url = self.url(forTilePath: path) else {
            result(nil, nil)
            return
        }

        // Check memory cache synchronously first
        if let cached = tileCache.get(url.absoluteString) {
            result(cached, nil)
            return
        }

        // Async fetch
        Task {
            if let data = await tileCache.fetchTile(url: url) {
                result(data, nil)
            } else {
                result(nil, nil)
            }
        }
    }

    private func url(forTilePath path: MKTileOverlayPath) -> URL? {
        guard let template = urlTemplate else { return nil }
        let urlString = template
            .replacingOccurrences(of: "{z}", with: "\(path.z)")
            .replacingOccurrences(of: "{x}", with: "\(path.x)")
            .replacingOccurrences(of: "{y}", with: "\(path.y)")
        return URL(string: urlString)
    }
}

// MARK: - Preloader

/// Preloads tiles for adjacent frames so animation is smooth.
/// Only preloads the center tile at the current zoom for each frame.
actor TilePreloader {
    private let cache = TileCache.shared
    private var preloadTask: Task<Void, Never>?

    /// Preload tiles for frames around the current index.
    /// Only preloads ±2 frames to limit memory usage.
    func preloadAround(
        index: Int,
        frames: [RadarFrame],
        centerLat: Double,
        centerLon: Double,
        zoomLevel: Int = 6
    ) {
        preloadTask?.cancel()
        preloadTask = Task {
            let range = max(0, index - 2)...min(frames.count - 1, index + 2)
            for i in range {
                guard !Task.isCancelled else { return }
                let frame = frames[i]
                // Preload center tile at a reasonable zoom
                let tileX = lon2tileX(centerLon, zoom: zoomLevel)
                let tileY = lat2tileY(centerLat, zoom: zoomLevel)
                let urlString = frame.tileURL
                    .replacingOccurrences(of: "{z}", with: "\(zoomLevel)")
                    .replacingOccurrences(of: "{x}", with: "\(tileX)")
                    .replacingOccurrences(of: "{y}", with: "\(tileY)")
                if let url = URL(string: urlString) {
                    _ = await cache.fetchTile(url: url)
                }
            }
        }
    }

    func cancelPreload() {
        preloadTask?.cancel()
    }

    // Slippy map tile math
    private func lon2tileX(_ lon: Double, zoom: Int) -> Int {
        Int(floor((lon + 180.0) / 360.0 * pow(2.0, Double(zoom))))
    }

    private func lat2tileY(_ lat: Double, zoom: Int) -> Int {
        let latRad = lat * .pi / 180.0
        return Int(floor((1.0 - log(tan(latRad) + 1.0 / cos(latRad)) / .pi) / 2.0 * pow(2.0, Double(zoom))))
    }
}
