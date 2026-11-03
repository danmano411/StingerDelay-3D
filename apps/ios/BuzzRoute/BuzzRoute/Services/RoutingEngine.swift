import CoreLocation
import Foundation

/// Deterministic planner. Owns every numeric value (times, distances, probabilities).
/// Grok only interprets / speaks verified TripTrace output.
struct RoutingEngine {
    var walkSpeedMetersPerSecond: Double = 1.35
    var replayMode: Bool = true

    func plan(
        from origin: CampusPlace,
        to destination: CampusPlace,
        departAt: Date = .now,
        targetArrival: Date? = nil
    ) -> TripTrace {
        if origin.id == destination.id {
            return makeSamePlaceTrace(origin: origin, at: departAt)
        }

        let originStop = MockCampusData.nearestStop(to: origin)
        let destStop = MockCampusData.nearestStop(to: destination)
        let sharedLines = Set(originStop.stingerRoutes).intersection(destStop.stingerRoutes)
        let line = preferredLine(from: sharedLines, origin: origin, destination: destination)

        var segments: [RouteSegment] = []

        // 1) Walk to stop
        let walk1Meters = MockCampusData.distance(origin.coordinate, originStop.coordinate)
        let walk1 = walkQuantiles(meters: walk1Meters, horizonBias: 0)
        segments.append(
            RouteSegment(
                kind: .walk,
                title: "Walk to \(originStop.shortName)",
                detail: String(format: "%.0f m to boarding stop", walk1Meters),
                duration: walk1,
                distanceMeters: walk1Meters,
                fromCoordinate: origin.coordinate,
                toCoordinate: originStop.coordinate
            )
        )

        // 2) Wait for bus — tighter if near-term headway
        let headway = headwayMinutes(for: line)
        let wait = waitQuantiles(headway: headway)
        segments.append(
            RouteSegment(
                kind: .wait,
                title: "Wait for \(line.rawValue) Stinger",
                detail: String(format: "Typical headway %.0f min · replay GPS", headway),
                duration: wait,
                line: line,
                fromCoordinate: originStop.coordinate,
                toCoordinate: originStop.coordinate
            )
        )

        // 3) Optional transfer if no shared line
        let needsTransfer = sharedLines.isEmpty
        let rideStop = needsTransfer
            ? (MockCampusData.place(id: "stop-tech-green") ?? destStop)
            : destStop

        let ride1Meters = MockCampusData.distance(originStop.coordinate, rideStop.coordinate)
        let ride1 = rideQuantiles(meters: ride1Meters, line: line, horizonMinutes: walk1.p50 + wait.p50)
        segments.append(
            RouteSegment(
                kind: .ride,
                title: "Ride \(line.rawValue) toward \(rideStop.shortName)",
                detail: needsTransfer ? "Primary leg before transfer" : "Direct Stinger leg",
                duration: ride1,
                distanceMeters: ride1Meters,
                line: line,
                fromCoordinate: originStop.coordinate,
                toCoordinate: rideStop.coordinate
            )
        )

        if needsTransfer {
            let transferLine = preferredLine(
                from: Set(destStop.stingerRoutes),
                origin: origin,
                destination: destination
            )
            let transferWalkMeters = 120.0
            let transferWalk = walkQuantiles(meters: transferWalkMeters, horizonBias: 8)
            segments.append(
                RouteSegment(
                    kind: .transferWalk,
                    title: "Transfer at Tech Green",
                    detail: "Cross platform to \(transferLine.rawValue)",
                    duration: transferWalk,
                    distanceMeters: transferWalkMeters,
                    fromCoordinate: rideStop.coordinate,
                    toCoordinate: rideStop.coordinate
                )
            )

            let wait2 = waitQuantiles(headway: headwayMinutes(for: transferLine) + 1)
            segments.append(
                RouteSegment(
                    kind: .wait,
                    title: "Wait for \(transferLine.rawValue)",
                    detail: "Second boarding",
                    duration: wait2,
                    line: transferLine,
                    fromCoordinate: rideStop.coordinate,
                    toCoordinate: rideStop.coordinate
                )
            )

            let ride2Meters = MockCampusData.distance(rideStop.coordinate, destStop.coordinate)
            let prior = segments.reduce(0.0) { $0 + $1.duration.p50 }
            let ride2 = rideQuantiles(meters: ride2Meters, line: transferLine, horizonMinutes: prior)
            segments.append(
                RouteSegment(
                    kind: .ride,
                    title: "Ride \(transferLine.rawValue) to \(destStop.shortName)",
                    detail: "Final transit leg",
                    duration: ride2,
                    distanceMeters: ride2Meters,
                    line: transferLine,
                    fromCoordinate: rideStop.coordinate,
                    toCoordinate: destStop.coordinate
                )
            )
        }

        // Final walk
        let walk2Meters = MockCampusData.distance(
            needsTransfer ? destStop.coordinate : rideStop.coordinate,
            destination.coordinate
        )
        let priorTotal = segments.reduce(0.0) { $0 + $1.duration.p50 }
        let walk2 = walkQuantiles(meters: max(walk2Meters, 40), horizonBias: priorTotal / 10)
        segments.append(
            RouteSegment(
                kind: .walk,
                title: "Walk to \(destination.shortName)",
                detail: String(format: "%.0f m final approach", walk2Meters),
                duration: walk2,
                distanceMeters: walk2Meters,
                fromCoordinate: needsTransfer ? destStop.coordinate : rideStop.coordinate,
                toCoordinate: destination.coordinate
            )
        )

        let total = sumQuantiles(segments.map(\.duration))
        let horizon = total.p50
        let arrivalP50 = departAt.addingTimeInterval(total.p50 * 60)
        let arrivalP10 = departAt.addingTimeInterval(total.p10 * 60)
        let arrivalP90 = departAt.addingTimeInterval(total.p90 * 60)

        var pOnTime = 0.92
        if let target = targetArrival {
            let slack = target.timeIntervalSince(arrivalP50) / 60.0
            pOnTime = onTimeProbability(slackMinutes: slack, spread: total.spreadMinutes)
        } else {
            pOnTime = max(0.55, 0.95 - horizon / 400.0)
        }

        let widening: String? = horizon >= 60
            ? "Bands widen past ~60 min — check again closer to departure."
            : (horizon <= 3 ? "Near-term bus window: tight confidence." : nil)

        let confidence = ConfidenceBand(
            horizonMinutes: horizon,
            arrivalP10: arrivalP10,
            arrivalP50: arrivalP50,
            arrivalP90: arrivalP90,
            pOnTime: pOnTime,
            wideningNote: widening
        )

        let created = Date()
        let trace = TripTrace(
            id: UUID(),
            createdAt: created,
            origin: origin,
            destination: destination,
            segments: segments,
            totalDuration: total,
            confidence: confidence,
            replayMode: replayMode,
            verificationToken: TripVerification.makeToken(
                originID: origin.id,
                destinationID: destination.id,
                createdAt: created
            )
        )

        return trace
    }

