import SwiftUI

struct ProviderCard: View {
    let snapshot: ProviderSnapshot
    @Bindable var store: UsageStore
    let accent: Color
    let lang: AppLanguage

    /// Lifts near-black accents (e.g. the Original theme's `#0F0F0F` Codex mark)
    /// to a graphite tone so the dot / bar / sparkline stay visible against the
    /// dark material card. Bright accents pass through unchanged.
    private var displayAccent: Color { accent.liftedForDarkBackground }

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            let insight = WeeklyPacingInsight(window: snapshot.weekly, lang: lang)
            let liveActive = liveActivity(for: snapshot.provider).isActive

            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle()
                    .fill(displayAccent)
                    .frame(width: 7, height: 7)
                    .offset(y: -0.5)
                Text(snapshot.provider.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                if liveActive {
                    LiveBadge(accent: displayAccent)
                }
                if let insight {
                    FlashingDot(color: insight.color, shouldPulse: insight.shouldPulse)
                        .offset(y: -0.5)
                    Text(insight.message)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(insight.color)
                        .lineLimit(1)
                }
                Spacer()
                if let detail = snapshot.detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 6) {
                UsageRow(window: snapshot.fiveHour, provider: snapshot.provider, store: store, accent: displayAccent, lang: lang)

                let advice = store.pacingAdvice(for: snapshot, kind: .fiveHour)
                PacingAdviceView(advice: advice, accent: displayAccent)
                    .padding(.leading, 30)
            }

            UsageRow(window: snapshot.weekly, provider: snapshot.provider, store: store, accent: displayAccent, lang: lang)

            if snapshot.provider == .claude && !store.topClaudeProjects.isEmpty {
                TopProjectsView(projects: store.topClaudeProjects, accent: displayAccent)
                    .padding(.leading, 30)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(CardBackground())
    }

    private func liveActivity(for provider: ProviderKind) -> LiveActivitySnapshot {
        switch provider {
        case .claude: return store.liveActivityMonitor.claude
        case .codex: return store.liveActivityMonitor.codex
        }
    }
}

/// Small "LIVE" badge with a pulsing dot. Shown next to the provider name
/// when session-log activity has been observed in the last few seconds.
private struct LiveBadge: View {
    let accent: Color

    var body: some View {
        HStack(spacing: 4) {
            FlashingDot(color: accent, shouldPulse: true)
                .offset(y: -0.5)
            Text("LIVE")
                .font(.system(size: 9, weight: .bold, design: .monospaced))
                .foregroundStyle(accent)
                .tracking(0.6)
        }
        .padding(.horizontal, 5)
        .padding(.vertical, 1)
        .background(
            Capsule().fill(accent.opacity(0.12))
        )
        .overlay(
            Capsule().strokeBorder(accent.opacity(0.35), lineWidth: 0.5)
        )
    }
}

struct WeeklyPacingInsight {
    let message: String
    let color: Color
    let delta: Double

    init?(window: UsageWindow, lang: AppLanguage, now: Date = .now) {
        guard let delta = WeeklyPacing.delta(for: window, now: now) else {
            return nil
        }
        self.delta = delta
        message = Loc(lang: lang).insightMessage(delta: delta)

        switch delta {
        case ..<(-5): color = .orange
        case -5...5: color = .green
        default: color = .blue
        }
    }

    var shouldPulse: Bool { abs(delta) > 10 }
}
