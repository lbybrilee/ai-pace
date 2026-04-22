import SwiftUI

struct StatusItemLabelView: View {
    let claudeText: String?
    let codexText: String?
    let theme: AppTheme

    var body: some View {
        HStack(spacing: 6) {
            if let claudeText {
                pill(text: claudeText, color: theme.claudeAccent)
            }
            if let codexText {
                pill(text: codexText, color: theme.codexAccent)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 22)
        .allowsHitTesting(false)
    }

    private func pill(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold))
            .monospacedDigit()
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(color)
            )
    }
}
