import Foundation
import Testing
@testable import AIPace

struct UsageStoreTests {
    @Test
    @MainActor
    func agentStatusAndVisibleSnapshotsReflectAvailability() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UsageStore(
            claudeProbe: ProbeStub(queue: ProbeQueue([ProviderSnapshot.loading(.claude)])),
            codexProbe: ProbeStub(queue: ProbeQueue([ProviderSnapshot.loading(.codex)])),
            copilotProbe: CopilotProbeStub(queue: CopilotProbeQueue([CopilotSnapshot.loading()])),
            notificationManager: NotificationManagerSpy(),
            userDefaults: defaults,
            startRefreshLoop: false
        )
        store.claude = makeSnapshot(.claude, fiveHourUsed: 15, weeklyUsed: 45)
        store.codex = makeSnapshot(.codex, fiveHourMessage: "Codex is not installed or not on PATH.", weeklyMessage: "Codex is not installed or not on PATH.")
        store.copilot = makeCopilotSnapshot(
            primaryKind: .month,
            primaryValue: "17",
            secondaryKind: .today,
            secondaryValue: "2",
            detail: "octocat"
        )

        #expect(store.agentStatus(for: ProviderKind.claude).availability == AgentAvailability.available)
        #expect(store.agentStatus(for: ProviderKind.codex).availability == AgentAvailability.notInstalled)
        #expect(store.agentStatus(for: ProviderKind.copilot).availability == AgentAvailability.available)
        #expect(store.visibleSnapshots.map { $0.provider } == [ProviderKind.claude])
        #expect(store.showsCopilotCard)
        #expect(store.visibleCardCount == 2)
        #expect(store.hasVisibleSnapshots)
        #expect(store.menuBarTitle == "Cl 15/45  Cx --/--")

        store.setProviderVisibilityEnabled(false, for: .claude)

