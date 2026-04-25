import Foundation
import Observation

/// "Is something burning tokens right now?" — backed by file-mtime polling
/// against the per-provider session log directories.
struct LiveActivitySnapshot: Equatable, Sendable {
    let lastActivity: Date?
    let isActive: Bool

    static let idle = LiveActivitySnapshot(lastActivity: nil, isActive: false)
}

/// Pure file-system scan used by `LiveActivityMonitor`. Exposed for tests.
enum LiveActivityScanner {
    /// How far back from `now` we treat a session log mtime as "live activity".
    static let activeWindow: TimeInterval = 45

    static func snapshot(
        directories: [URL],
        now: Date = .now,
        fileManager: FileManager = .default
    ) -> LiveActivitySnapshot {
        var latest: Date?
        for directory in directories {
            guard let mtime = mostRecentMtime(in: directory, fileManager: fileManager) else { continue }
            if (latest ?? .distantPast) < mtime {
                latest = mtime
            }
        }
        guard let latest else { return .idle }
        let isActive = now.timeIntervalSince(latest) <= activeWindow
        return LiveActivitySnapshot(lastActivity: latest, isActive: isActive)
    }

    /// Walks `directory` and returns the newest file modification date found.
    /// Excludes directory mtimes to avoid spurious activity from housekeeping.
    static func mostRecentMtime(in directory: URL, fileManager: FileManager = .default) -> Date? {
        guard fileManager.fileExists(atPath: directory.path) else { return nil }
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.contentModificationDateKey, .isRegularFileKey],
            options: [.skipsHiddenFiles, .skipsPackageDescendants]
        ) else { return nil }

        var newest: Date?
        for case let url as URL in enumerator {
            let values = try? url.resourceValues(forKeys: [.contentModificationDateKey, .isRegularFileKey])
            guard values?.isRegularFile == true else { continue }
            guard let mtime = values?.contentModificationDate else { continue }
            if (newest ?? .distantPast) < mtime {
                newest = mtime
            }
        }
        return newest
    }
}

/// Polling-based live activity tracker. Cheap because we only stat files; we
/// avoid FSEvents to keep this dependency-free and behaviour predictable
/// across Swift Package builds.
@MainActor
@Observable
final class LiveActivityMonitor {
    var claude: LiveActivitySnapshot = .idle
    var codex: LiveActivitySnapshot = .idle

    @ObservationIgnored private let claudeDirectories: [URL]
    @ObservationIgnored private let codexDirectories: [URL]
    @ObservationIgnored private let pollInterval: TimeInterval
    @ObservationIgnored private var pollTask: Task<Void, Never>?

    init(
        claudeDirectories: [URL] = LiveActivityMonitor.defaultClaudeDirectories,
        codexDirectories: [URL] = LiveActivityMonitor.defaultCodexDirectories,
        pollInterval: TimeInterval = 5,
        autoStart: Bool = true
    ) {
        self.claudeDirectories = claudeDirectories
        self.codexDirectories = codexDirectories
        self.pollInterval = pollInterval
        if autoStart {
            start()
        }
    }

    deinit {
        pollTask?.cancel()
    }

    func start() {
        pollTask?.cancel()
        let claudeDirs = claudeDirectories
        let codexDirs = codexDirectories
        let interval = pollInterval
        pollTask = Task { [weak self] in
            // First scan happens immediately so the UI doesn't flicker on launch.
            await self?.refresh(claudeDirs: claudeDirs, codexDirs: codexDirs)
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(interval))
                guard !Task.isCancelled else { break }
                await self?.refresh(claudeDirs: claudeDirs, codexDirs: codexDirs)
            }
        }
    }

    func stop() {
        pollTask?.cancel()
        pollTask = nil
    }

    private func refresh(claudeDirs: [URL], codexDirs: [URL]) async {
        let claudeSnap = await Task.detached(priority: .utility) {
            LiveActivityScanner.snapshot(directories: claudeDirs)
        }.value
        let codexSnap = await Task.detached(priority: .utility) {
            LiveActivityScanner.snapshot(directories: codexDirs)
        }.value
        if claude != claudeSnap { claude = claudeSnap }
        if codex != codexSnap { codex = codexSnap }
    }

    static let defaultClaudeDirectories: [URL] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [home.appendingPathComponent(".claude/projects", isDirectory: true)]
    }()

    static let defaultCodexDirectories: [URL] = {
        let home = FileManager.default.homeDirectoryForCurrentUser
        return [home.appendingPathComponent(".codex/sessions", isDirectory: true)]
    }()
}
