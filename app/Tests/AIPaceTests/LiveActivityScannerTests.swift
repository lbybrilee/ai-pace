import Foundation
import Testing
@testable import AIPace

struct LiveActivityScannerTests {
    @Test
    func reportsRecentMtimeAsActive() throws {
        let dir = try TempDir()
        defer { try? dir.cleanup() }

        let now = Date()
        try dir.touch(name: "session.jsonl", at: now.addingTimeInterval(-5))
        let snap = LiveActivityScanner.snapshot(directories: [dir.url], now: now)
        #expect(snap.isActive == true)
        #expect(snap.lastActivity != nil)
    }

    @Test
    func staleMtimeIsInactive() throws {
        let dir = try TempDir()
        defer { try? dir.cleanup() }

        let now = Date()
        try dir.touch(name: "session.jsonl", at: now.addingTimeInterval(-LiveActivityScanner.activeWindow - 60))
        let snap = LiveActivityScanner.snapshot(directories: [dir.url], now: now)
        #expect(snap.isActive == false)
        #expect(snap.lastActivity != nil)
    }

    @Test
    func emptyDirectoryIsIdle() throws {
        let dir = try TempDir()
        defer { try? dir.cleanup() }
        let snap = LiveActivityScanner.snapshot(directories: [dir.url])
        #expect(snap == .idle)
    }

    @Test
    func missingDirectoryIsIdle() {
        let bogus = URL(fileURLWithPath: "/var/empty/aipace-missing-\(UUID().uuidString)")
        let snap = LiveActivityScanner.snapshot(directories: [bogus])
        #expect(snap == .idle)
    }

    @Test
    func picksNewestAcrossMultipleDirectories() throws {
        let a = try TempDir()
        let b = try TempDir()
        defer {
            try? a.cleanup()
            try? b.cleanup()
        }

        let now = Date()
        try a.touch(name: "old.jsonl", at: now.addingTimeInterval(-300))
        try b.touch(name: "fresh.jsonl", at: now.addingTimeInterval(-2))

        let snap = LiveActivityScanner.snapshot(directories: [a.url, b.url], now: now)
        #expect(snap.isActive == true)
        let last = try #require(snap.lastActivity)
        #expect(now.timeIntervalSince(last) < 30)
    }

    @Test
    func recursesIntoSubdirectories() throws {
        let dir = try TempDir()
        defer { try? dir.cleanup() }

        let nested = dir.url.appendingPathComponent("sub-a/sub-b", isDirectory: true)
        try FileManager.default.createDirectory(at: nested, withIntermediateDirectories: true)
        let file = nested.appendingPathComponent("session.jsonl")
        FileManager.default.createFile(atPath: file.path, contents: Data("{}".utf8))
        try FileManager.default.setAttributes([.modificationDate: Date()], ofItemAtPath: file.path)

        let snap = LiveActivityScanner.snapshot(directories: [dir.url])
        #expect(snap.isActive == true)
    }
}

private struct TempDir {
    let url: URL

    init() throws {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("aipace-live-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    }

    func touch(name: String, at date: Date) throws {
        let fileURL = url.appendingPathComponent(name)
        FileManager.default.createFile(atPath: fileURL.path, contents: Data("{}".utf8))
        try FileManager.default.setAttributes([.modificationDate: date], ofItemAtPath: fileURL.path)
    }

    func cleanup() throws {
        try FileManager.default.removeItem(at: url)
    }
}
