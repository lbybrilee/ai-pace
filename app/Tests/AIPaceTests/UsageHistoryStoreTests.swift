import Foundation
import Testing
@testable import AIPace

struct UsageHistoryStoreTests {
    @Test
    func recordAppendsSamplesForDistinctKeys() {
        var store = UsageHistoryStore()
        let claudeFive = UsageWindowKey(provider: .claude, kind: .fiveHour)
        let codexWeekly = UsageWindowKey(provider: .codex, kind: .weekly)
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        store.record(25, for: claudeFive, now: base)
        store.record(40, for: claudeFive, now: base.addingTimeInterval(300))
        store.record(10, for: codexWeekly, now: base.addingTimeInterval(600))

        #expect(store.samples(for: claudeFive).count == 2)
        #expect(store.samples(for: claudeFive).last?.percentage == 40)
        #expect(store.samples(for: codexWeekly).count == 1)
    }

    @Test
    func recordReplacesLastSampleWhenTakenWithinDebounceWindow() {
        var store = UsageHistoryStore()
        let key = UsageWindowKey(provider: .claude, kind: .weekly)
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        store.record(10, for: key, now: base)
        store.record(12, for: key, now: base.addingTimeInterval(10))  // within 60s debounce
        store.record(15, for: key, now: base.addingTimeInterval(120)) // outside debounce

        let samples = store.samples(for: key)
        #expect(samples.count == 2)
        #expect(samples[0].percentage == 12)
        #expect(samples[1].percentage == 15)
    }

    @Test
    func recordDropsSamplesOlderThanWindow() {
        var store = UsageHistoryStore()
        let key = UsageWindowKey(provider: .codex, kind: .fiveHour)
        let base = Date(timeIntervalSince1970: 1_700_000_000)

        store.record(50, for: key, now: base)
        store.record(60, for: key, now: base.addingTimeInterval(UsageHistoryStore.historyWindow + 60))

        let samples = store.samples(for: key)
        #expect(samples.count == 1)
        #expect(samples.first?.percentage == 60)
    }

    @Test
    func persistAndLoadRoundTrips() throws {
        let suiteName = "UsageHistoryStoreTests.persist.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suiteName))
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        var store = UsageHistoryStore()
        let key = UsageWindowKey(provider: .claude, kind: .weekly)
        store.record(42, for: key, now: Date(timeIntervalSince1970: 1_700_000_000))
        store.persist(to: defaults, key: "history")

        let reloaded = UsageHistoryStore.load(from: defaults, key: "history")
        #expect(reloaded.samples(for: key).count == 1)
        #expect(reloaded.samples(for: key).first?.percentage == 42)
    }
}
