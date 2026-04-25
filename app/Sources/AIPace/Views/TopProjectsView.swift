import SwiftUI

/// Collapsible "Top projects (5h)" panel inside the Claude provider card.
/// Shows attribution sourced from Claude Code session logs.
struct TopProjectsView: View {
    let projects: [ProjectAttribution]
    let accent: Color
    @State private var isExpanded = false

    var body: some View {
        if projects.isEmpty {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    withAnimation(.easeInOut(duration: 0.18)) {
                        isExpanded.toggle()
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "folder")
                            .font(.system(size: 10, weight: .semibold))
                            .foregroundStyle(.secondary)
                        Text("Top projects (5h)")
                            .font(.system(size: 11, weight: .medium))
                            .foregroundStyle(.secondary)
                        Text("· \(projects.count)")
                            .font(.system(size: 11, design: .monospaced))
                            .foregroundStyle(.tertiary)
                        Spacer()
                        Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundStyle(.tertiary)
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerOnHover()

                if isExpanded {
                    VStack(alignment: .leading, spacing: 4) {
                        let maxTokens = projects.map(\.totalTokens).max() ?? 1
                        ForEach(projects) { project in
                            ProjectAttributionRow(
                                project: project,
                                maxTokens: maxTokens,
                                accent: accent
                            )
                        }
                    }
                    .padding(.top, 2)
                }
            }
        }
    }
}

private struct ProjectAttributionRow: View {
    let project: ProjectAttribution
    let maxTokens: Int
    let accent: Color

    var body: some View {
        HStack(spacing: 8) {
            VStack(alignment: .leading, spacing: 1) {
                Text(project.displayName)
                    .font(.system(size: 11, weight: .medium))
                    .lineLimit(1)
                    .truncationMode(.middle)
                Text("\(project.messageCount) msgs · \(formatTokens(project.totalTokens)) tok")
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
            Spacer(minLength: 8)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.primary.opacity(0.08))
                    Capsule()
                        .fill(accent.opacity(0.7))
                        .frame(width: geo.size.width * fraction)
                }
            }
            .frame(width: 80, height: 4)
        }
    }

    private var fraction: CGFloat {
        guard maxTokens > 0 else { return 0 }
        return CGFloat(project.totalTokens) / CGFloat(maxTokens)
    }

    private func formatTokens(_ value: Int) -> String {
        if value >= 1_000_000 {
            return String(format: "%.1fM", Double(value) / 1_000_000)
        }
        if value >= 1_000 {
            return String(format: "%.1fk", Double(value) / 1_000)
        }
        return "\(value)"
    }
}
