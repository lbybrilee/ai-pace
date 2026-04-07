import Foundation

enum StatusItemFormatter {
    static func compactValue(for window: UsageWindow) -> String {
        guard let used = window.usedPercentage else {
            return "--"
        }
        return String(Int(used.rounded()))
    }

    static func text(prefix: String, snapshot: ProviderSnapshot, mode: MenuBarDisplayMode) -> String {
        switch mode {
        case .usage:
            return "\(prefix) \(compactValue(for: snapshot.fiveHour))/\(compactValue(for: snapshot.weekly))"
        case .insight:
            let insight = WeeklyPacing.formattedDelta(for: snapshot.weekly) ?? "--"
            return "\(prefix) \(insight)"
        case .usageAndInsight:
            let usage = "\(compactValue(for: snapshot.fiveHour))/\(compactValue(for: snapshot.weekly))"
            let insight = WeeklyPacing.formattedDelta(for: snapshot.weekly) ?? "--"
            return "\(prefix) \(usage) \(insight)"
        }
    }
}
