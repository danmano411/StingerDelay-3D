import Foundation

enum VerificationError: LocalizedError {
    case missingToken
    case mismatchedTotals
    case unverifiedSpeech
    case numberNotAllowed(Double)

    var errorDescription: String? {
        switch self {
        case .missingToken:
            return "TripTrace is missing a verification token."
        case .mismatchedTotals:
            return "Segment durations do not match TripTrace totals."
        case .unverifiedSpeech:
            return "Refusing to speak numbers that are not backed by a verified TripTrace."
        case .numberNotAllowed(let n):
            return "Number \(n) is not in TripTrace.allowed_numbers."
        }
    }
}

enum TripVerification {
    /// Every number shown or spoken must come from a TripTrace and pass this check.
    static func verify(_ trace: TripTrace) throws {
        guard !trace.verificationToken.isEmpty else {
            throw VerificationError.missingToken
        }

        let segmentP50 = trace.segments.reduce(0.0) { $0 + $1.duration.p50 }
        let delta = abs(segmentP50 - trace.totalDuration.p50)
        // Allow tiny float / rounding slack (local planner) or API leg-vs-total skew
        guard delta <= 3.0 else {
            throw VerificationError.mismatchedTotals
        }
    }

    static func isVerified(_ trace: TripTrace) -> Bool {
        (try? verify(trace)) != nil
    }

    /// When `allowedNumbers` is non-empty (API plans), only those values may be spoken.
    static func assertAllowed(_ value: Double, in trace: TripTrace) throws {
        guard !trace.allowedNumbers.isEmpty else { return }
        let ok = trace.allowedNumbers.contains { abs($0 - value) < 0.51 || abs($0 - value * 60) < 0.51 }
        if !ok {
            throw VerificationError.numberNotAllowed(value)
        }
    }

    static func makeToken(originID: String, destinationID: String, createdAt: Date) -> String {
        let stamp = Int(createdAt.timeIntervalSince1970) % 100_000
        return "TR-\(originID.prefix(3).uppercased())\(destinationID.prefix(3).uppercased())-\(stamp)"
    }
}
