import Foundation
import Testing
@testable import AIPace

@MainActor
struct StatusItemRepairDebouncerTests {
    @Test
    func scheduleRunsRepairAfterDelay() async {
        var reasons: [String] = []
        let debouncer = StatusItemRepairDebouncer(delay: .milliseconds(10)) { reason in
            reasons.append(reason)
        }

        debouncer.schedule(reason: "wake")

        try? await Task.sleep(for: .milliseconds(40))
        #expect(reasons == ["wake"])
    }

    @Test
    func scheduleCoalescesRapidRepairsUsingLatestReason() async {
        var reasons: [String] = []
        let debouncer = StatusItemRepairDebouncer(delay: .milliseconds(40)) { reason in
            reasons.append(reason)
        }

        debouncer.schedule(reason: "wake")
        debouncer.schedule(reason: "display-change")
        debouncer.schedule(reason: "space-change")

        try? await Task.sleep(for: .milliseconds(90))
        #expect(reasons == ["space-change"])
    }
}
