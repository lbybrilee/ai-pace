import AppKit
import SwiftUI

@MainActor
final class OptionsWindowController: NSWindowController {
    private let windowWidth: CGFloat = 520
    private let preferredWindowHeight: CGFloat = 640
    private let minimumWindowHeight: CGFloat = 460
    private let store: UsageStore

    init(store: UsageStore) {
        self.store = store
        let contentView = ScrollView {
            SettingsView(store: store)
        }
        let hostingController = NSHostingController(rootView: contentView)

        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: windowWidth, height: preferredWindowHeight),
            styleMask: [.titled, .closable, .miniaturizable],
            backing: .buffered,
            defer: false
        )
        window.title = "Options"
        window.contentViewController = hostingController
        window.center()
        window.minSize = NSSize(width: windowWidth, height: minimumWindowHeight)
        window.isReleasedWhenClosed = false

        super.init(window: window)
        shouldCascadeWindows = false
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func show() {
        guard let window else {
            return
        }

        let targetHeight = resolvedWindowHeight()
        window.setContentSize(NSSize(width: windowWidth, height: targetHeight))

        if !window.isVisible {
            window.center()
        }

        showWindow(nil)
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        Task {
            await store.refreshNotificationAuthorizationState()
        }
    }

    private func resolvedWindowHeight() -> CGFloat {
        guard let visibleFrame = NSScreen.main?.visibleFrame else {
            return preferredWindowHeight
        }

        let maxHeight = max(minimumWindowHeight, visibleFrame.height - 120)
        return min(preferredWindowHeight, maxHeight)
    }
}
