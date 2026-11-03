import SwiftUI

struct PlanCardView: View {
    let trip: TripTrace
    var onAskGrok: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("PRT PLAN")
                        .font(.caption2.weight(.bold))
                        .tracking(1.4)
                        .foregroundStyle(GTTheme.gold)
                    Text("\(trip.origin.shortName) → \(trip.destination.shortName)")
                        .font(.title3.weight(.bold))
                        .foregroundStyle(.white)
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 2) {
                    Text(trip.totalDuration.formattedTypical())
                        .font(.title2.weight(.bold).monospaced())
                        .foregroundStyle(GTTheme.gold)
                    Text("typical")
                        .font(.caption2)
                        .foregroundStyle(.white.opacity(0.45))
                }
            }

            HStack(spacing: 8) {
                chip(trip.verificationToken, icon: "checkmark.seal.fill")
                if trip.replayMode {
                    chip("REPLAY", icon: "arrow.triangle.2.circlepath")
                }
                chip(trip.totalDuration.formattedBand(), icon: "clock")
            }

            ConfidenceBandView(band: trip.confidence, total: trip.totalDuration)

            VStack(alignment: .leading, spacing: 0) {
                ForEach(Array(trip.segments.enumerated()), id: \.element.id) { index, segment in
                    SegmentRowView(segment: segment, isLast: index == trip.segments.count - 1)
                }
            }

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

    private func chip(_ text: String, icon: String) -> some View {
        Label(text, systemImage: icon)
            .font(.caption2.weight(.semibold))
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .foregroundStyle(.white.opacity(0.85))
            .background(Color.white.opacity(0.07))
            .clipShape(Capsule())
    }
}
