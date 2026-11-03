import SwiftUI

struct ConfidenceBandView: View {
    let band: ConfidenceBand
    let total: DurationQuantiles

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Confidence", systemImage: "chart.bar.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(GTTheme.techGold)
                Spacer()
                Text(percent(band.pOnTime) + " on time")
                    .font(.caption.weight(.bold))
                    .foregroundStyle(band.pOnTime >= 0.75 ? GTTheme.good : GTTheme.warn)
            }

            GeometryReader { geo in
                let width = geo.size.width
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.white.opacity(0.08))
                        .frame(height: 10)

                    Capsule()
                        .fill(GTTheme.gold.opacity(0.35))
                        .frame(width: max(18, width * bandWidthFactor), height: 10)
                        .offset(x: width * 0.12)

                    Circle()
                        .fill(GTTheme.gold)
                        .frame(width: 14, height: 14)
                        .offset(x: width * 0.45)
                }
            }
            .frame(height: 14)

            HStack {
                Text("p10 \(time(band.arrivalP10))")
                Spacer()
                Text("p50 \(time(band.arrivalP50))")
                    .fontWeight(.semibold)
                    .foregroundStyle(.white)
                Spacer()
                Text("p90 \(time(band.arrivalP90))")
            }
            .font(.caption2.monospaced())
            .foregroundStyle(.white.opacity(0.7))

            if let note = band.wideningNote {
                Text(note)
                    .font(.caption2)
                    .foregroundStyle(.white.opacity(0.55))
            }
        }
        .padding(12)
        .background(Color.white.opacity(0.04))
        .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
    }

    private var bandWidthFactor: CGFloat {
        let spread = max(1, total.spreadMinutes)
        return CGFloat(min(0.7, 0.25 + spread / 40))
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
