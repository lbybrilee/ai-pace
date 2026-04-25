import Foundation

enum StatusItemFormatter {
    static func compactValue(for window: UsageWindow) -> String {
        guard let used = window.usedPercentage else {
            return "--"
        }
        return String(Int(used.rounded()))
    }

    static func compactRemainingValue(for window: UsageWindow) -> String {
        guard let used = window.usedPercentage else {
            return "--"
        }
        let remaining = max(0, 100 - used)
        return String(Int(remaining.rounded()))
    }

    static func text(prefix: String, snapshot: ProviderSnapshot, mode: MenuBarDisplayMode) -> String {
        // Menu-bar labels now use glyph logos in place of text prefixes, so the
        // controller passes `""`. Clipboard copy still passes "Claude"/"Codex" and
        // needs a separator — handle both with one branch.
        let lead = prefix.isEmpty ? "" : "\(prefix) "
        switch mode {
        case .usage:
            return "\(lead)\(compactValue(for: snapshot.fiveHour))/\(compactValue(for: snapshot.weekly))"
        case .remaining:
            return "\(lead)\(compactRemainingValue(for: snapshot.fiveHour))/\(compactRemainingValue(for: snapshot.weekly))"
        case .insight:
            let insight = WeeklyPacing.formattedDelta(for: snapshot.weekly) ?? "--"
            return "\(lead)\(insight)"
        case .usageAndInsight:
            let usage = "\(compactValue(for: snapshot.fiveHour))/\(compactValue(for: snapshot.weekly))"
            let insight = WeeklyPacing.formattedDelta(for: snapshot.weekly) ?? "--"
            return "\(lead)\(usage) \(insight)"
        case .remainingAndInsight:
            let remaining = "\(compactRemainingValue(for: snapshot.fiveHour))/\(compactRemainingValue(for: snapshot.weekly))"
            let insight = WeeklyPacing.formattedDelta(for: snapshot.weekly) ?? "--"
            return "\(lead)\(remaining) \(insight)"
        }
    }
}
