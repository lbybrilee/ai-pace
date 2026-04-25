import Foundation
import SwiftUI

protocol ProviderSnapshotFetching: Sendable {
    func fetch() async -> ProviderSnapshot
}

extension ClaudeProbe: ProviderSnapshotFetching {}
extension CodexProbe: ProviderSnapshotFetching {}

@MainActor
final class UsageStore: ObservableObject {
    @Published var claude = ProviderSnapshot.loading(.claude)
    @Published var codex = ProviderSnapshot.loading(.codex)
    @Published var lastUpdated: Date?
    @Published var isRefreshing = false
    @Published private(set) var refreshNotificationKeys: Set<String>
    @Published var autoRefreshInterval: AutoRefreshInterval
    @Published var notificationSound: NotificationSoundOption
    @Published private(set) var notificationsDisabledInSystem = false
    @Published private(set) var launchAtStartupState: LaunchAtStartupState
    @Published private(set) var launchAtStartupErrorMessage: String?

    private let claudeProbe: any ProviderSnapshotFetching
    private let codexProbe: any ProviderSnapshotFetching
    private let notificationManager: any NotificationManaging
    private let launchAtStartupManager: any LaunchAtStartupManaging
    private let userDefaults: UserDefaults
    private var refreshTask: Task<Void, Never>?
    private var preservedFailureCounts: [ProviderKind: Int] = [:]
    private let refreshNotificationDefaultsKey = "refreshNotificationKeys"
    private let autoRefreshIntervalDefaultsKey = "autoRefreshInterval"
    private let notificationSoundDefaultsKey = "notificationSound"

