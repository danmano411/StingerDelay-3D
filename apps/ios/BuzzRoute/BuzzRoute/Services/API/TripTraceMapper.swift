import CoreLocation
import Foundation

enum TripTraceMapper {
    /// Maps OpenAPI TripTrace (seconds) into the SwiftUI TripTrace (minutes + map geometry).
    static func toUI(
        _ api: APITripTrace,
        origin: CampusPlace,
        destination: CampusPlace,
        replayMode: Bool
    ) -> TripTrace {
        let plan = api.plan
        let totalMinutes = DurationQuantiles(
            p10: plan.total_s.p10 / 60.0,
            p50: plan.total_s.p50 / 60.0,
            p90: plan.total_s.p90 / 60.0
        )

        let leaveAt = parseDate(plan.leave_at) ?? .now
        let arriveAt = parseDate(plan.arrive_at) ?? leaveAt.addingTimeInterval(plan.total_s.p50)
        let arriveP10 = leaveAt.addingTimeInterval(plan.total_s.p10)
        let arriveP90 = leaveAt.addingTimeInterval(plan.total_s.p90)

        let segments = plan.legs.map { leg in
            mapLeg(leg, fallbackFrom: origin.coordinate, fallbackTo: destination.coordinate)
        }

        let widening: String? = api.confidence_horizon_s >= 3600
            ? "Bands widen past ~60 min — check again closer to departure."
            : api.social_factor.map { "Social factor \($0.label) (badged) · spread ×\($0.spread_multiplier)" }

        let confidence = ConfidenceBand(
            horizonMinutes: api.confidence_horizon_s / 60.0,
            arrivalP10: arriveP10,
            arrivalP50: arriveAt,
            arrivalP90: arriveP90,
            pOnTime: plan.p_on_time,
            wideningNote: widening
        )

        let token = "API-\(api.model_id)-\(Int(leaveAt.timeIntervalSince1970) % 100_000)"

        return TripTrace(
            id: UUID(),
            createdAt: .now,
            origin: origin.renamed(api.origin_name),
            destination: destination.renamed(api.destination_name),
            segments: segments,
            totalDuration: totalMinutes,
            confidence: confidence,
            replayMode: replayMode,
            verificationToken: token,
            allowedNumbers: api.allowed_numbers ?? [],
            apiTrace: api
        )
    }

    private static func mapLeg(
        _ leg: APILeg,
        fallbackFrom: CLLocationCoordinate2D,
        fallbackTo: CLLocationCoordinate2D
    ) -> RouteSegment {
        let kind: SegmentKind = {
            switch leg.kind {
            case "wait": return .wait
            case "ride": return .ride
            case "transfer_walk": return .transferWalk
            default: return .walk
            }
        }()

        let path = leg.path ?? []
        let from: CLLocationCoordinate2D = {
            if let first = path.first, first.count >= 2 {
                return CLLocationCoordinate2D(latitude: first[0], longitude: first[1])
            }
            return fallbackFrom
        }()
        let to: CLLocationCoordinate2D = {
            if let last = path.last, last.count >= 2 {
                return CLLocationCoordinate2D(latitude: last[0], longitude: last[1])
            }
            return path.isEmpty ? fallbackTo : from
        }()

        let minutes = max(0.1, leg.duration_s_p50 / 60.0)
        let duration = DurationQuantiles(
            p10: minutes * 0.85,
            p50: minutes,
            p90: minutes * 1.2
        )

        let line: StingerLine? = leg.route_id.flatMap { id in
            CampusCatalog.routes.first(where: { String($0.id) == id }).map {
                StingerLine.from(routeName: $0.name)
            }
        }

        var detailParts: [String] = []
        if let d = leg.distance_m {
            detailParts.append(String(format: "%.0f m", d))
        }
        if leg.synthetic == true {
            detailParts.append("synthetic")
        }
        if leg.estimate == true {
            detailParts.append("estimate")
        }

        return RouteSegment(
            kind: kind,
            title: leg.label,
            detail: detailParts.isEmpty ? kind.label : detailParts.joined(separator: " · "),
            duration: duration,
            distanceMeters: leg.distance_m,
            line: line,
            fromCoordinate: from,
            toCoordinate: to
        )
    }

    private static func parseDate(_ raw: String) -> Date? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let d = iso.date(from: raw) { return d }
        iso.formatOptions = [.withInternetDateTime]
        if let d = iso.date(from: raw) { return d }
        let fallback = DateFormatter()
        fallback.locale = Locale(identifier: "en_US_POSIX")
        fallback.timeZone = TimeZone(identifier: "America/New_York")
        fallback.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXXXX"
        return fallback.date(from: raw)
    }
}

private extension CampusPlace {
    func renamed(_ apiName: String?) -> CampusPlace {
        guard let apiName, !apiName.isEmpty else { return self }
        return CampusPlace(
            id: id,
            name: apiName,
            shortName: apiName.count <= 22 ? apiName : String(apiName.prefix(20)) + "…",
            kind: kind,
            latitude: latitude,
            longitude: longitude,
            stingerRoutes: stingerRoutes
        )
    }
}