        #expect(store.visibleSnapshots.isEmpty)
        #expect(store.showsCopilotCard)
        #expect(store.visibleCardCount == 1)
    }

    @Test
    @MainActor
    func copilotStatusTracksSavedAndClearedToken() async {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        actor TokenBox {
            var token: String?

            func setToken(_ token: String?) {
                self.token = token
            }

            func value() -> String? {
                token
            }
        }

        let tokenBox = TokenBox()
        let credentialStore = GitHubCopilotCredentialStore(
            loadOverride: { nil },
            saveOverride: { token in
                Task { await tokenBox.setToken(token) }
            },
            deleteOverride: {
                Task { await tokenBox.setToken(nil) }
            }
        )
        let webSession = GitHubCopilotWebSession(
            fetchOverride: {
                makeCopilotSnapshot(
                    primaryKind: .premiumRequests,
                    primaryValue: "7.4%",
                    primaryProgress: 7.4,
                    detail: "Managed by nioer"
                )
            },
            openLoginOverride: {}
        )

        let store = UsageStore(
            claudeProbe: ProbeStub(queue: ProbeQueue([ProviderSnapshot.loading(.claude)])),
            codexProbe: ProbeStub(queue: ProbeQueue([ProviderSnapshot.loading(.codex)])),
            copilotProbe: CopilotProbeStub(queue: CopilotProbeQueue([
                makeCopilotSnapshot(
                    primaryKind: .month,
                    primaryValue: "19",
                    secondaryKind: .today,
                    secondaryValue: "4",
                    detail: "octocat"
                ),
            ])),
            copilotCredentialStore: credentialStore,
            copilotWebSession: webSession,
            notificationManager: NotificationManagerSpy(),
            userDefaults: defaults,
            startRefreshLoop: false
        )

        store.saveCopilotToken("  test-token  ")
        let didRefresh = await waitUntil {
            await MainActor.run {
                store.copilot.primary.valueText == "19" && store.copilot.secondary?.valueText == "4"
            }
        }

        #expect(didRefresh)
        #expect(await tokenBox.value() == "test-token")
        #expect(store.agentStatus(for: .copilot).availability == .available)

        store.clearCopilotToken()

        #expect(store.copilot.primary.message == "GitHub sign in required.")
        #expect(store.agentStatus(for: .copilot).availability == .missingAuth)
    }

    @Test
    @MainActor
    func copilotWebUsageEstimatesMonthlyAllowanceAndUpdatesWhenAllowanceChanges() async {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UsageStore(
            claudeProbe: ProbeStub(queue: ProbeQueue([ProviderSnapshot.loading(.claude)])),
            codexProbe: ProbeStub(queue: ProbeQueue([ProviderSnapshot.loading(.codex)])),
            copilotProbe: CopilotProbeStub(queue: CopilotProbeQueue([
                makeCopilotSnapshot(
                    primaryKind: .premiumRequests,
                    primaryValue: "7.4%",
                    primaryProgress: 7.4,
                    detail: "Managed by nioer"
                ),
            ])),
            notificationManager: NotificationManagerSpy(),
            userDefaults: defaults,
            startRefreshLoop: false
        )

        await store.refresh()

        #expect(store.copilot.primary.valueText == "7.4%")
        #expect(store.copilot.secondary?.kind == .month)
        #expect(store.copilot.secondary?.valueText == "~22/300")
        #expect(store.copilot.primary.resetsAt != nil)

        store.setCopilotMonthlyAllowance(500)

        #expect(store.copilot.secondary?.valueText == "~37/500")
    }

    @Test
    @MainActor
    func refreshPreservesPreviousSnapshotOnRateLimitErrors() async {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let previousClaude = makeSnapshot(.claude, fiveHourUsed: 20, weeklyUsed: 70)
        let previousCodex = makeSnapshot(.codex, fiveHourUsed: 5, weeklyUsed: 10)
        let claudeQueue = ProbeQueue([
            makeSnapshot(.claude, fiveHourMessage: "HTTP 429 rate limit", weeklyMessage: "HTTP 429 rate limit"),
        ])
        let codexQueue = ProbeQueue([
            makeSnapshot(.codex, fiveHourUsed: 11, weeklyUsed: 22),
        ])
        let store = UsageStore(
            claudeProbe: ProbeStub(queue: claudeQueue),
            codexProbe: ProbeStub(queue: codexQueue),
            notificationManager: NotificationManagerSpy(),
            userDefaults: defaults,
            startRefreshLoop: false
        )
        store.claude = previousClaude
        store.codex = previousCodex

        await store.refresh()

        #expect(store.claude.fiveHour.usedPercentage == 20)
        #expect(store.claude.weekly.usedPercentage == 70)
        #expect(store.codex.fiveHour.usedPercentage == 11)
        #expect(store.codex.weekly.usedPercentage == 22)
        #expect(store.lastUpdated != nil)
    }

    @Test
    @MainActor
    func refreshPreservesFirstTransientClaudeAuthFailureOnly() async {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let previousClaude = makeSnapshot(.claude, fiveHourUsed: 20, weeklyUsed: 70)
        let claudeQueue = ProbeQueue([
            makeSnapshot(.claude, fiveHourMessage: "Claude authentication failed.", weeklyMessage: "Claude authentication failed."),
            makeSnapshot(.claude, fiveHourMessage: "Claude authentication failed.", weeklyMessage: "Claude authentication failed."),
        ])
        let codexQueue = ProbeQueue([
            makeSnapshot(.codex, fiveHourUsed: 11, weeklyUsed: 22),
            makeSnapshot(.codex, fiveHourUsed: 11, weeklyUsed: 22),
        ])
        let store = UsageStore(
            claudeProbe: ProbeStub(queue: claudeQueue),
            codexProbe: ProbeStub(queue: codexQueue),
            notificationManager: NotificationManagerSpy(),
            userDefaults: defaults,
            startRefreshLoop: false
        )
        store.claude = previousClaude

        await store.refresh()

        #expect(store.claude.fiveHour.usedPercentage == 20)
        #expect(store.claude.weekly.usedPercentage == 70)
        #expect(store.agentStatus(for: .claude).availability == .available)

        await store.refresh()

        #expect(store.claude.fiveHour.usedPercentage == nil)
        #expect(store.claude.weekly.usedPercentage == nil)
        #expect(store.claude.fiveHour.message == "Claude authentication failed.")
        #expect(store.agentStatus(for: .claude).availability == .sessionExpired)
    }

    @Test
    @MainActor
    func refreshSendsNotificationWhenUsageWindowResets() async {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let key = UsageWindowKey(provider: .claude, kind: .fiveHour)
        defaults.set([key.storageKey], forKey: "refreshNotificationKeys")

        let previousReset = Date(timeIntervalSince1970: 1_000)
        let currentReset = previousReset.addingTimeInterval(600)
        let notificationManager = NotificationManagerSpy()
        let store = UsageStore(
            claudeProbe: ProbeStub(queue: ProbeQueue([
                makeSnapshot(.claude, fiveHourUsed: 5, weeklyUsed: 25, fiveHourReset: currentReset, weeklyReset: currentReset),
            ])),
            codexProbe: ProbeStub(queue: ProbeQueue([
                makeSnapshot(.codex, fiveHourUsed: 10, weeklyUsed: 20),
            ])),
            notificationManager: notificationManager,
            userDefaults: defaults,
            startRefreshLoop: false
        )
        store.claude = makeSnapshot(.claude, fiveHourUsed: 95, weeklyUsed: 80, fiveHourReset: previousReset, weeklyReset: previousReset)

        await store.refresh()

        #expect(notificationManager.sentKeys == [key])
        #expect(notificationManager.sentSounds == [.systemDefault])
    }

    @Test
    @MainActor
    func setRefreshNotificationsEnabledPersistsOnlyWhenAuthorized() async {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let notificationManager = NotificationManagerSpy()
        let store = UsageStore(
            claudeProbe: ProbeStub(queue: ProbeQueue([ProviderSnapshot.loading(.claude)])),
            codexProbe: ProbeStub(queue: ProbeQueue([ProviderSnapshot.loading(.codex)])),
            notificationManager: notificationManager,
            userDefaults: defaults,
            startRefreshLoop: false
        )
        let key = UsageWindowKey(provider: .codex, kind: .weekly)

        await store.setRefreshNotificationsEnabled(true, for: key)
        #expect(notificationManager.authorizationRequests == 1)
        #expect(store.refreshNotificationsEnabled(for: key))
        #expect(defaults.stringArray(forKey: "refreshNotificationKeys") == [key.storageKey])

        notificationManager.authorizationGranted = false
        await store.setRefreshNotificationsEnabled(false, for: key)
        #expect(!store.refreshNotificationsEnabled(for: key))
        #expect(defaults.stringArray(forKey: "refreshNotificationKeys") == [])

        await store.setRefreshNotificationsEnabled(true, for: key)
        #expect(!store.refreshNotificationsEnabled(for: key))
        #expect(defaults.stringArray(forKey: "refreshNotificationKeys") == [])
    }

    @Test
    @MainActor
    func refreshNotificationAuthorizationStateClearsEnabledKeysWhenSystemNotificationsAreDisabled() async {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let key = UsageWindowKey(provider: .claude, kind: .weekly)
        defaults.set([key.storageKey], forKey: "refreshNotificationKeys")

        let notificationManager = NotificationManagerSpy()
        notificationManager.systemNotificationsDisabled = true

        let store = UsageStore(
            claudeProbe: ProbeStub(queue: ProbeQueue([ProviderSnapshot.loading(.claude)])),
            codexProbe: ProbeStub(queue: ProbeQueue([ProviderSnapshot.loading(.codex)])),
            notificationManager: notificationManager,
            userDefaults: defaults,
            startRefreshLoop: false
        )

        #expect(store.refreshNotificationsEnabled(for: key))

        await store.refreshNotificationAuthorizationState()

        #expect(store.notificationsDisabledInSystem)
        #expect(!store.refreshNotificationsEnabled(for: key))
        #expect(defaults.stringArray(forKey: "refreshNotificationKeys") == [])
    }

    @Test
    @MainActor
    func setAutoRefreshIntervalPersistsSelection() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let store = UsageStore(
            claudeProbe: ProbeStub(queue: ProbeQueue([ProviderSnapshot.loading(.claude)])),
            codexProbe: ProbeStub(queue: ProbeQueue([ProviderSnapshot.loading(.codex)])),
            notificationManager: NotificationManagerSpy(),
            userDefaults: defaults,
            startRefreshLoop: false
        )

        store.setAutoRefreshInterval(AutoRefreshInterval.tenMinutes)

        #expect(store.autoRefreshInterval == AutoRefreshInterval.tenMinutes)
        #expect(defaults.integer(forKey: "autoRefreshInterval") == AutoRefreshInterval.tenMinutes.rawValue)
    }

    @Test
    @MainActor
    func manualRefreshRunsInitialRefreshOnly() async {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(AutoRefreshInterval.manual.rawValue, forKey: "autoRefreshInterval")

        let claudeCounter = ProbeCounter()
        let codexCounter = ProbeCounter()
        let store = UsageStore(
            claudeProbe: CountingProbe(
                snapshot: makeSnapshot(.claude, fiveHourUsed: 10, weeklyUsed: 20),
                counter: claudeCounter
            ),
            codexProbe: CountingProbe(
                snapshot: makeSnapshot(.codex, fiveHourUsed: 30, weeklyUsed: 40),
                counter: codexCounter
            ),
            notificationManager: NotificationManagerSpy(),
            userDefaults: defaults,
            startRefreshLoop: true
        )

        let didRefresh = await waitUntil {
            let claudeCalls = await claudeCounter.value()
            let codexCalls = await codexCounter.value()
            return claudeCalls == 1 && codexCalls == 1
        }
        #expect(didRefresh)

        try? await Task.sleep(for: .milliseconds(50))

        #expect(await claudeCounter.value() == 1)
        #expect(await codexCounter.value() == 1)
        #expect(store.autoRefreshInterval == .manual)
    }

    @Test
    @MainActor
    func switchingFromManualToTimedRefreshRestartsImmediateRefresh() async {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }
        defaults.set(AutoRefreshInterval.manual.rawValue, forKey: "autoRefreshInterval")

        let claudeCounter = ProbeCounter()
        let codexCounter = ProbeCounter()
        let store = UsageStore(
            claudeProbe: CountingProbe(
                snapshot: makeSnapshot(.claude, fiveHourUsed: 10, weeklyUsed: 20),
                counter: claudeCounter
            ),
            codexProbe: CountingProbe(
                snapshot: makeSnapshot(.codex, fiveHourUsed: 30, weeklyUsed: 40),
                counter: codexCounter
            ),
            notificationManager: NotificationManagerSpy(),
            userDefaults: defaults,
            startRefreshLoop: true
        )

        let initialRefresh = await waitUntil {
            let claudeCalls = await claudeCounter.value()
            let codexCalls = await codexCounter.value()
            return claudeCalls == 1 && codexCalls == 1
        }
        #expect(initialRefresh)

        store.setAutoRefreshInterval(.oneMinute)

        let restartedRefresh = await waitUntil {
            let claudeCalls = await claudeCounter.value()
            let codexCalls = await codexCounter.value()
            return claudeCalls == 2 && codexCalls == 2
        }
        #expect(restartedRefresh)
        #expect(defaults.integer(forKey: "autoRefreshInterval") == AutoRefreshInterval.oneMinute.rawValue)
    }

    @Test
    @MainActor
    func notificationSoundPersistsAndPreviewUsesManager() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let notificationManager = NotificationManagerSpy()
        let store = UsageStore(
            claudeProbe: ProbeStub(queue: ProbeQueue([ProviderSnapshot.loading(.claude)])),
            codexProbe: ProbeStub(queue: ProbeQueue([ProviderSnapshot.loading(.codex)])),
            notificationManager: notificationManager,
            userDefaults: defaults,
            startRefreshLoop: false
        )

        store.setNotificationSound(.frog)
        store.previewNotificationSound()

        #expect(store.notificationSound == .frog)
        #expect(defaults.string(forKey: "notificationSound") == NotificationSoundOption.frog.rawValue)
        #expect(notificationManager.previewedSounds == [.frog])
    }

    @Test
    @MainActor
    func launchAtStartupReflectsManagerStateAndUpdatesOnToggle() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        let launchManager = LaunchAtStartupManagerSpy()
        launchManager.state = .requiresApproval

        let store = UsageStore(
            claudeProbe: ProbeStub(queue: ProbeQueue([ProviderSnapshot.loading(.claude)])),
            codexProbe: ProbeStub(queue: ProbeQueue([ProviderSnapshot.loading(.codex)])),
            notificationManager: NotificationManagerSpy(),
            launchAtStartupManager: launchManager,
            userDefaults: defaults,
            startRefreshLoop: false
        )

        #expect(store.launchAtStartupEnabled)
        #expect(store.launchAtStartupNeedsApproval)
        #expect(store.launchAtStartupSupported)

        store.setLaunchAtStartupEnabled(false)

        #expect(launchManager.setCalls == [false])
        #expect(store.launchAtStartupState == .disabled)
        #expect(!store.launchAtStartupEnabled)
        #expect(store.launchAtStartupErrorMessage == nil)
    }

    @Test
    @MainActor
    func launchAtStartupKeepsStateAndExposesErrorWhenUpdateFails() {
        let suiteName = UUID().uuidString
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { defaults.removePersistentDomain(forName: suiteName) }

        struct LaunchError: LocalizedError {
            var errorDescription: String? { "Operation not permitted" }
        }

        let launchManager = LaunchAtStartupManagerSpy()
        launchManager.state = .unsupported
        launchManager.failure = LaunchError()

        let store = UsageStore(
            claudeProbe: ProbeStub(queue: ProbeQueue([ProviderSnapshot.loading(.claude)])),
            codexProbe: ProbeStub(queue: ProbeQueue([ProviderSnapshot.loading(.codex)])),
            notificationManager: NotificationManagerSpy(),
            launchAtStartupManager: launchManager,
            userDefaults: defaults,
            startRefreshLoop: false
        )

        store.setLaunchAtStartupEnabled(true)

        #expect(launchManager.setCalls == [true])
        #expect(store.launchAtStartupState == .unsupported)
        #expect(!store.launchAtStartupSupported)
        #expect(store.launchAtStartupErrorMessage == "Operation not permitted")
    }
}