    init(
        claudeProbe: any ProviderSnapshotFetching = ClaudeProbe(),
        codexProbe: any ProviderSnapshotFetching = CodexProbe(),
        notificationManager: any NotificationManaging = NotificationManager(),
        launchAtStartupManager: any LaunchAtStartupManaging = LaunchAtStartupManager(),
        userDefaults: UserDefaults = .standard,
        startRefreshLoop: Bool = true
    ) {
        self.claudeProbe = claudeProbe
        self.codexProbe = codexProbe
        self.notificationManager = notificationManager
        self.launchAtStartupManager = launchAtStartupManager
        self.userDefaults = userDefaults
        refreshNotificationKeys = Set(userDefaults.stringArray(forKey: refreshNotificationDefaultsKey) ?? [])
        let storedInterval = userDefaults.integer(forKey: autoRefreshIntervalDefaultsKey)
        autoRefreshInterval = AutoRefreshInterval(rawValue: storedInterval) ?? .defaultValue
        notificationSound = NotificationSoundOption(
            rawValue: userDefaults.string(forKey: notificationSoundDefaultsKey) ?? NotificationSoundOption.systemDefault.rawValue
        ) ?? .systemDefault
        launchAtStartupState = launchAtStartupManager.currentState()
        launchAtStartupErrorMessage = nil
        if startRefreshLoop {
            self.startRefreshLoop()
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    var menuBarTitle: String {
        let claudeName = ProviderDisplayName.displayName(for: .claude, userDefaults: userDefaults)
        let codexName = ProviderDisplayName.displayName(for: .codex, userDefaults: userDefaults)
        return "\(claudeName) \(compactValue(for: claude.fiveHour))/\(compactValue(for: claude.weekly))  \(codexName) \(compactValue(for: codex.fiveHour))/\(compactValue(for: codex.weekly))"
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

        let resolvedClaude = mergedSnapshot(previous: previousClaude, current: newClaude)
        let resolvedCodex = mergedSnapshot(previous: previousCodex, current: newCodex)

        claude = resolvedClaude
        codex = resolvedCodex
        lastUpdated = Date()

        await notifyIfWindowRefreshed(previous: previousClaude, current: resolvedClaude)
        await notifyIfWindowRefreshed(previous: previousCodex, current: resolvedCodex)
    }

    func setAutoRefreshInterval(_ interval: AutoRefreshInterval) {
        guard autoRefreshInterval != interval else {
            return
        }
        autoRefreshInterval = interval
        userDefaults.set(interval.rawValue, forKey: autoRefreshIntervalDefaultsKey)
        startRefreshLoop()
    }

    func setNotificationSound(_ option: NotificationSoundOption) {
        guard notificationSound != option else {
            return
        }
        notificationSound = option
        userDefaults.set(option.rawValue, forKey: notificationSoundDefaultsKey)
    }

    func previewNotificationSound() {
        notificationManager.preview(sound: notificationSound)
    }

    var launchAtStartupEnabled: Bool {
        switch launchAtStartupState {
        case .enabled, .requiresApproval:
            return true
        case .disabled, .unsupported:
            return false
        }
    }

    var launchAtStartupNeedsApproval: Bool {
        launchAtStartupState == .requiresApproval
    }

    var launchAtStartupSupported: Bool {
        launchAtStartupState != .unsupported
    }

    func setLaunchAtStartupEnabled(_ enabled: Bool) {
        do {
            launchAtStartupState = try launchAtStartupManager.setEnabled(enabled)
            launchAtStartupErrorMessage = nil
        } catch {
            launchAtStartupState = launchAtStartupManager.currentState()
            launchAtStartupErrorMessage = error.localizedDescription
        }
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

    func refreshNotificationAuthorizationState() async {
        let disabledInSystem = await notificationManager.notificationsDisabledInSystem()
        applyNotificationAuthorizationState(disabledInSystem: disabledInSystem)
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
            await refreshNotificationAuthorizationState()
            guard granted else {
                return
            }
            var updatedKeys = refreshNotificationKeys
            updatedKeys.insert(key.storageKey)
            refreshNotificationKeys = updatedKeys
        } else {
            var updatedKeys = refreshNotificationKeys
            updatedKeys.remove(key.storageKey)
            refreshNotificationKeys = updatedKeys
        }
        persistRefreshNotificationKeys()
    }

    private func persistRefreshNotificationKeys() {
        userDefaults.set(Array(refreshNotificationKeys).sorted(), forKey: refreshNotificationDefaultsKey)
    }

    private func applyNotificationAuthorizationState(disabledInSystem: Bool) {
        notificationsDisabledInSystem = disabledInSystem

        guard disabledInSystem, !refreshNotificationKeys.isEmpty else {
            return
        }

        refreshNotificationKeys = []
        persistRefreshNotificationKeys()
    }

    private func notifyIfWindowRefreshed(previous: ProviderSnapshot, current: ProviderSnapshot) async {
        await notifyIfWindowRefreshed(
            key: UsageWindowKey(provider: current.provider, kind: .fiveHour),
            previous: previous.fiveHour,
            current: current.fiveHour
        )
        await notifyIfWindowRefreshed(
            key: UsageWindowKey(provider: current.provider, kind: .weekly),
            previous: previous.weekly,
            current: current.weekly
        )
    }

    private func notifyIfWindowRefreshed(key: UsageWindowKey, previous: UsageWindow, current: UsageWindow) async {
        guard refreshNotificationsEnabled(for: key) else {
            return
        }
        guard let previousReset = previous.resetsAt, let currentReset = current.resetsAt else {
            return
        }
        guard currentReset.timeIntervalSince(previousReset) > 60 else {
            return
        }

        await notificationManager.sendRefreshNotification(for: key, sound: notificationSound)
    }

    private func snapshot(for provider: ProviderKind) -> ProviderSnapshot {
        switch provider {
        case .claude:
            return claude
        case .codex:
            return codex
        }
    }

    private func mergedSnapshot(previous: ProviderSnapshot, current: ProviderSnapshot) -> ProviderSnapshot {
        guard shouldPreservePreviousSnapshot(
            previous: previous,
            current: current,
            preservedFailureCount: preservedFailureCounts[current.provider, default: 0]
        ) else {
            preservedFailureCounts[current.provider] = 0
            return current
        }
        preservedFailureCounts[current.provider, default: 0] += 1
        return previous
    }

    private func shouldPreservePreviousSnapshot(
        previous: ProviderSnapshot,
        current: ProviderSnapshot,
        preservedFailureCount: Int
    ) -> Bool {
        let hasCurrentData = current.fiveHour.usedPercentage != nil || current.weekly.usedPercentage != nil
        guard !hasCurrentData else {
            return false
        }

        let hadPreviousData = previous.fiveHour.usedPercentage != nil || previous.weekly.usedPercentage != nil
        guard hadPreviousData else {
            return false
        }

        let message = (current.fiveHour.message ?? current.weekly.message ?? "").lowercased()
        if message.contains("http 429") || message.contains("rate limit") {
            return true
        }

        guard current.provider == .claude, preservedFailureCount == 0 else {
            return false
        }

        return isTransientClaudeAuthFailure(message)
    }

    private func isTransientClaudeAuthFailure(_ message: String) -> Bool {
        message.contains("credentials not found")
            || message.contains("credentials could not be read")
            || message.contains("authentication failed")
            || message.contains("session expired")
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
            guard autoRefreshInterval != .manual else {
                return
            }
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
