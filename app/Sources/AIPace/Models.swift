import Foundation

enum ProviderKind: String {
    case claude = "Claude"
    case codex = "Codex"
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
    case rateLimited
    case error(String)

    var showsInPopover: Bool {
        switch self {
        case .loading, .available:
            return true
        case .missingAuth, .accessDenied, .sessionExpired, .notInstalled, .notLoggedIn, .rateLimited, .error:
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
