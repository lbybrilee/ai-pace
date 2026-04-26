import Foundation

@MainActor
final class StatusItemRepairDebouncer {
    private let delay: Duration
    private let repair: @MainActor (String) -> Void
    private var task: Task<Void, Never>?

    init(delay: Duration = .milliseconds(500), repair: @escaping @MainActor (String) -> Void) {
        self.delay = delay
        self.repair = repair
    }

    func schedule(reason: String) {
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
