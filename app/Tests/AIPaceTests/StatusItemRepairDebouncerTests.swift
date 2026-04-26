import Foundation
import Testing
@testable import AIPace

@MainActor
struct StatusItemRepairDebouncerTests {
    @Test
    func scheduleRunsRepairAfterDelay() async {
        var reasons: [StatusItemRepairReason] = []
        let debouncer = StatusItemRepairDebouncer(delay: .milliseconds(10)) { reason in
            reasons.append(reason)
        }

        debouncer.schedule(reason: .wake)

        try? await Task.sleep(for: .milliseconds(40))
        #expect(reasons == [.wake])
    }

    @Test
    func scheduleCoalescesRapidRepairsUsingLatestReason() async {
        var reasons: [StatusItemRepairReason] = []
        let debouncer = StatusItemRepairDebouncer(delay: .milliseconds(40)) { reason in
            reasons.append(reason)
        }

        debouncer.schedule(reason: .wake)
        debouncer.schedule(reason: .displayChange)

        try? await Task.sleep(for: .milliseconds(90))
        #expect(reasons == [.displayChange])
    }

    @Test
    func cancelPreventsPendingRepair() async {
        var reasons: [StatusItemRepairReason] = []
        let debouncer = StatusItemRepairDebouncer(delay: .milliseconds(20)) { reason in
            reasons.append(reason)
        }

        debouncer.schedule(reason: .displayChange)
        debouncer.cancel()

        try? await Task.sleep(for: .milliseconds(60))
        #expect(reasons.isEmpty)
    }
}
