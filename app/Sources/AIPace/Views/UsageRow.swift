import SwiftUI

struct UsageRow: View {
    let window: UsageWindow
    let provider: ProviderKind
    @Bindable var store: UsageStore
    let accent: Color
    let lang: AppLanguage
    @AppStorage("popoverDisplayMode") private var popoverDisplayModeID = PopoverDisplayMode.usage.rawValue

    private var key: UsageWindowKey { UsageWindowKey(provider: provider, kind: window.kind) }
    private var notifyEnabled: Bool { store.refreshNotificationsEnabled(for: key) }
    private var notificationsDisabledInSystem: Bool { store.notificationsDisabledInSystem }
    private var loc: Loc { Loc(lang: lang) }
    private var popoverMode: PopoverDisplayMode { PopoverDisplayMode(rawValue: popoverDisplayModeID) ?? .usage }
    private let barLeadingInset: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(spacing: 6) {
                Button {
                    guard !notificationsDisabledInSystem else {
                        return
                    }
                    Task { await store.setRefreshNotificationsEnabled(!notifyEnabled, for: key) }
                } label: {
                    Image(systemName: notificationsDisabledInSystem ? "bell.slash" : (notifyEnabled ? "bell.fill" : "bell"))
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(notificationsDisabledInSystem ? .tertiary : (notifyEnabled ? .primary : .tertiary))
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 16, height: 16)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .disabled(notificationsDisabledInSystem)
                .pointerOnHover()
                .padding(.leading, 4)

                Text(loc.windowLabel(window.kind))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Group {
                    if let used = window.usedPercentage {
                        Text(percentageText(for: used))
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                            .foregroundStyle(UsageBarPalette.textColor(for: used, baseline: .primary))
                    } else {
                        Text(loc.displayMessage(window.message))
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(minWidth: popoverMode == .remaining ? 72 : 36, alignment: .trailing)

                Group {
                    if let resetsAt = window.resetsAt {
                        Text(formatReset(resetsAt))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 86, alignment: .trailing)
            }

            UsageBar(percentage: window.usedPercentage, accent: accent, mode: popoverMode)
                .padding(.leading, barLeadingInset)

            let samples = store.history.samples(for: key)
            if SparklineView.hasRenderableData(samples) {
                SparklineView(samples: samples, accent: accent)
                    .padding(.leading, barLeadingInset)
                    .padding(.top, 2)
            }
        }
    }

    private func percentageText(for used: Double) -> String {
        let clamped = min(max(used, 0), 100)
        switch popoverMode {
        case .usage:
            return "\(Int(clamped.rounded()))%"
        case .remaining:
            let remaining = 100 - clamped
            return "\(Int(remaining.rounded()))% \(loc.remainingSuffix)"
        }
    }

    private func formatReset(_ date: Date) -> String {
        let secs = max(0, Int(date.timeIntervalSinceNow.rounded(.down)))
        if secs < 60 { return "<1m" }
        let tot = secs / 60
        let d = tot / 1440
        let h = (tot % 1440) / 60
        let m = tot % 60
        var p: [String] = []
        if d > 0 { p.append("\(d)d") }
        if h > 0 || d > 0 { p.append("\(h)h") }
        p.append(String(format: "%02dm", m))
        return p.joined(separator: " ")
    }
}

struct UsageBar: View {
    let percentage: Double?
    let accent: Color
    let mode: PopoverDisplayMode
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.12))
                if let pct = percentage {
                    let clamped = min(max(pct, 0), 100)
                    let displayPct = mode == .remaining ? (100 - clamped) : clamped
                    Capsule()
                        .fill(UsageBarPalette.fillColor(for: clamped, accent: accent, colorScheme: colorScheme))
                        .frame(width: displayPct <= 0 ? 0 : max(2, geo.size.width * displayPct / 100))
                }
            }
        }
        .frame(height: 6)
    }
}

enum UsageBarPalette {
    static func fillColor(for percentage: Double, accent: Color, colorScheme: ColorScheme) -> Color {
        let pct = min(max(percentage, 0), 100)
        let base: Color
        switch pct {
        case ..<60:
            base = accent
        case 60..<85:
            base = Color(.sRGB, red: 0.95, green: 0.58, blue: 0.10, opacity: 1)
        default:
            base = Color(.sRGB, red: 0.92, green: 0.27, blue: 0.22, opacity: 1)
        }
        let opacity = colorScheme == .dark ? (pct > 80 ? 1.0 : pct > 60 ? 0.9 : 0.8) : 1.0
        return base.opacity(opacity)
    }

    static func textColor(for percentage: Double, baseline: HierarchicalShapeStyle) -> AnyShapeStyle {
        switch percentage {
        case ..<85:
            return AnyShapeStyle(baseline)
        case 85..<95:
            return AnyShapeStyle(Color(.sRGB, red: 0.95, green: 0.58, blue: 0.10, opacity: 1))
        default:
            return AnyShapeStyle(Color(.sRGB, red: 0.92, green: 0.27, blue: 0.22, opacity: 1))
        }
    }
}
