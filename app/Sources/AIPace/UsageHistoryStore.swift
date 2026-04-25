import Foundation

/// Lightweight ring-buffer store for usage percentages per window.
/// Persists to UserDefaults as JSON; capped at `maxSamplesPerKey` points keyed by
/// `UsageWindowKey.storageKey`. Used by the sparkline UI.
struct UsageHistoryStore: Sendable, Equatable {
    struct Sample: Codable, Sendable, Equatable {
        let timestamp: Double  // seconds since epoch
        let percentage: Double
    }

    static let maxSamplesPerKey = 144   // 24h worth of samples at 10-minute spacing
    static let minSampleSpacing: TimeInterval = 60  // don't record more than once per minute
    static let historyWindow: TimeInterval = 24 * 60 * 60

    private(set) var samplesByKey: [String: [Sample]]

    init(samplesByKey: [String: [Sample]] = [:]) {
        self.samplesByKey = samplesByKey
    }

    static func load(from defaults: UserDefaults, key: String) -> UsageHistoryStore {
        guard let data = defaults.data(forKey: key),
              let decoded = try? JSONDecoder().decode([String: [Sample]].self, from: data)
        else {
            return UsageHistoryStore()
        }
        return UsageHistoryStore(samplesByKey: decoded)
    }

    mutating func record(_ percentage: Double, for key: UsageWindowKey, now: Date = .now) {
        let storageKey = key.storageKey
        var existing = samplesByKey[storageKey] ?? []

        if let last = existing.last,
           now.timeIntervalSince1970 - last.timestamp < Self.minSampleSpacing {
            // Replace the latest sample instead of appending when we get a second refresh quickly.
            existing.removeLast()
        }

        existing.append(Sample(timestamp: now.timeIntervalSince1970, percentage: percentage))

        // Trim old samples outside the 24h window.
        let cutoff = now.timeIntervalSince1970 - Self.historyWindow
        existing.removeAll { $0.timestamp < cutoff }

        // Hard cap to prevent unbounded growth if clock skews.
        if existing.count > Self.maxSamplesPerKey {
            existing.removeFirst(existing.count - Self.maxSamplesPerKey)
        }

        samplesByKey[storageKey] = existing
    }

    func samples(for key: UsageWindowKey) -> [Sample] {
        samplesByKey[key.storageKey] ?? []
    }

    func persist(to defaults: UserDefaults, key: String) {
        guard let data = try? JSONEncoder().encode(samplesByKey) else { return }
        defaults.set(data, forKey: key)
    }
}