    // MARK: - Quantile helpers (stand-in for Stinger Delay Monte Carlo)

    private func walkQuantiles(meters: Double, horizonBias: Double) -> DurationQuantiles {
        let base = max(1.0, meters / walkSpeedMetersPerSecond / 60.0)
        let widen = 0.12 + min(0.35, horizonBias / 80.0)
        return DurationQuantiles(
            p10: max(0.8, base * (1 - widen)),
            p50: base,
            p90: base * (1 + widen * 1.4)
        )
    }

    private func waitQuantiles(headway: Double) -> DurationQuantiles {
        // Uniform-ish wait assumption with Stinger Delay style skew
        let p50 = headway * 0.45
        return DurationQuantiles(
            p10: max(0.3, p50 * 0.35),
            p50: p50,
            p90: max(p50 + 0.8, headway * 0.95)
        )
    }

    private func rideQuantiles(meters: Double, line: StingerLine, horizonMinutes: Double) -> DurationQuantiles {
        let busSpeed = 6.2 // m/s urban campus average with stops
        let base = max(1.5, meters / busSpeed / 60.0) + dwellPadding(for: line)
        let delayFactor = 1.0 + min(0.55, horizonMinutes / 120.0)
        return DurationQuantiles(
            p10: base * 0.85,
            p50: base * (0.95 + (delayFactor - 1) * 0.25),
            p90: base * delayFactor
        )
    }

    private func dwellPadding(for line: StingerLine) -> Double {
        switch line {
        case .trolley: return 0.6
        case .red: return 0.9
        case .blue: return 0.8
        case .green: return 1.1
        }
    }

    private func headwayMinutes(for line: StingerLine) -> Double {
        switch line {
        case .red: return 8
        case .blue: return 10
        case .green: return 12
        case .trolley: return 7
        }
    }

    private func preferredLine(from lines: Set<String>, origin: CampusPlace, destination: CampusPlace) -> StingerLine {
        let ordered: [StingerLine] = [.red, .blue, .trolley, .green]
        if let match = ordered.first(where: { lines.contains($0.rawValue) }) {
            return match
        }
        // Fall back to destination-serving line
        if let match = ordered.first(where: { destination.stingerRoutes.contains($0.rawValue) }) {
            return match
        }
        return .red
    }

    private func sumQuantiles(_ values: [DurationQuantiles]) -> DurationQuantiles {
        DurationQuantiles(
            p10: values.reduce(0) { $0 + $1.p10 },
            p50: values.reduce(0) { $0 + $1.p50 },
            p90: values.reduce(0) { $0 + $1.p90 }
        )
    }

    private func onTimeProbability(slackMinutes: Double, spread: Double) -> Double {
        if slackMinutes >= spread { return 0.94 }
        if slackMinutes >= spread * 0.5 { return 0.82 }
        if slackMinutes >= 0 { return 0.68 }
        if slackMinutes >= -spread * 0.5 { return 0.42 }
        return 0.22
    }

    private func makeSamePlaceTrace(origin: CampusPlace, at date: Date) -> TripTrace {
        let duration = DurationQuantiles(p10: 0, p50: 0, p90: 0)
        let segment = RouteSegment(
            kind: .walk,
            title: "Already there",
            detail: origin.name,
            duration: duration,
            distanceMeters: 0,
            fromCoordinate: origin.coordinate,
            toCoordinate: origin.coordinate
        )
        return TripTrace(
            id: UUID(),
            createdAt: date,
            origin: origin,
            destination: origin,
            segments: [segment],
            totalDuration: duration,
            confidence: ConfidenceBand(
                horizonMinutes: 0,
                arrivalP10: date,
                arrivalP50: date,
                arrivalP90: date,
                pOnTime: 1,
                wideningNote: nil
            ),
            replayMode: replayMode,
            verificationToken: TripVerification.makeToken(
                originID: origin.id,
                destinationID: origin.id,
                createdAt: date
            )
        )
    }
}
