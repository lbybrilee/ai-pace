import Foundation

enum ProviderKind: String, CaseIterable, Identifiable {
    case claude = "Claude"
    case codex = "Codex"
    case copilot = "Copilot"

    var id: String { rawValue }
}

enum UsageWindowKind: String {
    case fiveHour = "5h"
    case weekly = "Week"
}

enum AgentAvailability: Equatable {
    case loading
    case available
    case missingAuth
    case accessDenied
    case sessionExpired
    case notInstalled
    case notLoggedIn
    case error(String)

    var showsInPopover: Bool {
        switch self {
        case .loading, .available:
            return true
        case .missingAuth, .accessDenied, .sessionExpired, .notInstalled, .notLoggedIn, .error:
            return false
        }
    }
}

struct AgentStatus: Equatable {
    let provider: ProviderKind
    let availability: AgentAvailability
    let message: String?
}

enum MenuBarDisplayMode: String, CaseIterable, Identifiable {
    case usage
    case insight
    case usageAndInsight

    var id: String { rawValue }
}

enum UsagePerspective: String, CaseIterable, Identifiable {
    case used
    case remaining

    var id: String { rawValue }

    static let defaultValue: UsagePerspective = .used
}

enum CopilotDisplayMode: String, CaseIterable, Identifiable {
    case usage
    case percentage
    case both

    var id: String { rawValue }

    static let defaultValue: CopilotDisplayMode = .usage
}

enum AutoRefreshInterval: Int, CaseIterable, Identifiable {
    case manual = 0
    case oneMinute = 60
    case twoMinutes = 120
    case fiveMinutes = 300
    case tenMinutes = 600
    case fifteenMinutes = 900
    case thirtyMinutes = 1800

    var id: Int { rawValue }

    var duration: TimeInterval { TimeInterval(rawValue) }

    var label: String {
        switch self {
        case .manual:
            return "Manual"
        case .oneMinute:
            return "1 minute"
        case .twoMinutes:
            return "2 minutes"
        case .fiveMinutes:
            return "5 minutes"
        case .tenMinutes:
            return "10 minutes"
        case .fifteenMinutes:
            return "15 minutes"
        case .thirtyMinutes:
            return "30 minutes"
        }
    }

    static let defaultValue: AutoRefreshInterval = .fiveMinutes
}

enum NotificationSoundOption: String, CaseIterable, Identifiable {
    case systemDefault
    case glass
    case hero
    case purr
    case frog
    case bottle
    case submarine
    case silent

    var id: String { rawValue }

    var soundName: String? {
        switch self {
        case .systemDefault, .silent:
            return nil
        case .glass:
            return "Glass"
        case .hero:
            return "Hero"
        case .purr:
            return "Purr"
        case .frog:
            return "Frog"
        case .bottle:
            return "Bottle"
        case .submarine:
            return "Submarine"
        }
    }
}

enum LaunchAtStartupState: Equatable {
    case enabled
    case disabled
    case requiresApproval
    case unsupported
}

struct UsageWindowKey: Hashable, Sendable {
    let provider: ProviderKind
    let kind: UsageWindowKind

    var storageKey: String {
        "\(provider.rawValue.lowercased())-\(kind.rawValue.lowercased())"
    }
}

struct UsageWindow: Identifiable {
    let kind: UsageWindowKind
    var usedPercentage: Double?
    var resetsAt: Date?
    var message: String?

    var id: String { kind.rawValue }

    static func placeholder(_ kind: UsageWindowKind, message: String = "Loading…") -> UsageWindow {
        UsageWindow(kind: kind, usedPercentage: nil, resetsAt: nil, message: message)
    }
}

struct ProviderSnapshot {
    let provider: ProviderKind
    var fiveHour: UsageWindow
    var weekly: UsageWindow
    var detail: String?

    static func loading(_ provider: ProviderKind) -> ProviderSnapshot {
        ProviderSnapshot(
            provider: provider,
            fiveHour: .placeholder(.fiveHour),
            weekly: .placeholder(.weekly),
            detail: nil
        )
    }
}

enum CopilotUsageWindowKind: String {
    case premiumRequests = "Premium requests"
    case today = "Today"
    case month = "Month"
}

struct CopilotUsageWindow: Identifiable {
    let kind: CopilotUsageWindowKind
    var valueText: String?
    var progressPercent: Double?
    var resetsAt: Date?
    var message: String?

    var id: String { kind.rawValue }

    static func placeholder(_ kind: CopilotUsageWindowKind, message: String = "Loading…") -> CopilotUsageWindow {
        CopilotUsageWindow(kind: kind, valueText: nil, progressPercent: nil, resetsAt: nil, message: message)
    }

    func displayedValueText(perspective: UsagePerspective, monthlyAllowance: Int) -> String? {
        if let progressPercent {
            switch kind {
            case .premiumRequests:
                let value = perspective == .used ? progressPercent : max(0, 100 - progressPercent)
                return String(format: "%.1f%%", value)
            case .month:
                let used = Int((Double(monthlyAllowance) * min(max(progressPercent, 0), 100) / 100).rounded())
                let value = perspective == .used ? used : max(0, monthlyAllowance - used)
                return "~\(value)/\(monthlyAllowance)"
            case .today:
                break
            }
        }

        guard let valueText else {
            return nil
        }

        switch kind {
        case .premiumRequests, .month:
            guard let numericValue = Self.usageCount(in: valueText) else {
                return valueText
            }
            let value = perspective == .used ? numericValue : max(0, monthlyAllowance - numericValue)
            return String(value)
        case .today:
            return valueText
        }
    }

    private static func usageCount(in text: String) -> Int? {
        if let fractionStart = text.firstIndex(of: "/") {
            let prefix = text[..<fractionStart]
            let digits = prefix.filter(\.isNumber)
            if !digits.isEmpty {
                return Int(String(digits))
            }
        }

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        let digits = trimmed.prefix { $0.isNumber }
        guard !digits.isEmpty else {
            return nil
        }
        return Int(digits)
    }
}

struct CopilotSnapshot {
    var primary: CopilotUsageWindow
    var secondary: CopilotUsageWindow?
    var detail: String?
    var footer: String?

    static func loading() -> CopilotSnapshot {
        CopilotSnapshot(
            primary: .placeholder(.premiumRequests),
            secondary: nil,
            detail: nil,
            footer: nil
        )
    }
}

enum WeeklyPacing {
    static func delta(for window: UsageWindow, now: Date = .now) -> Double? {
        guard window.kind == .weekly,
              let used = window.usedPercentage,
              let resetsAt = window.resetsAt else {
            return nil
        }

        let totalWeeklyWindow: TimeInterval = 7 * 24 * 60 * 60
        let timeRemaining = min(max(resetsAt.timeIntervalSince(now) / totalWeeklyWindow * 100, 0), 100)
        let usageRemaining = min(max(100 - used, 0), 100)
        return usageRemaining - timeRemaining
    }

    static func formattedDelta(for window: UsageWindow, now: Date = .now) -> String? {
        guard let delta = delta(for: window, now: now) else {
            return nil
        }

        let roundedDelta = delta.rounded()
        if abs(roundedDelta) < 0.5 {
            return "0%"
        }
        return String(format: "%+.0f%%", roundedDelta)
    }
}
