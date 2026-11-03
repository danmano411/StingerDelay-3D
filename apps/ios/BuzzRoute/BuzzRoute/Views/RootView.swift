import SwiftUI

struct RootView: View {
    @StateObject private var model = NavigationViewModel()

    var body: some View {
        ZStack(alignment: .top) {
            ZStack {
                GTTheme.backgroundGradient
                if model.showTwin3D {
                    CampusTwinWebView(reloadToken: model.twinReloadToken)
                } else {
                    CampusMapView(model: model)
                }
            }
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                Spacer()
                if !model.showTwin3D {
                    bottomPanel
                } else {
                    twinChrome
                }
            }
        }
        .sheet(isPresented: $model.showDestinationPicker) {
            DestinationPicker(model: model)
        }
        .sheet(isPresented: $model.showGrokBot) {
            GrokBotSheet(navigation: model)
        }
        .preferredColorScheme(.dark)
    }

    private var twinChrome: some View {
        VStack(spacing: 10) {
            Text("3D campus twin · orbit with one finger · pinch to zoom · timeline at bottom of scene")
                .font(.caption2)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)

            HStack(spacing: 10) {
                BuzzPrimaryButton(title: "Ask Grok", systemImage: "waveform") {
                    model.showGrokBot = true
                }
                .accessibilityIdentifier("askGrokTwin")
                BuzzPrimaryButton(title: "Plan on Map", systemImage: "map", filled: false) {
                    model.showTwin3D = false
                }
                .accessibilityIdentifier("planOnMap")
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)
        }
        .accessibilityIdentifier("twinChrome")
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GEORGIA TECH")
                        .font(.caption2.weight(.bold).monospaced())
                        .tracking(1.6)
                        .foregroundStyle(GTTheme.gold)
                    Text("Buzz Route")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                Button {
                    model.showTwin3D.toggle()
                } label: {
                    Image(systemName: model.showTwin3D ? "map.fill" : "cube.transparent.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(GTTheme.gold)
                        .accessibilityLabel(model.showTwin3D ? "Show map" : "Show 3D twin")
                }
                .accessibilityIdentifier("toggleTwinMap")
                Button {
                    model.showGrokBot = true
                } label: {
                    Image(systemName: "waveform.circle.fill")
                        .font(.system(size: 30))
                        .foregroundStyle(GTTheme.gold)
                }
                .accessibilityIdentifier("openGrokHeader")
            }

            HStack(spacing: 8) {
                Label(model.origin.shortName, systemImage: "location.fill")
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(GTTheme.good.opacity(0.2))
                    .foregroundStyle(GTTheme.good)
                    .clipShape(Capsule())

                Image(systemName: "arrow.right")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(.white.opacity(0.4))

                Button {
                    model.showDestinationPicker = true
                } label: {
                    Label(
                        model.destination?.shortName ?? "Choose destination",
                        systemImage: "flag.fill"
                    )
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(GTTheme.gold.opacity(0.18))
                    .foregroundStyle(GTTheme.gold)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)

                Spacer()

                Toggle(isOn: $model.replayMode) {
                    Text("Replay")
                        .font(.caption2.weight(.bold))
                }
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(GTTheme.gold)
                .onChange(of: model.replayMode) { _, _ in
                    if model.destination != nil { model.plan() }
                }
            }
        }
        .padding(16)
        .background(
            RoundedRectangle(cornerRadius: 0)
                .fill(.ultraThinMaterial)
                .ignoresSafeArea(edges: .top)
        )
    }

    private var bottomPanel: some View {
        VStack(spacing: 12) {
            if let message = model.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(GTTheme.bad)
                    .padding(.horizontal)
            }

            if let trip = model.trip {
                PlanCardView(trip: trip) {
                    model.showGrokBot = true
                }
                .padding(.horizontal, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                VStack(spacing: 12) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Next up")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.white.opacity(0.45))
                            Text(model.nextEvent.title)
                                .font(.headline)
                                .foregroundStyle(.white)
                            Text("\(model.nextEvent.locationName)")
                                .font(.caption)
                                .foregroundStyle(.white.opacity(0.55))
                        }
                        Spacer()
                        Text(shortTime(model.nextEvent.start))
                            .font(.title3.weight(.bold).monospaced())
                            .foregroundStyle(GTTheme.gold)
                    }

                    HStack(spacing: 10) {
                        BuzzPrimaryButton(
                            title: "Leave for calendar event",
                            systemImage: "calendar.badge.clock",
                            action: model.planForNextCalendarEvent
                        )
                        BuzzPrimaryButton(
                            title: "Pick place",
                            systemImage: "map",
                            filled: false
                        ) {
                            model.showDestinationPicker = true
                        }
                    }
                }
                .padding(16)
                .background(
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .fill(GTTheme.panel)
                        .overlay(
                            RoundedRectangle(cornerRadius: 22, style: .continuous)
                                .stroke(Color.white.opacity(0.08), lineWidth: 1)
                        )
                )
                .padding(.horizontal, 12)
            }
        }
        .padding(.bottom, 10)
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: model.trip?.id)
    }

    private func shortTime(_ date: Date) -> String {
        let f = DateFormatter()
        f.timeStyle = .short
        return f.string(from: date)
    }
}

struct DestinationPicker: View {
    @ObservedObject var model: NavigationViewModel
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            List(model.destinations) { place in
                Button {
                    model.selectDestination(place)
                } label: {
                    HStack(spacing: 12) {
                        Image(systemName: place.kind == .landmark ? "mappin.and.ellipse" : "building.2.fill")
                            .foregroundStyle(GTTheme.gold)
                            .frame(width: 28)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(place.name)
                                .foregroundStyle(.primary)
                            Text(place.stingerRoutes.joined(separator: " · "))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        if model.destination?.id == place.id {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(GTTheme.gold)
                        }
                    }
                }
            }
            .navigationTitle("Destination")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Close") { dismiss() }
                }
            }
        }
        .presentationDetents([.medium, .large])
    }
}
