import Foundation
import Testing
@testable import AIPace

struct PacingCoachTests {
    private let base = Date(timeIntervalSince1970: 1_700_000_000)

    @Test
    func currentRateRequiresMinimumSpan() {
        let samples = [
            UsageHistoryStore.Sample(timestamp: base.timeIntervalSince1970, percentage: 10),
            UsageHistoryStore.Sample(timestamp: base.addingTimeInterval(60).timeIntervalSince1970, percentage: 12),
        ]
        let rate = PacingCoach.currentRatePerHour(samples: samples, now: base.addingTimeInterval(60))
        #expect(rate == nil)
    }

    @Test
    func currentRateComputedOverHourSpan() {
        let samples = [
            UsageHistoryStore.Sample(timestamp: base.timeIntervalSince1970, percentage: 10),
            UsageHistoryStore.Sample(timestamp: base.addingTimeInterval(1800).timeIntervalSince1970, percentage: 25),
        ]
        let rate = PacingCoach.currentRatePerHour(samples: samples, now: base.addingTimeInterval(1800))
        // 15 percentage points over 30 minutes = 30 pp/hour.
        #expect(rate != nil)
        #expect(abs((rate ?? 0) - 30) < 0.001)
    }

    @Test
    func currentRateIgnoresSamplesOutsideLookback() {
        let samples = [
            UsageHistoryStore.Sample(timestamp: base.timeIntervalSince1970, percentage: 10),
            UsageHistoryStore.Sample(
                timestamp: base.addingTimeInterval(PacingCoach.rateLookback + 1800).timeIntervalSince1970,
                percentage: 60
            ),
            UsageHistoryStore.Sample(
                timestamp: base.addingTimeInterval(PacingCoach.rateLookback + 2400).timeIntervalSince1970,
                percentage: 70
            ),
        ]
        let now = base.addingTimeInterval(PacingCoach.rateLookback + 2400)
        let rate = PacingCoach.currentRatePerHour(samples: samples, now: now)
        // Only the last two samples are in lookback. 10pp over 600s = 60 pp/hour.
        #expect(rate != nil)
        #expect(abs((rate ?? 0) - 60) < 0.001)
    }

    @Test
    func currentRateIgnoresWindowReset() {
        // Simulating a window reset: usage drops sharply.
        let samples = [
            UsageHistoryStore.Sample(timestamp: base.timeIntervalSince1970, percentage: 90),
            UsageHistoryStore.Sample(timestamp: base.addingTimeInterval(1800).timeIntervalSince1970, percentage: 5),
        ]
        let rate = PacingCoach.currentRatePerHour(samples: samples, now: base.addingTimeInterval(1800))
        #expect(rate == nil)
    }

    @Test
    func recommendedRateUsesRemainingBudgetOverTime() {
        let resets = base.addingTimeInterval(2 * 3600) // 2 hours away
        let rate = PacingCoach.recommendedRatePerHour(usedPercentage: 50, resetsAt: resets, now: base)
        // 50 remaining over 2h = 25 pp/h.
        #expect(rate != nil)
        #expect(abs((rate ?? 0) - 25) < 0.001)
    }

    @Test
    func recommendedRateIsNilNearReset() {
        let resets = base.addingTimeInterval(30) // 30s away
        let rate = PacingCoach.recommendedRatePerHour(usedPercentage: 50, resetsAt: resets, now: base)
        #expect(rate == nil)
    }

    @Test
    func projectedExhaustionMatchesBurnRate() {
        let exhaustion = PacingCoach.projectExhaustion(
            usedPercentage: 40,
            currentRatePerHour: 30,
            now: base
        )
        // 60 remaining at 30/hour = 2h.
        #expect(exhaustion != nil)
        let actual = exhaustion?.timeIntervalSince(base) ?? 0
        #expect(abs(actual - 7200) < 1)
    }

    @Test
    func projectedExhaustionIsNilWhenIdle() {
        let exhaustion = PacingCoach.projectExhaustion(
            usedPercentage: 40,
            currentRatePerHour: 0.1, // below minimumProjectableRate
            now: base
        )
        #expect(exhaustion == nil)
    }

    @Test
    func adviseFlagsOverPace() {
        // 20pp over 30min = 40 pp/h current rate.
        let samples = [
            UsageHistoryStore.Sample(timestamp: base.timeIntervalSince1970, percentage: 20),
            UsageHistoryStore.Sample(timestamp: base.addingTimeInterval(1800).timeIntervalSince1970, percentage: 40),
        ]
        let resets = base.addingTimeInterval(1800 + 4 * 3600) // 4h after the last sample
        let advice = PacingCoach.advise(
            usedPercentage: 40,
            resetsAt: resets,
            samples: samples,
            now: base.addingTimeInterval(1800)
        )
        // Recommended = 60 remaining over 4h = 15 pp/h.
        // Current 40 > recommended 15 * 1.10 → over pace.
        #expect(advice.isOverPace == true)
        #expect(advice.currentRatePerHour != nil)
        #expect(advice.recommendedRatePerHour != nil)
        #expect(advice.projectedExhaustion != nil)
    }

    @Test
    func adviseHandlesMissingData() {
        let advice = PacingCoach.advise(
            usedPercentage: nil,
            resetsAt: nil,
            samples: [],
            now: base
        )
        #expect(advice.currentRatePerHour == nil)
        #expect(advice.recommendedRatePerHour == nil)
        #expect(advice.projectedExhaustion == nil)
        #expect(advice.isOverPace == false)
    }
}
