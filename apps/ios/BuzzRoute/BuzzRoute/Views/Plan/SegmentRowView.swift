import SwiftUI

struct SegmentRowView: View {
    let segment: RouteSegment
    let isLast: Bool

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(spacing: 0) {
                Image(systemName: segment.kind.systemImage)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(GTTheme.ink)
                    .frame(width: 28, height: 28)
                    .background(iconBackground)
                    .clipShape(Circle())

                if !isLast {
                    Rectangle()
                        .fill(Color.white.opacity(0.15))
                        .frame(width: 2)
                        .frame(maxHeight: .infinity)
                }
            }

            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(segment.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.white)
                    Spacer()
                    Text(segment.duration.formattedTypical())
                        .font(.caption.weight(.bold).monospaced())
                        .foregroundStyle(GTTheme.gold)
                }

                Text(segment.detail)
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.55))

                Text(segment.kind.label.uppercased() + " · " + segment.duration.formattedBand())
                    .font(.caption2.weight(.semibold))
                    .tracking(0.4)
                    .foregroundStyle(.white.opacity(0.4))
            }
            .padding(.bottom, isLast ? 0 : 14)
        }
    }

    private var iconBackground: Color {
        switch segment.kind {
        case .walk, .transferWalk: return GTTheme.techGold
        case .wait: return Color.white.opacity(0.85)
        case .ride:
            if let line = segment.line {
                return Color(hex: line.tintHex)
            }
            return GTTheme.gold
        }
    }
}
