import SwiftUI

struct RootView: View {
    @StateObject private var model = NavigationViewModel()

    var body: some View {
        ZStack {
            GTTheme.backgroundGradient.ignoresSafeArea()

            Group {
                if model.showTwin3D {
                    CampusTwinWebView(reloadToken: model.twinReloadToken)
                } else {
                    CampusMapView(model: model)
                }
            }
            .ignoresSafeArea(edges: .horizontal)
        }
        .safeAreaInset(edge: .top, spacing: 0) {
            topBar
        }
        .safeAreaInset(edge: .bottom, spacing: 0) {
            if model.showTwin3D {
                twinChrome
            } else {
                bottomPanel
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

    /// Bottom actions for 3D mode — solid inset panel (web twin chrome is hidden).
    private var twinChrome: some View {
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
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
        .accessibilityIdentifier("twinChrome")
    }

    private var topBar: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("GEORGIA TECH")
                        .font(.caption2.weight(.bold).monospaced())
                        .tracking(1.6)
                        .foregroundStyle(GTTheme.gold)
                    Text("Buzz Route")
                        .font(.title2.weight(.bold))
                        .foregroundStyle(.white)
                }

                Spacer(minLength: 8)

                HStack(spacing: 14) {
                    Button {
                        model.showTwin3D.toggle()
                    } label: {
                        Image(systemName: model.showTwin3D ? "map.fill" : "cube.transparent.fill")
                            .font(.system(size: 22, weight: .semibold))
                            .foregroundStyle(GTTheme.gold)
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityLabel(model.showTwin3D ? "Show map" : "Show 3D twin")
                    .accessibilityIdentifier("toggleTwinMap")

                    Button {
                        model.showGrokBot = true
                    } label: {
                        Image(systemName: "waveform.circle.fill")
                            .font(.system(size: 28))
                            .foregroundStyle(GTTheme.gold)
                            .frame(width: 36, height: 36)
                    }
                    .accessibilityIdentifier("openGrokHeader")
                }
            }

            // Route chips + replay on separate wrapping rows — no overlap.
            HStack(spacing: 8) {
                Label(model.origin.shortName, systemImage: "location.fill")
                    .font(.caption.weight(.semibold))
                    .lineLimit(1)
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
                    .lineLimit(1)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(GTTheme.gold.opacity(0.18))
                    .foregroundStyle(GTTheme.gold)
                    .clipShape(Capsule())
                }
                .buttonStyle(.plain)
                .layoutPriority(1)
            }

            HStack(spacing: 10) {
                Text(model.replayMode ? "Replay buses on" : "Live buses")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.55))

                Spacer()

                Toggle(isOn: $model.replayMode) {
                    Text("Replay")
                }
                .toggleStyle(.switch)
                .labelsHidden()
                .tint(GTTheme.gold)
                .onChange(of: model.replayMode) { _, _ in
                    if model.destination != nil { model.plan() }
                }

                if let reachable = model.apiReachable {
                    Text(reachable ? "API" : "Offline")
                        .font(.caption2.weight(.bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .foregroundStyle(reachable ? GTTheme.good : GTTheme.warn)
                        .background((reachable ? GTTheme.good : GTTheme.warn).opacity(0.15))
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 10)
        .padding(.bottom, 12)
        .background(.ultraThinMaterial)
        .overlay(alignment: .bottom) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
    }

    private var bottomPanel: some View {
        VStack(spacing: 10) {
            if let message = model.errorMessage {
                Text(message)
                    .font(.caption)
                    .foregroundStyle(GTTheme.bad)
                    .multilineTextAlignment(.leading)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 16)
            }

            if let trip = model.trip {
                GeometryReader { geo in
                    PlanCardView(trip: trip) {
                        model.showGrokBot = true
                    }
                    .frame(maxHeight: min(420, geo.size.height), alignment: .top)
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                }
                .frame(height: 360)
                .padding(.horizontal, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            } else {
                emptyPlanPanel
                    .padding(.horizontal, 12)
            }
        }
        .padding(.top, 10)
        .padding(.bottom, 8)
        .background(.ultraThinMaterial)
        .overlay(alignment: .top) {
            Rectangle()
                .fill(Color.white.opacity(0.08))
                .frame(height: 1)
        }
        .animation(.spring(response: 0.35, dampingFraction: 0.86), value: model.trip?.id)
    }

    private var emptyPlanPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Next up")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.white.opacity(0.45))
                    Text(model.nextEvent.title)
                        .font(.headline)
                        .foregroundStyle(.white)
                        .fixedSize(horizontal: false, vertical: true)
                    Text(model.nextEvent.locationName)
                        .font(.caption)
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(2)
                }
                Spacer(minLength: 8)
                Text(shortTime(model.nextEvent.start))
                    .font(.title3.weight(.bold).monospaced())
                    .foregroundStyle(GTTheme.gold)
                    .layoutPriority(1)
            }

            VStack(spacing: 8) {
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
                                .multilineTextAlignment(.leading)
                            if !place.stingerRoutes.isEmpty {
                                Text(place.stingerRoutes.joined(separator: " · "))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
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
