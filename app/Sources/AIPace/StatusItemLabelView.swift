import SwiftUI

struct StatusItemLabelView: View {
    nonisolated static let defaultFallbackText = "AIPace"

    let claudeText: String?
    let codexText: String?
    let theme: AppTheme

    var body: some View {
        let visibleClaudeText = Self.visibleText(claudeText)
        let visibleCodexText = Self.visibleText(codexText)

        HStack(spacing: 6) {
            if let claudeText = visibleClaudeText {
                pill(text: claudeText, color: theme.claudeAccent)
            }
            if let codexText = visibleCodexText {
                pill(text: codexText, color: theme.codexAccent)
            }
            if let fallbackText = Self.resolvedFallbackText(
                claudeText: visibleClaudeText,
                codexText: visibleCodexText
            ) {
                pill(text: fallbackText, color: Color(red: 0.36, green: 0.38, blue: 0.42))
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 22)
        .allowsHitTesting(false)
    }

    nonisolated static func resolvedFallbackText(claudeText: String?, codexText: String?) -> String? {
        guard visibleText(claudeText) == nil, visibleText(codexText) == nil else {
            return nil
        }
        return defaultFallbackText
    }

    private nonisolated static func visibleText(_ text: String?) -> String? {
        guard let text else {
            return nil
        }
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    private func pill(text: String, color: Color) -> some View {
        Text(text)
            .font(.system(size: 11, weight: .semibold, design: .monospaced))
            .foregroundStyle(.white)
            .padding(.horizontal, 8)
            .padding(.vertical, 3)
            .background(
                Capsule(style: .continuous)
                    .fill(color)
            )
    }
}
