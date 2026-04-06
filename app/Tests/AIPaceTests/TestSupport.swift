import Foundation
@testable import AIPace

func makeWindow(
    _ kind: UsageWindowKind,
    used: Double? = nil,
    resetsAt: Date? = nil,
    message: String? = nil
) -> UsageWindow {
    UsageWindow(kind: kind, usedPercentage: used, resetsAt: resetsAt, message: message)
}

func makeSnapshot(
    _ provider: ProviderKind,
    fiveHourUsed: Double? = nil,
    weeklyUsed: Double? = nil,
    fiveHourReset: Date? = nil,
    weeklyReset: Date? = nil,
    fiveHourMessage: String? = nil,
    weeklyMessage: String? = nil,
    detail: String? = nil
) -> ProviderSnapshot {
    ProviderSnapshot(
        provider: provider,
        fiveHour: makeWindow(.fiveHour, used: fiveHourUsed, resetsAt: fiveHourReset, message: fiveHourMessage),
        weekly: makeWindow(.weekly, used: weeklyUsed, resetsAt: weeklyReset, message: weeklyMessage),
        detail: detail
    )
}

func makeTemporaryDirectory() throws -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
    return url
}

actor ProbeQueue {
    private var snapshots: [ProviderSnapshot]

    init(_ snapshots: [ProviderSnapshot]) {
        precondition(!snapshots.isEmpty, "ProbeQueue requires at least one snapshot")
        self.snapshots = snapshots
    }

    func next() -> ProviderSnapshot {
        if snapshots.count == 1 {
            return snapshots[0]
        }
        return snapshots.removeFirst()
    }
}

actor ProbeCounter {
    private var count = 0

    func increment() {
        count += 1
    }

    func value() -> Int {
        count
    }
}

struct ProbeStub: ProviderSnapshotFetching {
    let queue: ProbeQueue

    func fetch() async -> ProviderSnapshot {
        await queue.next()
    }
}

struct CountingProbe: ProviderSnapshotFetching {
    let snapshot: ProviderSnapshot
    let counter: ProbeCounter

    func fetch() async -> ProviderSnapshot {
        await counter.increment()
        return snapshot
    }
}

func waitUntil(
    maxAttempts: Int = 100,
    pollInterval: Duration = .milliseconds(10),
    condition: @escaping @Sendable () async -> Bool
) async -> Bool {
    for _ in 0..<maxAttempts {
        if await condition() {
            return true
        }
        try? await Task.sleep(for: pollInterval)
    }
    return await condition()
}

@MainActor
final class NotificationManagerSpy: NotificationManaging {
    var authorizationGranted = true
    var systemNotificationsDisabled = false
    private(set) var authorizationRequests = 0
    private(set) var sentKeys: [UsageWindowKey] = []
    private(set) var sentSounds: [NotificationSoundOption] = []
    private(set) var previewedSounds: [NotificationSoundOption] = []

    func notificationsDisabledInSystem() async -> Bool {
        systemNotificationsDisabled
    }

    func requestAuthorizationIfNeeded() async -> Bool {
        authorizationRequests += 1
        return authorizationGranted
    }

    func sendRefreshNotification(for key: UsageWindowKey, sound: NotificationSoundOption) async {
        sentKeys.append(key)
        sentSounds.append(sound)
    }

    func preview(sound: NotificationSoundOption) {
        previewedSounds.append(sound)
    }
}

@MainActor
final class LaunchAtStartupManagerSpy: LaunchAtStartupManaging {
    var state: LaunchAtStartupState = .disabled
    var failure: Error?
    private(set) var setCalls: [Bool] = []

    func currentState() -> LaunchAtStartupState {
        state
    }

    func setEnabled(_ enabled: Bool) throws -> LaunchAtStartupState {
        setCalls.append(enabled)
        if let failure {
            throw failure
        }
        state = enabled ? .enabled : .disabled
        return state
    }
}
