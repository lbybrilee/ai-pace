import Foundation
import Testing
@testable import AIPace

struct ClaudeSessionScannerTests {
    @Test
    func aggregatesTokensByCwdWithinCutoff() throws {
        let env = try TempProjectsDirectory()
        defer { try? env.cleanup() }

        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let cutoff = now.addingTimeInterval(-5 * 3600)
        let recent = now.addingTimeInterval(-30 * 60)
        let stale = now.addingTimeInterval(-6 * 3600)

        try env.writeSession(name: "session-a.jsonl", lines: [
            assistantLine(timestamp: recent, cwd: "/Users/me/proj-a", input: 100, output: 50),
            assistantLine(timestamp: recent, cwd: "/Users/me/proj-a", input: 200, output: 100),
            assistantLine(timestamp: stale, cwd: "/Users/me/proj-a", input: 9999, output: 9999), // ignored
        ])

        try env.writeSession(name: "session-b.jsonl", lines: [
            assistantLine(timestamp: recent, cwd: "/Users/me/proj-b", input: 50, output: 50),
        ])

        let projects = ClaudeSessionScanner.scanSync(
            projectsDirectory: env.url,
            since: cutoff,
            limit: 5
        )

        #expect(projects.count == 2)
        let projA = try #require(projects.first { $0.path == "/Users/me/proj-a" })
        #expect(projA.totalTokens == 450)
        #expect(projA.messageCount == 2)
        #expect(projA.displayName == "proj-a")

        let projB = try #require(projects.first { $0.path == "/Users/me/proj-b" })
        #expect(projB.totalTokens == 100)

        // Sorted by tokens descending.
        #expect(projects.first?.path == "/Users/me/proj-a")
    }

    @Test
    func skipsNonAssistantAndMalformedLines() throws {
        let env = try TempProjectsDirectory()
        defer { try? env.cleanup() }

        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let recent = now.addingTimeInterval(-10 * 60)

        try env.writeSession(name: "mixed.jsonl", lines: [
            "{not valid json",
            #"{"type":"user","timestamp":"2026-04-25T00:00:00.000Z","cwd":"/Users/me/proj-x"}"#,
            assistantLine(timestamp: recent, cwd: "/Users/me/proj-x", input: 10, output: 5),
            #"{"type":"assistant","cwd":"/Users/me/proj-y","message":{}}"#, // missing usage
        ])

        let projects = ClaudeSessionScanner.scanSync(
            projectsDirectory: env.url,
            since: now.addingTimeInterval(-3600),
            limit: 5
        )

        #expect(projects.count == 1)
        #expect(projects.first?.path == "/Users/me/proj-x")
        #expect(projects.first?.totalTokens == 15)
    }

    @Test
    func returnsEmptyWhenNoSessionsInsideCutoff() throws {
        let env = try TempProjectsDirectory()
        defer { try? env.cleanup() }

        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let veryOld = now.addingTimeInterval(-7 * 24 * 3600)

        try env.writeSession(name: "old.jsonl", lines: [
            assistantLine(timestamp: veryOld, cwd: "/Users/me/proj-old", input: 100, output: 100),
        ])
        // Backdate the file mtime so the file-level fast-path skip kicks in.
        try env.setMtime(of: "old.jsonl", to: veryOld)

        let projects = ClaudeSessionScanner.scanSync(
            projectsDirectory: env.url,
            since: now.addingTimeInterval(-3600),
            limit: 5
        )
        #expect(projects.isEmpty)
    }

    @Test
    func handlesMissingProjectsDirectoryGracefully() {
        let bogus = URL(fileURLWithPath: "/var/empty/nonexistent-aipace-test-\(UUID().uuidString)")
        let projects = ClaudeSessionScanner.scanSync(
            projectsDirectory: bogus,
            since: Date(),
            limit: 5
        )
        #expect(projects.isEmpty)
    }

    @Test
    func limitsResultsAndKeepsHighestByTokens() throws {
        let env = try TempProjectsDirectory()
        defer { try? env.cleanup() }

        let now = Date(timeIntervalSince1970: 1_750_000_000)
        let recent = now.addingTimeInterval(-30 * 60)

        var lines: [String] = []
        for i in 1...4 {
            lines.append(assistantLine(timestamp: recent, cwd: "/Users/me/p\(i)", input: i * 10, output: i * 10))
        }
        try env.writeSession(name: "all.jsonl", lines: lines)

        let projects = ClaudeSessionScanner.scanSync(
            projectsDirectory: env.url,
            since: now.addingTimeInterval(-3600),
            limit: 2
        )
        #expect(projects.count == 2)
        #expect(projects[0].path == "/Users/me/p4")
        #expect(projects[1].path == "/Users/me/p3")
    }

    // MARK: - Helpers

    private func assistantLine(timestamp: Date, cwd: String, input: Int, output: Int) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        let ts = formatter.string(from: timestamp)
        return #"""
        {"type":"assistant","timestamp":"\#(ts)","cwd":"\#(cwd)","message":{"usage":{"input_tokens":\#(input),"output_tokens":\#(output)}}}
        """#
    }
}

private struct TempProjectsDirectory {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("ai-pace-tests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func writeSession(name: String, lines: [String]) throws {
        let projectDir = url.appendingPathComponent("project-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: projectDir, withIntermediateDirectories: true)
        let fileURL = projectDir.appendingPathComponent(name)
        try lines.joined(separator: "\n").write(to: fileURL, atomically: true, encoding: .utf8)
    }

    func setMtime(of name: String, to date: Date) throws {
        let enumerator = FileManager.default.enumerator(at: url, includingPropertiesForKeys: nil)
        guard let enumerator else { return }
        for case let candidate as URL in enumerator where candidate.lastPathComponent == name {
            try FileManager.default.setAttributes(
                [.modificationDate: date],
                ofItemAtPath: candidate.path
            )
        }
    }

    func cleanup() throws {
        try FileManager.default.removeItem(at: url)
    }
}
