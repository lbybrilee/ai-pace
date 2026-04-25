import Foundation

/// Estimates burn rate and recommends a pace so the user can last until the
/// usage window resets. Driven purely by the percentage history we already
/// record in `UsageHistoryStore`, so it works for any provider/window.
struct PacingAdvice: Equatable, Sendable {
    /// Recent burn rate in percentage points per hour. Nil when we have too little data.
    let currentRatePerHour: Double?
    /// Pace (percentage points per hour) that exactly consumes the remaining
    /// budget by `resetsAt`. Nil if the window is already exhausted or we
    /// don't know the reset time.
    let recommendedRatePerHour: Double?
    /// Wall-clock time at which we project usage will reach 100% at the
    /// current burn rate. Nil when we cannot project (no rate, idle, etc).
    let projectedExhaustion: Date?
    /// True when the current rate exceeds the recommended pace. Drives
    /// red/amber UI cues.
    let isOverPace: Bool
}

enum PacingCoach {
    /// Minimum rate (% per hour) we treat as "burning" for projection purposes.
    /// Below this we won't bother projecting an ETA - the user is effectively idle.
    static let minimumProjectableRate: Double = 0.5

    /// Maximum lookback for measuring current rate. Anything older is ignored.
    static let rateLookback: TimeInterval = 60 * 60 // 1h

    /// We need at least this much spread between samples to compute a rate.
    static let minimumSampleSpan: TimeInterval = 5 * 60 // 5min

    static func advise(
        usedPercentage: Double?,
        resetsAt: Date?,
        samples: [UsageHistoryStore.Sample],
        now: Date = .now
    ) -> PacingAdvice {
        let currentRate = currentRatePerHour(samples: samples, now: now)
        let recommendedRate = recommendedRatePerHour(
            usedPercentage: usedPercentage,
            resetsAt: resetsAt,
            now: now
        )
        let projectedExhaustion = projectExhaustion(
            usedPercentage: usedPercentage,
            currentRatePerHour: currentRate,
            now: now
        )

        let isOverPace: Bool = {
            guard let currentRate, let recommendedRate else { return false }
            return currentRate > recommendedRate * 1.10 // 10% slack
        }()

        return PacingAdvice(
            currentRatePerHour: currentRate,
            recommendedRatePerHour: recommendedRate,
            projectedExhaustion: projectedExhaustion,
            isOverPace: isOverPace
        )
    }

    static func currentRatePerHour(samples: [UsageHistoryStore.Sample], now: Date) -> Double? {
        let cutoff = now.timeIntervalSince1970 - rateLookback
        let recent = samples.filter { $0.timestamp >= cutoff }
        guard recent.count >= 2,
              let first = recent.first,
              let last = recent.last else { return nil }

        let spanSeconds = last.timestamp - first.timestamp
        guard spanSeconds >= minimumSampleSpan else { return nil }

        let delta = last.percentage - first.percentage
        // If the window reset mid-span, delta will be sharply negative; ignore.
        guard delta >= 0 else { return nil }

        let ratePerSecond = delta / spanSeconds
        return ratePerSecond * 3600
    }

    static func recommendedRatePerHour(
        usedPercentage: Double?,
        resetsAt: Date?,
        now: Date
    ) -> Double? {
        guard let used = usedPercentage, let resetsAt else { return nil }
        let remaining = max(0, 100 - used)
        let secondsLeft = resetsAt.timeIntervalSince(now)
        guard secondsLeft > 60 else { return nil }
        return remaining / (secondsLeft / 3600)
    }

    static func projectExhaustion(
        usedPercentage: Double?,
        currentRatePerHour: Double?,
        now: Date
    ) -> Date? {
        guard let used = usedPercentage,
              let rate = currentRatePerHour,
              rate >= minimumProjectableRate,
              used < 100 else { return nil }
        let remaining = max(0, 100 - used)
        let secondsToExhaust = (remaining / rate) * 3600
        return now.addingTimeInterval(secondsToExhaust)
    }
}
