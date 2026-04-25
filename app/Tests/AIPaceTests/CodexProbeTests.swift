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
        ])

        #expect(window?.usedPercent == 62.5)
        #expect(window?.resetsAt == Date(timeIntervalSince1970: 1_710_000_000))
        #expect(probe.parseWindow(["resetsAt": 1_710_000_000]) == nil)
    }

    @Test
    func readResponseReturnsMatchingPayload() async throws {
        let stream = AsyncStream<String> { continuation in
            continuation.yield("{\"jsonrpc\":\"2.0\",\"id\":1,\"result\":{\"ignored\":true}}")
            continuation.yield("not json")
            continuation.yield("{\"jsonrpc\":\"2.0\",\"id\":2,\"result\":{\"rateLimits\":{}}}")
            continuation.finish()
        }

        let payload = try await CodexJSONRPC.readResponse(withID: 2, from: stream)

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
            _ = try await CodexJSONRPC.readResponse(withID: 2, from: stream)
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
