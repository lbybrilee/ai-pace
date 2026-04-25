import Foundation

/// Aggregated token usage for a single project, derived from Claude Code
/// session logs. Used to power the "top projects" attribution panel.
struct ProjectAttribution: Sendable, Equatable, Identifiable {
    let path: String
    let displayName: String
    let totalTokens: Int
    let messageCount: Int
    let lastActivity: Date

    var id: String { path }
}

/// Scans `~/.claude/projects/*/<sessionId>.jsonl` for assistant messages
/// timestamped within a recency window and aggregates tokens per project.
///
/// The format is one JSON object per line. We only care about lines where
/// `type == "assistant"` — they carry the `message.usage` object with
/// `input_tokens` and `output_tokens`, plus a `cwd` we use as the project key.
enum ClaudeSessionScanner {
    static let defaultProjectsDirectory: URL = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return home.appendingPathComponent(".claude/projects", isDirectory: true)
    }()

    /// Scan all session files within `projectsDirectory` and return the top
    /// projects (by token count) with activity since `cutoff`. Returns at
    /// most `limit` entries. File I/O happens on a background task.
    static func scanRecentActivity(
        projectsDirectory: URL = defaultProjectsDirectory,
        since cutoff: Date,
        limit: Int = 5
    ) async -> [ProjectAttribution] {
        await Task.detached(priority: .utility) {
            scanSync(
                projectsDirectory: projectsDirectory,
                since: cutoff,
                limit: limit
            )
        }.value
    }

    /// Synchronous scanner exposed for tests. The async wrapper above is
    /// what production code should use.
    static func scanSync(
        projectsDirectory: URL,
        since cutoff: Date,
        limit: Int,
        fileManager: FileManager = .default
    ) -> [ProjectAttribution] {
        guard fileManager.fileExists(atPath: projectsDirectory.path) else { return [] }
        let resourceKeys: [URLResourceKey] = [.contentModificationDateKey, .isDirectoryKey]
        guard let enumerator = fileManager.enumerator(
            at: projectsDirectory,
            includingPropertiesForKeys: resourceKeys,
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return [] }

        var totalsByPath: [String: Int] = [:]
        var messageCountsByPath: [String: Int] = [:]
        var lastActivityByPath: [String: Date] = [:]
        var displayNameByPath: [String: String] = [:]

        // Reuse one formatter per scan; ISO8601DateFormatter isn't Sendable so
        // we don't share it across scans.
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]

        for case let url as URL in enumerator {
            guard url.pathExtension == "jsonl" else { continue }
            guard let modified = (try? url.resourceValues(forKeys: [.contentModificationDateKey]))?
                .contentModificationDate else { continue }
            // Skip files that haven't been touched since the cutoff at all.
            if modified < cutoff { continue }

            scanFile(
                at: url,
                since: cutoff,
                formatter: formatter,
                totals: &totalsByPath,
                messageCounts: &messageCountsByPath,
                lastActivity: &lastActivityByPath,
                displayNames: &displayNameByPath
            )
        }

        let projects = totalsByPath.compactMap { (path, tokens) -> ProjectAttribution? in
            guard tokens > 0 else { return nil }
            let display = displayNameByPath[path] ?? URL(fileURLWithPath: path).lastPathComponent
            return ProjectAttribution(
                path: path,
                displayName: display,
                totalTokens: tokens,
                messageCount: messageCountsByPath[path] ?? 0,
                lastActivity: lastActivityByPath[path] ?? Date.distantPast
            )
        }

        return projects
            .sorted { $0.totalTokens > $1.totalTokens }
            .prefix(limit)
            .map { $0 }
    }

    private static func scanFile(
        at url: URL,
        since cutoff: Date,
        formatter: ISO8601DateFormatter,
        totals: inout [String: Int],
        messageCounts: inout [String: Int],
        lastActivity: inout [String: Date],
        displayNames: inout [String: String]
    ) {
        guard let data = try? Data(contentsOf: url) else { return }
        guard let text = String(data: data, encoding: .utf8) else { return }

        let decoder = JSONDecoder()
        for rawLine in text.split(separator: "\n", omittingEmptySubsequences: true) {
            guard let lineData = String(rawLine).data(using: .utf8) else { continue }
            guard let entry = try? decoder.decode(SessionEntry.self, from: lineData) else { continue }
            guard entry.type == "assistant",
                  let cwd = entry.cwd, !cwd.isEmpty,
                  let timestampString = entry.timestamp,
                  let timestamp = formatter.date(from: timestampString)
            else { continue }
            guard timestamp >= cutoff else { continue }
            guard let usage = entry.message?.usage else { continue }

            let tokens = (usage.input_tokens ?? 0) + (usage.output_tokens ?? 0)
            guard tokens > 0 else { continue }

            totals[cwd, default: 0] += tokens
            messageCounts[cwd, default: 0] += 1
            if (lastActivity[cwd] ?? .distantPast) < timestamp {
                lastActivity[cwd] = timestamp
            }
            if displayNames[cwd] == nil {
                displayNames[cwd] = URL(fileURLWithPath: cwd).lastPathComponent
            }
        }
    }
}

private struct SessionEntry: Decodable {
    let type: String?
    let timestamp: String?
    let cwd: String?
    let message: SessionMessage?
}

private struct SessionMessage: Decodable {
    let usage: SessionUsage?
}

private struct SessionUsage: Decodable {
    let input_tokens: Int?
    let output_tokens: Int?
}

