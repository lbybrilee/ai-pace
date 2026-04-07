import AppKit
import SwiftUI

@main
@MainActor
struct AIPaceApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store: UsageStore

    init() {
        _store = StateObject(wrappedValue: UsageStore())
    }

    var body: some Scene {
        let _ = appDelegate.configureIfNeeded(store: store)

        Settings {
            EmptyView()
        }
    }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItemController: StatusItemController?
    private var optionsWindowController: OptionsWindowController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
    }

    func configureIfNeeded(store: UsageStore) {
        guard statusItemController == nil else {
            return
        }
        let openSettings: @MainActor @Sendable () -> Void = { [weak self] in
            guard let self else {
                return
            }
            self.showOptionsWindow(with: store)
        }
        statusItemController = StatusItemController(store: store, openSettings: openSettings)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    private func showOptionsWindow(with store: UsageStore) {
        if optionsWindowController == nil {
            optionsWindowController = OptionsWindowController(store: store)
        }
        optionsWindowController?.show()
    }
}
