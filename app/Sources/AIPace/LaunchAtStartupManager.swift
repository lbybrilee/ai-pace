import Foundation
import ServiceManagement

@MainActor
protocol LaunchAtStartupManaging {
    func currentState() -> LaunchAtStartupState
    func setEnabled(_ enabled: Bool) throws -> LaunchAtStartupState
}

@MainActor
struct LaunchAtStartupManager: LaunchAtStartupManaging {
    func currentState() -> LaunchAtStartupState {
        guard isSupported else {
            return .unsupported
        }

        switch SMAppService.mainApp.status {
        case .enabled:
            return .enabled
        case .notRegistered:
            return .disabled
        case .requiresApproval:
            return .requiresApproval
        case .notFound:
            return .unsupported
        @unknown default:
            return .unsupported
        }
    }

    func setEnabled(_ enabled: Bool) throws -> LaunchAtStartupState {
        guard isSupported else {
            return .unsupported
        }

        if enabled {
            try SMAppService.mainApp.register()
        } else {
            try SMAppService.mainApp.unregister()
        }

        return currentState()
    }

    private var isSupported: Bool {
        Bundle.main.bundleURL.pathExtension == "app"
            && Bundle.main.bundleIdentifier != nil
    }
}
