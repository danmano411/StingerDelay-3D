import SwiftUI

enum GTTheme {
    static let navy = Color(red: 0.0, green: 0.188, blue: 0.341)       // #003057
    static let gold = Color(red: 0.918, green: 0.667, blue: 0.0)        // #EAAA00
    static let techGold = Color(red: 0.702, green: 0.639, blue: 0.412)  // #B3A369
    static let ink = Color(red: 0.07, green: 0.09, blue: 0.12)
    static let panel = Color(red: 0.06, green: 0.09, blue: 0.14).opacity(0.92)
    static let mist = Color(red: 0.90, green: 0.92, blue: 0.94)
    static let good = Color(red: 0.30, green: 0.76, blue: 0.54)
    static let warn = Color(red: 0.95, green: 0.55, blue: 0.20)
    static let bad = Color(red: 1.0, green: 0.37, blue: 0.34)

    static var backgroundGradient: LinearGradient {
        LinearGradient(
            colors: [
                Color(red: 0.02, green: 0.05, blue: 0.10),
                Color(red: 0.05, green: 0.12, blue: 0.22),
                Color(red: 0.03, green: 0.08, blue: 0.14)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

struct BuzzPrimaryButton: View {
    let title: String
    var systemImage: String? = nil
    var filled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 8) {
                if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title)
                    .fontWeight(.semibold)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 13)
            .foregroundStyle(filled ? GTTheme.ink : GTTheme.gold)
            .background(filled ? GTTheme.gold : Color.white.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(GTTheme.gold.opacity(filled ? 0 : 0.55), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
