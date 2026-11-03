import SwiftUI

struct GrokBotSheet: View {
    @ObservedObject var navigation: NavigationViewModel
    @StateObject private var bot = GrokBotViewModel()
    @FocusState private var focused: Bool

    var body: some View {
        NavigationStack {
            ZStack {
                GTTheme.backgroundGradient.ignoresSafeArea()

                VStack(spacing: 0) {
                    calendarBanner

                    ScrollViewReader { proxy in
                        ScrollView {
                            LazyVStack(alignment: .leading, spacing: 12) {
                                ForEach(bot.messages) { message in
                                    ChatBubble(message: message)
                                        .id(message.id)
                                }
                                if bot.isThinking {
                                    HStack {
                                        ProgressView()
                                            .tint(GTTheme.gold)
                                        Text("Checking TripTrace…")
                                            .font(.caption)
                                            .foregroundStyle(.white.opacity(0.55))
                                    }
                                    .padding(.leading, 8)
                                }
                            }
                            .padding(16)
                        }
                        .onChange(of: bot.messages.count) { _, _ in
                            if let last = bot.messages.last?.id {
                                withAnimation {
                                    proxy.scrollTo(last, anchor: .bottom)
                                }
                            }
                        }
                    }

                    suggestionRow

                    composer
                }
            }
            .navigationTitle("Grok Bot")
            .navigationBarTitleDisplayMode(.inline)
            .toolbarBackground(.ultraThinMaterial, for: .navigationBar)
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    private var calendarBanner: some View {
        HStack(spacing: 12) {
            Image(systemName: "calendar")
                .foregroundStyle(GTTheme.gold)
            VStack(alignment: .leading, spacing: 2) {
                Text("Next Google Calendar event")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.5))
                Text(navigation.nextEvent.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.white)
                Text("\(navigation.nextEvent.locationName) · \(time(navigation.nextEvent.start))")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))
            }
            Spacer()
            if navigation.verificationOK {
                Image(systemName: "checkmark.seal.fill")
                    .foregroundStyle(GTTheme.good)
            }
        }
        .padding(14)
        .background(Color.white.opacity(0.05))
    }

    private var suggestionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(bot.suggestions, id: \.self) { suggestion in
                    Button {
                        bot.send(suggestion, trace: navigation.trip, event: navigation.nextEvent)
                    } label: {
                        Text(suggestion)
                            .font(.caption.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .foregroundStyle(.white.opacity(0.9))
                            .background(Color.white.opacity(0.08))
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    private var composer: some View {
        HStack(spacing: 10) {
            Button {
                bot.toggleListen(trace: navigation.trip, event: navigation.nextEvent)
            } label: {
                Image(systemName: bot.isListening ? "waveform.circle.fill" : "mic.circle.fill")
                    .font(.system(size: 34))
                    .foregroundStyle(bot.isListening ? GTTheme.bad : GTTheme.gold)
            }

            TextField("Ask about leave time, buses, confidence…", text: $bot.draft, axis: .vertical)
                .textFieldStyle(.plain)
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color.white.opacity(0.08))
                .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                .focused($focused)
                .foregroundStyle(.white)

            Button {
                bot.send(bot.draft, trace: navigation.trip, event: navigation.nextEvent)
            } label: {
                Image(systemName: "arrow.up.circle.fill")
                    .font(.system(size: 32))
                    .foregroundStyle(GTTheme.gold)
            }
            .disabled(bot.draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(.ultraThinMaterial)
    }

    private func time(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}

struct ChatBubble: View {
    let message: GrokMessage

    var body: some View {
        HStack {
            if message.role == .user { Spacer(minLength: 40) }

            VStack(alignment: message.role == .user ? .trailing : .leading, spacing: 6) {
                Text(message.text)
                    .font(.subheadline)
                    .foregroundStyle(message.role == .user ? GTTheme.ink : .white)
                    .padding(12)
                    .background(
                        message.role == .user ? GTTheme.gold : Color.white.opacity(0.08)
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

                if message.spokenFromTrace {
                    Label("Verified TripTrace", systemImage: "checkmark.seal.fill")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(GTTheme.good)
                }
            }

            if message.role != .user { Spacer(minLength: 40) }
        }
    }
}
