import Foundation
import SwiftUI

protocol ProviderSnapshotFetching: Sendable {
    func fetch() async -> ProviderSnapshot
}

extension ClaudeProbe: ProviderSnapshotFetching {}
extension CodexProbe: ProviderSnapshotFetching {}

@MainActor
protocol CopilotSnapshotFetching: AnyObject {
    func fetch() async -> CopilotSnapshot
}

extension GitHubCopilotProbe: CopilotSnapshotFetching {}

@MainActor
final class UsageStore: ObservableObject {
    static let defaultCopilotMonthlyAllowance = 300

    @Published var claude = ProviderSnapshot.loading(.claude)
    @Published var codex = ProviderSnapshot.loading(.codex)
    @Published var copilot = CopilotSnapshot.loading()
    @Published var lastUpdated: Date?
    @Published var isRefreshing = false
    @Published private(set) var refreshNotificationKeys: Set<String>
    @Published var autoRefreshInterval: AutoRefreshInterval
    @Published var notificationSound: NotificationSoundOption
    @Published private(set) var usagePerspective: UsagePerspective
    @Published private(set) var notificationsDisabledInSystem = false
    @Published private(set) var launchAtStartupState: LaunchAtStartupState
    @Published private(set) var launchAtStartupErrorMessage: String?
    @Published private(set) var copilotMonthlyAllowance: Int
    @Published private(set) var visibleProviders: Set<ProviderKind>
    @Published private(set) var copilotDisplayMode: CopilotDisplayMode

    private let claudeProbe: any ProviderSnapshotFetching
    private let codexProbe: any ProviderSnapshotFetching
    private let copilotProbe: any CopilotSnapshotFetching
    private let copilotCredentialStore: GitHubCopilotCredentialStore
    private let copilotWebSession: GitHubCopilotWebSession
    private let notificationManager: any NotificationManaging
    private let launchAtStartupManager: any LaunchAtStartupManaging
    private let userDefaults: UserDefaults
    private let calendar: Calendar
    private var refreshTask: Task<Void, Never>?
    private var preservedFailureCounts: [ProviderKind: Int] = [:]
    private let refreshNotificationDefaultsKey = "refreshNotificationKeys"
    private let autoRefreshIntervalDefaultsKey = "autoRefreshInterval"
    private let notificationSoundDefaultsKey = "notificationSound"
    private let usagePerspectiveDefaultsKey = "usagePerspective"
    private let copilotMonthlyAllowanceDefaultsKey = "copilotMonthlyAllowance"
    private let visibleProvidersDefaultsKey = "visibleProviders"
    private let copilotDisplayModeDefaultsKey = "copilotDisplayMode"

    init(
        claudeProbe: any ProviderSnapshotFetching = ClaudeProbe(),
        codexProbe: any ProviderSnapshotFetching = CodexProbe(),
        copilotCredentialStore: GitHubCopilotCredentialStore = GitHubCopilotCredentialStore(),
        copilotWebSession: GitHubCopilotWebSession = GitHubCopilotWebSession(),
        copilotProbe: (any CopilotSnapshotFetching)? = nil,
        notificationManager: any NotificationManaging = NotificationManager(),
        launchAtStartupManager: any LaunchAtStartupManaging = LaunchAtStartupManager(),
        calendar: Calendar = .current,
        userDefaults: UserDefaults = .standard,
        startRefreshLoop: Bool = true
    ) {
        self.claudeProbe = claudeProbe
        self.codexProbe = codexProbe
        self.copilotCredentialStore = copilotCredentialStore
        self.copilotWebSession = copilotWebSession
        self.copilotProbe = copilotProbe ?? GitHubCopilotProbe(
            credentialStore: copilotCredentialStore,
            webSession: copilotWebSession
        )
        self.notificationManager = notificationManager
        self.launchAtStartupManager = launchAtStartupManager
        self.calendar = calendar
        self.userDefaults = userDefaults
        refreshNotificationKeys = Set(userDefaults.stringArray(forKey: refreshNotificationDefaultsKey) ?? [])
        let storedInterval = userDefaults.integer(forKey: autoRefreshIntervalDefaultsKey)
        autoRefreshInterval = AutoRefreshInterval(rawValue: storedInterval) ?? .defaultValue
        notificationSound = NotificationSoundOption(
            rawValue: userDefaults.string(forKey: notificationSoundDefaultsKey) ?? NotificationSoundOption.systemDefault.rawValue
        ) ?? .systemDefault
        usagePerspective = UsagePerspective(
            rawValue: userDefaults.string(forKey: usagePerspectiveDefaultsKey) ?? UsagePerspective.defaultValue.rawValue
        ) ?? .defaultValue
        let storedAllowance = userDefaults.integer(forKey: copilotMonthlyAllowanceDefaultsKey)
        copilotMonthlyAllowance = storedAllowance > 0 ? storedAllowance : Self.defaultCopilotMonthlyAllowance
        visibleProviders = Self.parseVisibleProviders(
            userDefaults.stringArray(forKey: visibleProvidersDefaultsKey)
        )
        copilotDisplayMode = CopilotDisplayMode(
            rawValue: userDefaults.string(forKey: copilotDisplayModeDefaultsKey) ?? CopilotDisplayMode.defaultValue.rawValue
        ) ?? .defaultValue
        launchAtStartupState = launchAtStartupManager.currentState()
        launchAtStartupErrorMessage = nil
        copilotWebSession.onUsageDetected = { [weak self] in
            Task { @MainActor [weak self] in
                await self?.refresh()
            }
        }
        if startRefreshLoop {
            self.startRefreshLoop()
        }
    }

