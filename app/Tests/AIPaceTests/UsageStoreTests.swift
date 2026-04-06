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
            notificationManager: NotificationManagerSpy(),
            userDefaults: defaults,
            startRefreshLoop: false
        )
        store.claude = makeSnapshot(.claude, fiveHourUsed: 15, weeklyUsed: 45)
        store.codex = makeSnapshot(.codex, fiveHourMessage: "Codex is not installed or not on PATH.", weeklyMessage: "Codex is not installed or not on PATH.")

        #expect(store.agentStatus(for: ProviderKind.claude).availability == AgentAvailability.available)
        #expect(store.agentStatus(for: ProviderKind.codex).availability == AgentAvailability.notInstalled)
        #expect(store.visibleSnapshots.map { $0.provider } == [ProviderKind.claude])
        #expect(store.hasVisibleSnapshots)
        #expect(store.menuBarTitle == "Cl 15/45  Cx --/--")
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
        #expect(defaults.stringArray(forKey: "refreshNotificationKeys") == [key.storageKey])

        notificationManager.authorizationGranted = false
        await store.setRefreshNotificationsEnabled(false, for: key)
        #expect(defaults.stringArray(forKey: "refreshNotificationKeys") == [])

        await store.setRefreshNotificationsEnabled(true, for: key)
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
}
