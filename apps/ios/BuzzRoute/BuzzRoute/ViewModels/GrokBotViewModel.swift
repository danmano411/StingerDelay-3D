import Foundation
import SwiftUI

@MainActor
final class GrokBotViewModel: ObservableObject {
    @Published var messages: [GrokMessage] = []
    @Published var draft: String = ""
    @Published var isListening: Bool = false
    @Published var isThinking: Bool = false
    @Published var conversationID: String = UUID().uuidString
    @Published var lastAction: String?

    private let bot = GrokBotService()

    let suggestions = [
        "Get me to Klaus by 8:30",
        "Hey Grok, using my calendar, when should I leave?",
        "Explain this confidence band",
        "Walk that path"
    ]

    init() {
        messages = [
            GrokMessage(
                role: .assistant,
                text: "I’m Grok Bot for Buzz Route. Ask “Get me to Klaus by 8:30” — numbers come from the shared API TripTrace when the server is up."
            )
        ]
    }

    func send(_ text: String, navigation: NavigationViewModel) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(GrokMessage(role: .user, text: trimmed))
        draft = ""
        isThinking = true

        Task {
            let reply = await bot.respond(
                to: trimmed,
                conversationID: conversationID,
                navigation: navigation
            )
            if let newID = reply.conversationID {
                conversationID = newID
            }
            lastAction = reply.action
            messages.append(reply.message)
            if let trace = reply.trace {
                navigation.trip = trace
                navigation.verificationOK = TripVerification.isVerified(trace)
                navigation.usingServerPlan = trace.apiTrace != nil
                if navigation.destination == nil {
                    navigation.destination = trace.destination
                }
            }
            isThinking = false
        }
    }

    func toggleListen(navigation: NavigationViewModel) {
        if isListening {
            isListening = false
            send("Get me to Klaus by 8:30", navigation: navigation)
        } else {
            isListening = true
            Task {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                if isListening {
                    toggleListen(navigation: navigation)
                }
            }
        }
    }
}
