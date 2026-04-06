import Foundation
import SwiftUI

@MainActor
final class UsageStore: ObservableObject {
    @Published var claude = ProviderSnapshot.loading(.claude)
    @Published var codex = ProviderSnapshot.loading(.codex)
    @Published var lastUpdated: Date?
    @Published var isRefreshing = false
    @Published private(set) var refreshNotificationKeys: Set<String>
    @Published var autoRefreshInterval: AutoRefreshInterval

    private let claudeProbe = ClaudeProbe()
    private let codexProbe = CodexProbe()
    private let notificationManager = NotificationManager()
    private var refreshTask: Task<Void, Never>?
    private let refreshNotificationDefaultsKey = "refreshNotificationKeys"
    private let autoRefreshIntervalDefaultsKey = "autoRefreshInterval"

    init() {
        refreshNotificationKeys = Set(UserDefaults.standard.stringArray(forKey: refreshNotificationDefaultsKey) ?? [])
        let storedInterval = UserDefaults.standard.integer(forKey: autoRefreshIntervalDefaultsKey)
        autoRefreshInterval = AutoRefreshInterval(rawValue: storedInterval) ?? .defaultValue
        startRefreshLoop()
    }

    deinit {
        refreshTask?.cancel()
    }

    var menuBarTitle: String {
        "Cl \(compactValue(for: claude.fiveHour))/\(compactValue(for: claude.weekly))  Cx \(compactValue(for: codex.fiveHour))/\(compactValue(for: codex.weekly))"
    }

    var visibleSnapshots: [ProviderSnapshot] {
        [claude, codex].filter { agentStatus(for: $0.provider).availability.showsInPopover }
    }

    var hasVisibleSnapshots: Bool {
        !visibleSnapshots.isEmpty
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let previousClaude = claude
        let previousCodex = codex

        async let claudeSnapshot = claudeProbe.fetch()
        async let codexSnapshot = codexProbe.fetch()

        let newClaude = await claudeSnapshot
        let newCodex = await codexSnapshot

        claude = newClaude
        codex = newCodex
        lastUpdated = Date()

        notifyIfWindowRefreshed(previous: previousClaude, current: newClaude)
        notifyIfWindowRefreshed(previous: previousCodex, current: newCodex)
    }

    func setAutoRefreshInterval(_ interval: AutoRefreshInterval) {
        guard autoRefreshInterval != interval else {
            return
        }
        autoRefreshInterval = interval
        UserDefaults.standard.set(interval.rawValue, forKey: autoRefreshIntervalDefaultsKey)
        startRefreshLoop()
    }

    private func compactValue(for window: UsageWindow) -> String {
        guard let used = window.usedPercentage else {
            return "--"
        }
        return String(Int(used.rounded()))
    }

    func refreshNotificationsEnabled(for key: UsageWindowKey) -> Bool {
        refreshNotificationKeys.contains(key.storageKey)
    }

    func agentStatus(for provider: ProviderKind) -> AgentStatus {
        let snapshot = snapshot(for: provider)
        if snapshot.fiveHour.usedPercentage != nil || snapshot.weekly.usedPercentage != nil {
            return AgentStatus(provider: provider, availability: .available, message: nil)
        }

        let message = snapshot.fiveHour.message ?? snapshot.weekly.message
        guard let message else {
            return AgentStatus(provider: provider, availability: .loading, message: nil)
        }

        if message == "Loading…" {
            return AgentStatus(provider: provider, availability: .loading, message: nil)
        }

        switch provider {
        case .claude:
            return classifyClaudeStatus(message: message)
        case .codex:
            return classifyCodexStatus(message: message)
        }
    }

    func setRefreshNotificationsEnabled(_ enabled: Bool, for key: UsageWindowKey) async {
        if enabled {
            let granted = await notificationManager.requestAuthorizationIfNeeded()
            guard granted else {
                return
            }
            refreshNotificationKeys.insert(key.storageKey)
        } else {
            refreshNotificationKeys.remove(key.storageKey)
        }
        persistRefreshNotificationKeys()
    }

    private func persistRefreshNotificationKeys() {
        UserDefaults.standard.set(Array(refreshNotificationKeys).sorted(), forKey: refreshNotificationDefaultsKey)
    }

    private func notifyIfWindowRefreshed(previous: ProviderSnapshot, current: ProviderSnapshot) {
        notifyIfWindowRefreshed(
            key: UsageWindowKey(provider: current.provider, kind: .fiveHour),
            previous: previous.fiveHour,
            current: current.fiveHour
        )
        notifyIfWindowRefreshed(
            key: UsageWindowKey(provider: current.provider, kind: .weekly),
            previous: previous.weekly,
            current: current.weekly
        )
    }

    private func notifyIfWindowRefreshed(key: UsageWindowKey, previous: UsageWindow, current: UsageWindow) {
        guard refreshNotificationsEnabled(for: key) else {
            return
        }
        guard let previousReset = previous.resetsAt, let currentReset = current.resetsAt else {
            return
        }
        guard currentReset.timeIntervalSince(previousReset) > 60 else {
            return
        }

        Task {
            await notificationManager.sendRefreshNotification(for: key)
        }
    }

    private func snapshot(for provider: ProviderKind) -> ProviderSnapshot {
        switch provider {
        case .claude:
            return claude
        case .codex:
            return codex
        }
    }

    private func classifyClaudeStatus(message: String) -> AgentStatus {
        let normalized = message.lowercased()

        if normalized.contains("credentials not found")
            || normalized.contains("credentials could not be read") {
            return AgentStatus(provider: .claude, availability: .missingAuth, message: message)
        }
        if normalized.contains("keychain access denied") {
            return AgentStatus(provider: .claude, availability: .accessDenied, message: message)
        }
        if normalized.contains("session expired")
            || normalized.contains("authentication failed") {
            return AgentStatus(provider: .claude, availability: .sessionExpired, message: message)
        }

        return AgentStatus(provider: .claude, availability: .error(message), message: message)
    }

    private func classifyCodexStatus(message: String) -> AgentStatus {
        let normalized = message.lowercased()

        if normalized.contains("not installed or not on path") {
            return AgentStatus(provider: .codex, availability: .notInstalled, message: message)
        }
        if normalized.contains("not logged in")
            || normalized.contains("please log in") {
            return AgentStatus(provider: .codex, availability: .notLoggedIn, message: message)
        }

        return AgentStatus(provider: .codex, availability: .error(message), message: message)
    }

    private func startRefreshLoop() {
        refreshTask?.cancel()
        refreshTask = Task {
            await refresh()
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(autoRefreshInterval.duration))
                guard !Task.isCancelled else {
                    break
                }
                await refresh()
            }
        }
    }
}
