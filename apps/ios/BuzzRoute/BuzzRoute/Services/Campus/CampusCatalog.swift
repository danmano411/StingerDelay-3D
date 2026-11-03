import CoreLocation
import Foundation

struct StingerStopGeo: Identifiable, Hashable, Codable {
    let id: Int
    let name: String
    let lat: Double
    let lon: Double
    let dwell: Int?
    let to_next: Int?

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: lat, longitude: lon)
    }

    var shortName: String {
        if name.count <= 22 { return name }
        return String(name.prefix(20)) + "…"
    }
}

struct StingerRouteGeo: Identifiable, Hashable, Codable {
    let id: Int
    let name: String
    let color: String
    let line: [[Double]]
    let stops: [StingerStopGeo]

    /// Blue is synthetic in the twin / product rules.
    var isSynthetic: Bool { name.lowercased() == "blue" }

    var coordinates: [CLLocationCoordinate2D] {
        line.compactMap { pair in
            guard pair.count >= 2 else { return nil }
            return CLLocationCoordinate2D(latitude: pair[0], longitude: pair[1])
        }
    }

    /// Distance-parameterized position along the polyline (meters from start).
    func coordinate(atDistance meters: Double) -> CLLocationCoordinate2D? {
        let coords = coordinates
        guard coords.count >= 2 else { return coords.first }
        var remaining = max(0, meters)
        for i in 0..<(coords.count - 1) {
            let a = coords[i]
            let b = coords[i + 1]
            let seg = CLLocation(latitude: a.latitude, longitude: a.longitude)
                .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
            if remaining <= seg || i == coords.count - 2 {
                let t = seg > 0 ? min(1, remaining / seg) : 0
                return CLLocationCoordinate2D(
                    latitude: a.latitude + (b.latitude - a.latitude) * t,
                    longitude: a.longitude + (b.longitude - a.longitude) * t
                )
            }
            remaining -= seg
        }
        return coords.last
    }

    var totalLengthMeters: Double {
        let coords = coordinates
        guard coords.count >= 2 else { return 0 }
        var sum = 0.0
        for i in 0..<(coords.count - 1) {
            sum += CLLocation(latitude: coords[i].latitude, longitude: coords[i].longitude)
                .distance(from: CLLocation(latitude: coords[i + 1].latitude, longitude: coords[i + 1].longitude))
        }
        return sum
    }
}

enum CampusCatalog {
    static let campusCenter = CLLocationCoordinate2D(latitude: 33.7756, longitude: -84.3963)

    static let routes: [StingerRouteGeo] = {
        guard let url = Bundle.main.url(forResource: "routes", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([StingerRouteGeo].self, from: data)
        else {
            return []
        }
        return decoded
    }()

    static var allStops: [StingerStopGeo] {
        var seen = Set<Int>()
        var out: [StingerStopGeo] = []
        for route in routes {
            for stop in route.stops where !seen.contains(stop.id) {
                seen.insert(stop.id)
                out.append(stop)
            }
        }
        return out
    }

    /// Place a demo bus on each route using seconds-of-day.
    static func buses(atSecondsOfDay t: Double) -> [LiveBus] {
        routes.enumerated().compactMap { index, route in
            let length = route.totalLengthMeters
            guard length > 50 else { return nil }
            // Stagger routes; loop every ~25 minutes of sim time at 1x
            let period = 25.0 * 60.0
            let phase = Double(index) * 90.0
            let dist = ((t + phase).truncatingRemainder(dividingBy: period) / period) * length
            guard let coord = route.coordinate(atDistance: dist) else { return nil }
            let line = StingerLine.from(routeName: route.name)
            return LiveBus(
                id: "route-\(route.id)",
                line: line,
                coordinate: coord,
                heading: 0,
                delayMinutes: route.isSynthetic ? 0 : Double(index) * 0.4
            )
        }
    }
}

extension StingerLine {
    static func from(routeName: String) -> StingerLine {
        switch routeName.lowercased() {
        case "red": return .red
        case "blue": return .blue
        case "green": return .green
        case "gold": return .gold
        case "clough": return .clough
        case "trolley": return .trolley
        default: return .gold
        }
    }
}
