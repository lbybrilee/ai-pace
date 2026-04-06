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
    case error(String)

    var showsInPopover: Bool {
        switch self {
        case .loading, .available, .error:
            return true
        case .missingAuth, .accessDenied, .sessionExpired, .notInstalled, .notLoggedIn:
            return false
        }
    }
}

struct AgentStatus: Equatable {
    let provider: ProviderKind
    let availability: AgentAvailability
    let message: String?
}

enum AutoRefreshInterval: Int, CaseIterable, Identifiable {
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
