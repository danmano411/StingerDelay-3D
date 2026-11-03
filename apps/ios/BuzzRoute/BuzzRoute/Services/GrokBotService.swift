import Foundation

struct GrokMessage: Identifiable, Hashable {
    enum Role: String {
        case user
        case assistant
        case system
    }

    let id: UUID
    let role: Role
    let text: String
    let spokenFromTrace: Bool
    let createdAt: Date

    init(
        id: UUID = UUID(),
        role: Role,
        text: String,
        spokenFromTrace: Bool = false,
        createdAt: Date = .now
    ) {
        self.id = id
        self.role = role
        self.text = text
        self.spokenFromTrace = spokenFromTrace
        self.createdAt = createdAt
    }
}

struct GrokBotReply {
    let message: GrokMessage
    let trace: TripTrace?
    let action: String?
    let conversationID: String?
}

/// Talks to `POST /grok/chat` when the API is up; otherwise interprets a verified local TripTrace.
struct GrokBotService {
    @MainActor
    func respond(
        to prompt: String,
        conversationID: String,
        navigation: NavigationViewModel
    ) async -> GrokBotReply {
        let origin = APIChatOrigin(lat: navigation.origin.latitude, lon: navigation.origin.longitude)
        do {
            let response = try await BuzzAPIClient.shared.grokChat(
                conversationID: conversationID,
                message: prompt,
                origin: origin
            )
            navigation.apiReachable = true

            var mapped: TripTrace?
            if let apiTrace = response.trace {
                let dest = navigation.destination
                    ?? NormalizedCatalog.place(id: "klaus")
                    ?? navigation.origin
                mapped = TripTraceMapper.toUI(
                    apiTrace,
                    origin: navigation.origin,
                    destination: dest,
                    replayMode: navigation.replayMode
                )
                if let mapped {
                    try? TripVerification.verify(mapped)
                }
            }

            let msg = GrokMessage(
                role: .assistant,
                text: response.reply,
                spokenFromTrace: response.verified
            )
            return GrokBotReply(
                message: msg,
                trace: mapped,
                action: response.action,
                conversationID: response.conversation_id
            )
        } catch {
            navigation.apiReachable = false
            let local = localRespond(
                to: prompt,
                trace: navigation.trip,
                nextEvent: navigation.nextEvent
            )
            let note = GrokMessage(
                role: .assistant,
                text: "\(local.text)\n\n(API offline at \(APIConfig.baseURL.host ?? "localhost") — local TripTrace only.)",
                spokenFromTrace: local.spokenFromTrace
            )
            return GrokBotReply(message: note, trace: nil, action: nil, conversationID: conversationID)
        }
    }

    private func localRespond(
        to prompt: String,
        trace: TripTrace?,
        nextEvent: CalendarEvent?
    ) -> GrokMessage {
        let lowered = prompt.lowercased()

        if lowered.contains("calendar") || lowered.contains("leave") || lowered.contains("when should") {
            return leaveAdvice(trace: trace, event: nextEvent)
        }

        if lowered.contains("explain") || lowered.contains("why") || lowered.contains("confidence") {
            return explainConfidence(trace: trace)
        }

        if lowered.contains("bus") || lowered.contains("stinger") || lowered.contains("delay") {
            return busStatus(trace: trace)
        }

        if let trace, TripVerification.isVerified(trace) {
            return GrokMessage(
                role: .assistant,
                text: """
                Here’s the verified plan \(trace.verificationToken):
                \(trace.origin.shortName) → \(trace.destination.shortName).
                Typical \(trace.totalDuration.formattedTypical()) (band \(trace.totalDuration.formattedBand())).
                On-time probability \(percent(trace.confidence.pOnTime)).
                Ask me when to leave for your next calendar event, or to explain the confidence band.
                """,
                spokenFromTrace: true
            )
        }

        return GrokMessage(
            role: .assistant,
            text: "Plan a trip on the map first — I only speak numbers that come from a verified TripTrace."
        )
    }

    private func leaveAdvice(trace: TripTrace?, event: CalendarEvent?) -> GrokMessage {
        guard let event else {
            return GrokMessage(
                role: .assistant,
                text: "I don’t see a next Google Calendar event yet. Connect calendar on the backend, or pick a destination manually."
            )
        }

        guard let trace, TripVerification.isVerified(trace) else {
            return GrokMessage(
                role: .assistant,
                text: "Your next event is \(event.title) at \(event.locationName). Plan a route there and I’ll compute leave time from the TripTrace."
            )
        }

        let leaveBy = event.start.addingTimeInterval(-trace.totalDuration.p90 * 60)
        let formatter = DateFormatter()
        formatter.timeStyle = .short

        var text = """
        Next event: \(event.title) at \(formatter.string(from: event.start)) (\(event.locationName)).
        Verified TripTrace \(trace.verificationToken) needs about \(trace.totalDuration.formattedTypical()) typical, \(trace.totalDuration.formattedBand()) band.
        Leave by \(formatter.string(from: leaveBy)) to cover the p90 arrival (\(percent(trace.confidence.pOnTime)) on-time vs that window).
        """

        if let note = trace.confidence.wideningNote {
            text += "\n\(note)"
        }

        return GrokMessage(role: .assistant, text: text, spokenFromTrace: true)
    }

    private func explainConfidence(trace: TripTrace?) -> GrokMessage {
        guard let trace, TripVerification.isVerified(trace) else {
            return GrokMessage(role: .assistant, text: "No verified TripTrace yet — I won’t invent a confidence band.")
        }

        let horizon = Int(trace.confidence.horizonMinutes.rounded())
        var text = """
        Confidence for \(trace.verificationToken): horizon ~\(horizon) min.
        Arrival window \(time(trace.confidence.arrivalP10))–\(time(trace.confidence.arrivalP90)) (p50 \(time(trace.confidence.arrivalP50))).
        On-time probability \(percent(trace.confidence.pOnTime)).
        Bands come from Monte Carlo over Stinger Delay quantiles — they widen as the horizon grows.
        """
        if let note = trace.confidence.wideningNote {
            text += "\n\(note)"
        }
        return GrokMessage(role: .assistant, text: text, spokenFromTrace: true)
    }

    private func busStatus(trace: TripTrace?) -> GrokMessage {
        guard let trace, TripVerification.isVerified(trace) else {
            return GrokMessage(
                role: .assistant,
                text: "Replay buses are on the map. Plan a trip to lock wait/ride minutes to a TripTrace."
            )
        }

        let wait = trace.segments.first(where: { $0.kind == .wait })
        let ride = trace.segments.first(where: { $0.kind == .ride })
        let waitText = wait.map { "Wait \( $0.duration.formattedBand() )" } ?? "No wait segment"
        let rideText = ride.map { "Ride \( $0.line?.rawValue ?? "Stinger" ) \( $0.duration.formattedBand() )" } ?? "No ride segment"

        return GrokMessage(
            role: .assistant,
            text: "From \(trace.verificationToken): \(waitText); \(rideText). All figures verified from the planner.",
            spokenFromTrace: true
        )
    }

    private func percent(_ value: Double) -> String {
        "\(Int((value * 100).rounded()))%"
    }

    private func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}
