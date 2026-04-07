import Foundation

enum StatusItemFormatter {
    static func compactValue(for window: UsageWindow, perspective: UsagePerspective) -> String {
        guard let used = window.usedPercentage else {
            return "--"
        }
        let value = perspective == .used ? used : max(0, 100 - used)
        return String(Int(value.rounded()))
    }

    static func text(prefix: String, snapshot: ProviderSnapshot, mode: MenuBarDisplayMode, perspective: UsagePerspective) -> String {
        switch mode {
        case .usage:
            return "\(prefix) \(compactValue(for: snapshot.fiveHour, perspective: perspective))/\(compactValue(for: snapshot.weekly, perspective: perspective))"
        case .insight:
            let insight = WeeklyPacing.formattedDelta(for: snapshot.weekly) ?? "--"
            return "\(prefix) \(insight)"
        case .usageAndInsight:
            let usage = "\(compactValue(for: snapshot.fiveHour, perspective: perspective))/\(compactValue(for: snapshot.weekly, perspective: perspective))"
            let insight = WeeklyPacing.formattedDelta(for: snapshot.weekly) ?? "--"
            return "\(prefix) \(usage) \(insight)"
        }
    }

    static func text(
        prefix: String,
        snapshot: CopilotSnapshot,
        mode: CopilotDisplayMode,
        perspective: UsagePerspective,
        monthlyAllowance: Int
    ) -> String {
        if snapshot.primary.kind == .premiumRequests {
            let percentage = compactValue(for: snapshot.primary, perspective: perspective, monthlyAllowance: monthlyAllowance)
            let usage = snapshot.secondary.map {
                compactValue(for: $0, perspective: perspective, monthlyAllowance: monthlyAllowance)
            }

            switch mode {
            case .usage:
                return "\(prefix) \(usage ?? percentage)"
            case .percentage:
                return "\(prefix) \(percentage)"
            case .both:
                if let usage {
                    return "\(prefix) \(usage) \(percentage)"
                }
                return "\(prefix) \(percentage)"
            }
        }

        let primary = compactValue(for: snapshot.primary, perspective: perspective, monthlyAllowance: monthlyAllowance)
        if let secondary = snapshot.secondary {
            return "\(prefix) \(compactValue(for: secondary, perspective: perspective, monthlyAllowance: monthlyAllowance))/\(primary)"
        }
        return "\(prefix) \(primary)"
    }

    private static func compactValue(
        for window: CopilotUsageWindow,
        perspective: UsagePerspective,
        monthlyAllowance: Int
    ) -> String {
        window.displayedValueText(perspective: perspective, monthlyAllowance: monthlyAllowance) ?? "--"
    }
}
