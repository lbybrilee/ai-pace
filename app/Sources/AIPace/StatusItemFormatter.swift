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
        let windows = snapshot.fiveHour.usedPercentage == nil && snapshot.weekly.usedPercentage != nil
            ? [snapshot.weekly]
            : [snapshot.fiveHour, snapshot.weekly]

        switch mode {
        case .usage:
            return "\(prefix) \(windows.map(compactValue).joined(separator: "/"))"
        case .remaining:
            return "\(prefix) \(windows.map(compactRemainingValue).joined(separator: "/"))"
        case .insight:
            let insight = WeeklyPacing.formattedDelta(for: snapshot.weekly) ?? "--"
            return "\(prefix) \(insight)"
        case .usageAndInsight:
            let usage = windows.map(compactValue).joined(separator: "/")
            let insight = WeeklyPacing.formattedDelta(for: snapshot.weekly) ?? "--"
            return "\(prefix) \(usage) \(insight)"
        case .remainingAndInsight:
            let remaining = windows.map(compactRemainingValue).joined(separator: "/")
            let insight = WeeklyPacing.formattedDelta(for: snapshot.weekly) ?? "--"
            return "\(prefix) \(remaining) \(insight)"
        }
    }
}
