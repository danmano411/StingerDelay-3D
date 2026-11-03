import SwiftUI

struct PlanCardView: View {
    let trip: TripTrace
    var onAskGrok: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            header

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    chip(trip.verificationToken, icon: "checkmark.seal.fill")
                    if trip.apiTrace != nil {
                        chip("API", icon: "server.rack")
                    }
                    if trip.replayMode {
                        chip("REPLAY", icon: "arrow.triangle.2.circlepath")
                    }
                    if let social = trip.apiTrace?.social_factor {
                        chip(social.label, icon: "bubble.left")
                    }
                    chip(trip.totalDuration.formattedBand(), icon: "clock")
                }
            }

            ConfidenceBandView(band: trip.confidence, total: trip.totalDuration)

            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(trip.segments.enumerated()), id: \.element.id) { index, segment in
                        SegmentRowView(segment: segment, isLast: index == trip.segments.count - 1)
                    }
                }
            }
            .frame(maxHeight: 180)

            BuzzPrimaryButton(title: "Ask Grok Bot", systemImage: "waveform", action: onAskGrok)
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
        .shadow(color: .black.opacity(0.35), radius: 18, y: 8)
    }

    private var header: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("PRT PLAN")
                    .font(.caption2.weight(.bold))
                    .tracking(1.4)
                    .foregroundStyle(GTTheme.gold)
                Text("\(trip.origin.shortName) → \(trip.destination.shortName)")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer(minLength: 8)
            VStack(alignment: .trailing, spacing: 2) {
                Text(trip.totalDuration.formattedTypical())
                    .font(.title2.weight(.bold).monospaced())
                    .foregroundStyle(GTTheme.gold)
                Text("typical")
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.45))
            }
            .layoutPriority(1)
        }
    }

    private func chip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(.white.opacity(0.85))
            .background(Color.white.opacity(0.07))
            .clipShape(Capsule())
    }
}
