import CoreLocation
import Foundation

enum SegmentKind: String, Codable, CaseIterable, Identifiable {
    case walk
    case wait
    case ride
    case transferWalk

    var id: String { rawValue }

    var label: String {
        switch self {
        case .walk: return "Walk"
        case .wait: return "Wait"
        case .ride: return "Ride"
        case .transferWalk: return "Transfer walk"
        }
    }

    var systemImage: String {
        switch self {
        case .walk, .transferWalk: return "figure.walk"
        case .wait: return "hourglass"
        case .ride: return "bus.fill"
        }
    }
}

struct DurationQuantiles: Hashable, Codable {
    /// Minutes
    let p10: Double
    let p50: Double
    let p90: Double

    var spreadMinutes: Double { max(0, p90 - p10) }

    func formattedBand() -> String {
        String(format: "%.0f–%.0f min", p10, p90)
    }

    func formattedTypical() -> String {
        String(format: "%.0f min", p50)
    }
}

struct RouteSegment: Identifiable, Hashable, Codable {
    let id: UUID
    let kind: SegmentKind
    let title: String
    let detail: String
    let duration: DurationQuantiles
    let distanceMeters: Double?
    let line: StingerLine?
    let fromCoordinate: CLLocationCoordinate2D
    let toCoordinate: CLLocationCoordinate2D

    enum CodingKeys: String, CodingKey {
        case id, kind, title, detail, duration, distanceMeters, line
        case fromLat, fromLon, toLat, toLon
    }

    init(
        id: UUID = UUID(),
        kind: SegmentKind,
        title: String,
        detail: String,
        duration: DurationQuantiles,
        distanceMeters: Double? = nil,
        line: StingerLine? = nil,
        fromCoordinate: CLLocationCoordinate2D,
        toCoordinate: CLLocationCoordinate2D
    ) {
        self.id = id
        self.kind = kind
        self.title = title
        self.detail = detail
        self.duration = duration
        self.distanceMeters = distanceMeters
        self.line = line
        self.fromCoordinate = fromCoordinate
        self.toCoordinate = toCoordinate
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        kind = try c.decode(SegmentKind.self, forKey: .kind)
        title = try c.decode(String.self, forKey: .title)
        detail = try c.decode(String.self, forKey: .detail)
        duration = try c.decode(DurationQuantiles.self, forKey: .duration)
        distanceMeters = try c.decodeIfPresent(Double.self, forKey: .distanceMeters)
        line = try c.decodeIfPresent(StingerLine.self, forKey: .line)
        fromCoordinate = CLLocationCoordinate2D(
            latitude: try c.decode(Double.self, forKey: .fromLat),
            longitude: try c.decode(Double.self, forKey: .fromLon)
        )
        toCoordinate = CLLocationCoordinate2D(
            latitude: try c.decode(Double.self, forKey: .toLat),
            longitude: try c.decode(Double.self, forKey: .toLon)
        )
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(kind, forKey: .kind)
        try c.encode(title, forKey: .title)
        try c.encode(detail, forKey: .detail)
        try c.encode(duration, forKey: .duration)
        try c.encodeIfPresent(distanceMeters, forKey: .distanceMeters)
        try c.encodeIfPresent(line, forKey: .line)
        try c.encode(fromCoordinate.latitude, forKey: .fromLat)
        try c.encode(fromCoordinate.longitude, forKey: .fromLon)
        try c.encode(toCoordinate.latitude, forKey: .toLat)
        try c.encode(toCoordinate.longitude, forKey: .toLon)
    }

    static func == (lhs: RouteSegment, rhs: RouteSegment) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}

struct ConfidenceBand: Hashable, Codable {
    let horizonMinutes: Double
    let arrivalP10: Date
    let arrivalP50: Date
    let arrivalP90: Date
    let pOnTime: Double
    let wideningNote: String?

    var isWide: Bool { horizonMinutes >= 60 }
}

struct TripTrace: Identifiable, Hashable, Codable {
    let id: UUID
    let createdAt: Date
    let origin: CampusPlace
    let destination: CampusPlace
    let segments: [RouteSegment]
    let totalDuration: DurationQuantiles
    let confidence: ConfidenceBand
    let replayMode: Bool
    let verificationToken: String

    var polylineCoordinates: [CLLocationCoordinate2D] {
        var coords: [CLLocationCoordinate2D] = []
        for segment in segments {
            if coords.isEmpty {
                coords.append(segment.fromCoordinate)
            }
            coords.append(segment.toCoordinate)
        }
        return coords
    }

    var spokenSummary: String {
        let eta = totalDuration.formattedTypical()
        let band = totalDuration.formattedBand()
        let onTime = Int((confidence.pOnTime * 100).rounded())
        return "TripTrace \(verificationToken): typical \(eta), band \(band), on-time probability \(onTime) percent."
    }
}