    deinit {
        refreshTask?.cancel()
    }

    var menuBarTitle: String {
        "Cl \(compactValue(for: claude.fiveHour))/\(compactValue(for: claude.weekly))  Cx \(compactValue(for: codex.fiveHour))/\(compactValue(for: codex.weekly))"
    }

    var visibleSnapshots: [ProviderSnapshot] {
        [claude, codex].filter {
            visibleProviders.contains($0.provider) && agentStatus(for: $0.provider).availability.showsInPopover
        }
    }

    var showsCopilotCard: Bool {
        visibleProviders.contains(.copilot) && agentStatus(for: .copilot).availability.showsInPopover
    }

    var visibleCardCount: Int {
        visibleSnapshots.count + (showsCopilotCard ? 1 : 0)
    }

    var hasVisibleSnapshots: Bool {
        visibleCardCount > 0
    }

    func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }

        let previousClaude = claude
        let previousCodex = codex
        let previousCopilot = copilot

        async let claudeSnapshot = claudeProbe.fetch()
        async let codexSnapshot = codexProbe.fetch()

        let newClaude = await claudeSnapshot
        let newCodex = await codexSnapshot
        let newCopilot = normalizeCopilotSnapshot(await copilotProbe.fetch())

        let resolvedClaude = mergedSnapshot(previous: previousClaude, current: newClaude)
        let resolvedCodex = mergedSnapshot(previous: previousCodex, current: newCodex)

        claude = resolvedClaude
        codex = resolvedCodex
        copilot = mergedCopilotSnapshot(previous: previousCopilot, current: newCopilot)
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

    func setUsagePerspective(_ perspective: UsagePerspective) {
        guard usagePerspective != perspective else {
            return
        }
        usagePerspective = perspective
        userDefaults.set(perspective.rawValue, forKey: usagePerspectiveDefaultsKey)
    }

    func setCopilotMonthlyAllowance(_ allowance: Int) {
        let normalized = max(1, allowance)
        guard copilotMonthlyAllowance != normalized else {
            return
        }
        copilotMonthlyAllowance = normalized
        userDefaults.set(normalized, forKey: copilotMonthlyAllowanceDefaultsKey)
        copilot = normalizeCopilotSnapshot(copilot)
    }

    func setProviderVisibilityEnabled(_ enabled: Bool, for provider: ProviderKind) {
        var updated = visibleProviders
        if enabled {
            updated.insert(provider)
        } else {
            updated.remove(provider)
        }

        visibleProviders = updated
        userDefaults.set(
            ProviderKind.allCases.filter { updated.contains($0) }.map(\.rawValue),
            forKey: visibleProvidersDefaultsKey
        )
    }

    func setCopilotDisplayMode(_ mode: CopilotDisplayMode) {
        guard copilotDisplayMode != mode else {
            return
        }
        copilotDisplayMode = mode
        userDefaults.set(mode.rawValue, forKey: copilotDisplayModeDefaultsKey)
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
        switch provider {
        case .claude:
            return classifyProviderStatus(provider: provider, snapshot: claude)
        case .codex:
            return classifyProviderStatus(provider: provider, snapshot: codex)
        case .copilot:
            return classifyCopilotStatus()
        }
    }

    func openCopilotLogin() {
        copilotWebSession.openLoginWindow()
    }

    func saveCopilotToken(_ token: String) {
        copilotCredentialStore.saveToken(token)
        copilot = .loading()
        Task { await refresh() }
    }

    func clearCopilotToken() {
        copilotCredentialStore.deleteToken()
        copilot = CopilotSnapshot(
            primary: CopilotUsageWindow(kind: .premiumRequests, valueText: nil, progressPercent: nil, resetsAt: nil, message: "GitHub sign in required."),
            secondary: nil,
            detail: nil,
            footer: nil
        )
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

    private static func parseVisibleProviders(_ rawValues: [String]?) -> Set<ProviderKind> {
        let parsed = Set((rawValues ?? []).compactMap(ProviderKind.init(rawValue:)))
        return parsed.isEmpty ? Set(ProviderKind.allCases) : parsed
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

    private func classifyProviderStatus(provider: ProviderKind, snapshot: ProviderSnapshot) -> AgentStatus {
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
        case .copilot:
            return AgentStatus(provider: provider, availability: .error(message), message: message)
        }
    }

    private func normalizeCopilotSnapshot(_ snapshot: CopilotSnapshot, now: Date = .now) -> CopilotSnapshot {
        var normalized = snapshot
        normalized.primary = normalizedCopilotWindow(snapshot.primary, now: now)

        if let secondary = snapshot.secondary {
            normalized.secondary = normalizedCopilotWindow(secondary, now: now)
        }

        if snapshot.primary.kind == .premiumRequests,
           let progress = snapshot.primary.progressPercent,
           snapshot.primary.valueText != nil {
            normalized.secondary = CopilotUsageWindow(
                kind: .month,
                valueText: estimatedCopilotMonthlyUsageText(progressPercent: progress),
                progressPercent: progress,
                resetsAt: nil,
                message: nil
            )
        }

        return normalized
    }

    private func normalizedCopilotWindow(_ window: CopilotUsageWindow, now: Date) -> CopilotUsageWindow {
        guard window.resetsAt == nil, window.valueText != nil || window.progressPercent != nil else {
            return window
        }

        return CopilotUsageWindow(
            kind: window.kind,
            valueText: window.valueText,
            progressPercent: window.progressPercent,
            resetsAt: defaultCopilotResetDate(for: window.kind, now: now),
            message: window.message
        )
    }

    private func estimatedCopilotMonthlyUsageText(progressPercent: Double) -> String {
        let estimatedUsed = Int((Double(copilotMonthlyAllowance) * min(max(progressPercent, 0), 100) / 100).rounded())
        return "~\(estimatedUsed)/\(copilotMonthlyAllowance)"
    }

    private func defaultCopilotResetDate(for kind: CopilotUsageWindowKind, now: Date) -> Date? {
        switch kind {
        case .premiumRequests, .month:
            return startOfNextMonth(after: now)
        case .today:
            guard let tomorrow = calendar.date(byAdding: .day, value: 1, to: now) else {
                return nil
            }
            return calendar.startOfDay(for: tomorrow)
        }
    }

    private func startOfNextMonth(after date: Date) -> Date? {
        guard
            let monthStart = calendar.date(from: calendar.dateComponents([.year, .month], from: date)),
            let nextMonthStart = calendar.date(byAdding: .month, value: 1, to: monthStart)
        else {
            return nil
        }
        return nextMonthStart
    }

    private func classifyCopilotStatus() -> AgentStatus {
        if copilot.primary.valueText != nil || copilot.secondary?.valueText != nil {
            return AgentStatus(provider: .copilot, availability: .available, message: nil)
        }

        let message = copilot.primary.message ?? copilot.secondary?.message
        guard let message else {
            return AgentStatus(provider: .copilot, availability: .loading, message: nil)
        }

        if message == "Loading…" {
            return AgentStatus(provider: .copilot, availability: .loading, message: nil)
        }

        let normalized = message.lowercased()
        if normalized.contains("token not found") || normalized.contains("sign in required") {
            return AgentStatus(provider: .copilot, availability: .missingAuth, message: message)
        }
        if normalized.contains("authentication failed") {
            return AgentStatus(provider: .copilot, availability: .sessionExpired, message: message)
        }
        if normalized.contains("plan:read") || normalized.contains("cannot access the billing usage api") || normalized.contains("access was denied") {
            return AgentStatus(provider: .copilot, availability: .accessDenied, message: message)
        }
        return AgentStatus(provider: .copilot, availability: .error(message), message: message)
    }

    private func mergedCopilotSnapshot(previous: CopilotSnapshot, current: CopilotSnapshot) -> CopilotSnapshot {
        let hasCurrentData = current.primary.valueText != nil || current.secondary?.valueText != nil
        guard !hasCurrentData else {
            return current
        }

        let hadPreviousData = previous.primary.valueText != nil || previous.secondary?.valueText != nil
        guard hadPreviousData else {
            return current
        }

        let message = (current.primary.message ?? current.secondary?.message ?? "").lowercased()
        if message.contains("http 429") || message.contains("rate limit") {
            return previous
        }

        return current
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
