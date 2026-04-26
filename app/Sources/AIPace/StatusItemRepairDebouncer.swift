import Foundation

enum StatusItemRepairReason: String {
    case launch
    case wake
    case wakeFollowup = "wake-followup"
    case displayChange = "display-change"
}

@MainActor
final class StatusItemRepairDebouncer {
    private let delay: Duration
    private let repair: @MainActor (StatusItemRepairReason) -> Void
    private var task: Task<Void, Never>?

    init(delay: Duration = .milliseconds(500), repair: @escaping @MainActor (StatusItemRepairReason) -> Void) {
        self.delay = delay
        self.repair = repair
    }

    deinit {
        task?.cancel()
    }

    func schedule(reason: StatusItemRepairReason) {
        task?.cancel()
        task = Task { @MainActor [delay, repair] in
            do {
                try await Task.sleep(for: delay)
            } catch {
                return
            }

            guard !Task.isCancelled else {
                return
            }

            repair(reason)
        }
    }

    func cancel() {
        task?.cancel()
        task = nil
    }
}
