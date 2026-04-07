import Foundation
import Testing
@testable import AIPace

struct CodexProbeTests {
    @Test
    func numericValueParsesCommonJSONRepresentations() {
        let probe = CodexProbe()

        #expect(probe.numericValue(12) == 12)
        #expect(probe.numericValue("12.5") == 12.5)
        #expect(probe.numericValue(NSNumber(value: 7.25)) == 7.25)
        #expect(probe.numericValue("nope") == nil)
    }

    @Test
    func parseWindowRequiresUsedPercentAndParsesResetTimestamp() {
        let probe = CodexProbe()
        let window = probe.parseWindow([
            "usedPercent": "62.5",
            "resetsAt": 1_710_000_000,
            "windowDurationMins": 240,
        ])

        #expect(window?.usedPercent == 62.5)
        #expect(window?.resetsAt == Date(timeIntervalSince1970: 1_710_000_000))
        #expect(window?.windowDurationMins == 240)
        #expect(probe.parseWindow(["resetsAt": 1_710_000_000]) == nil)
    }

    @Test
    func preferredRateLimitSnapshotPrefersCodexBucket() {
        let probe = CodexProbe()
        let result: [String: Any] = [
            "rateLimits": ["planType": "plus"],
            "rateLimitsByLimitId": [
                "other": ["planType": "go"],
                "codex": ["planType": "pro"],
            ],
        ]

        let snapshot = probe.preferredRateLimitSnapshot(from: result)

        #expect(snapshot?["planType"] as? String == "pro")
    }

    @Test
    func detailTextUsesActualWindowDurations() {
        let probe = CodexProbe()
        let shortWindow = CodexRateLimitWindow(usedPercent: 12, resetsAt: nil, windowDurationMins: 240)
        let longWindow = CodexRateLimitWindow(usedPercent: 48, resetsAt: nil, windowDurationMins: 10_080)

        #expect(
            probe.detailText(planType: "pro", shortWindow: shortWindow, longWindow: longWindow) == "Plan: pro · 4h / 7d"
        )
    }

    @Test
    func readResponseReturnsMatchingPayload() async throws {
        let stream = AsyncStream<String> { continuation in
            continuation.yield("{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"ignored\":true}}")
            continuation.yield("not json")
            continuation.yield("{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{\"rateLimits\":{}}}")
            continuation.finish()
        }

        let payload = try await readResponse(withID: 2, from: stream)

        #expect(payload["id"] as? Int == 2)
        #expect((payload["result"] as? [String: Any]) != nil)
    }

    @Test
    func readResponseThrowsMatchingServerError() async {
        let stream = AsyncStream<String> { continuation in
            continuation.yield("{\"jsonrpc\":\"2.0\",\"id\":2,\"error\":{\"message\":\"No session\"}}")
            continuation.finish()
        }

        do {
            _ = try await readResponse(withID: 2, from: stream)
            Issue.record("Expected invalid response error")
        } catch let error as ProcessRunnerError {
            guard case .invalidResponse(let message) = error else {
                Issue.record("Unexpected error type: \(error)")
                return
            }
            #expect(message == "No session")
        } catch {
            Issue.record("Unexpected error: \(error)")
        }
    }
}
