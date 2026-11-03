import Foundation
import SwiftUI

@MainActor
final class GrokBotViewModel: ObservableObject {
    @Published var messages: [GrokMessage] = []
    @Published var draft: String = ""
    @Published var isListening: Bool = false
    @Published var isThinking: Bool = false

    private let bot = GrokBotService()

    let suggestions = [
        "Hey Grok, using my calendar, when should I leave?",
        "Explain this confidence band",
        "How delayed is my Stinger?"
    ]

    init() {
        messages = [
            GrokMessage(
                role: .assistant,
                text: "I’m Grok Bot for Buzz Route. I only speak numbers from a verified TripTrace — ask me when to leave for your next event."
            )
        ]
    }

    func send(_ text: String, trace: TripTrace?, event: CalendarEvent?) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        messages.append(GrokMessage(role: .user, text: trimmed))
        draft = ""
        isThinking = true

        // Light delay so the sheet feels conversational
        Task {
            try? await Task.sleep(nanoseconds: 450_000_000)
            let reply = bot.respond(to: trimmed, trace: trace, nextEvent: event)
            messages.append(reply)
            isThinking = false
        }
    }

    func toggleListen(trace: TripTrace?, event: CalendarEvent?) {
        if isListening {
            isListening = false
            // Simulated speech result for Simulator demos
            send("Hey Grok, using my calendar, when should I leave for the next event?", trace: trace, event: event)
        } else {
            isListening = true
            Task {
                try? await Task.sleep(nanoseconds: 1_400_000_000)
                if isListening {
                    toggleListen(trace: trace, event: event)
                }
            }
        }
    }
}
