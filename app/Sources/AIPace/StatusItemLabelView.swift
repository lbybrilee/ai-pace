import SwiftUI

struct StatusItemLabelView: View {
    let pills: [StatusItemPill]

    var body: some View {
        HStack(spacing: 6) {
            ForEach(Array(pills.enumerated()), id: \.offset) { entry in
                pill(text: entry.element.text, color: entry.element.color)
            }
        }
        .padding(.horizontal, 4)
        .frame(height: 22)
        .allowsHitTesting(false)
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

struct StatusItemPill {
    let text: String
    let color: Color
}
