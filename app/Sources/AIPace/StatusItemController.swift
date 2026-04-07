import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate, NSPopoverDelegate {
    private let popoverWidth: CGFloat = 440
    private let store: UsageStore
    private let openSettings: @MainActor () -> Void
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var popoverHostingController: NSHostingController<MenuContentView>?
    private var globalClickMonitor: Any?
    private var appDeactivationObserver: NSObjectProtocol?
    private var cancellables = Set<AnyCancellable>()

    init(store: UsageStore, openSettings: @escaping @MainActor () -> Void) {
        self.store = store
        self.openSettings = openSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: 220)
        super.init()
        configureStatusItem()
        configurePopover()
        bindStore()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else {
            return
        }

        button.target = self
        button.action = #selector(handleClick(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.title = ""
        button.image = nil
        button.imagePosition = .imageOnly
        button.imageScaling = .scaleNone

        updateButtonTitle()
    }

    private func configurePopover() {
        popover.behavior = .semitransient
        popover.animates = false
        popover.delegate = self
        let size = popoverSize()
        popover.contentSize = size

        let hostingController = NSHostingController(
            rootView: MenuContentView(store: store, openSettings: openSettings, popoverHeight: size.height)
        )
        hostingController.sizingOptions = []
        hostingController.view.frame = NSRect(origin: .zero, size: size)
        hostingController.preferredContentSize = size

        popoverHostingController = hostingController
        popover.contentViewController = hostingController
    }

    private func bindStore() {
        Publishers.CombineLatest3(store.$claude, store.$codex, store.$copilot)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _, _ in
                self?.updateButtonTitle()
                self?.updatePopoverLayout()
            }
            .store(in: &cancellables)

        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in
                self?.updateButtonTitle()
                self?.updatePopoverLayout()
            }
            .store(in: &cancellables)
    }

    private func updateButtonTitle() {
        guard let button = statusItem.button else {
            return
        }

        let themeID = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.defaultTheme.id
        let theme = AppTheme.resolvedTheme(themeID: themeID)
        let view = statusLabelView(theme: theme)
        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        guard let image = renderer.nsImage else {
            return
        }

        image.isTemplate = false
        button.image = image
        statusItem.length = image.size.width + 12
    }

    private func statusLabelView(theme: AppTheme? = nil) -> StatusItemLabelView {
        let resolvedTheme = theme ?? AppTheme.resolvedTheme(
            themeID: UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.defaultTheme.id
        )
        let displayMode = MenuBarDisplayMode(
            rawValue: UserDefaults.standard.string(forKey: "menuBarDisplayMode") ?? MenuBarDisplayMode.usage.rawValue
        ) ?? .usage
        var pills: [StatusItemPill] = []

        if store.visibleProviders.contains(.claude),
           store.agentStatus(for: .claude).availability.showsInPopover {
            pills.append(StatusItemPill(
                text: StatusItemFormatter.text(prefix: "Cl", snapshot: store.claude, mode: displayMode, perspective: store.usagePerspective),
                color: resolvedTheme.claudeAccent
            ))
        }
        if store.visibleProviders.contains(.codex),
           store.agentStatus(for: .codex).availability.showsInPopover {
            pills.append(StatusItemPill(
                text: StatusItemFormatter.text(prefix: "Cx", snapshot: store.codex, mode: displayMode, perspective: store.usagePerspective),
                color: resolvedTheme.codexAccent
            ))
        }
        if store.visibleProviders.contains(.copilot),
           store.agentStatus(for: .copilot).availability.showsInPopover {
            pills.append(StatusItemPill(
                text: StatusItemFormatter.text(
                    prefix: "Cp",
                    snapshot: store.copilot,
                    mode: store.copilotDisplayMode,
                    perspective: store.usagePerspective,
                    monthlyAllowance: store.copilotMonthlyAllowance
                ),
                color: resolvedTheme.copilotAccent
            ))
        }

        return StatusItemLabelView(pills: pills)
    }

    private func updatePopoverLayout() {
        guard let hostingController = popoverHostingController else {
            return
        }

        let size = popoverSize()
        guard popover.contentSize != size || hostingController.preferredContentSize != size else {
            return
        }

        popover.contentSize = size
        hostingController.preferredContentSize = size
        hostingController.view.setFrameSize(size)
        hostingController.rootView = MenuContentView(
            store: store,
            openSettings: openSettings,
            popoverHeight: size.height
        )
    }

    private func popoverSize() -> NSSize {
        NSSize(width: popoverWidth, height: popoverHeight())
    }

    private func popoverHeight() -> CGFloat {
        Self.popoverHeight(forVisibleSnapshotCount: store.visibleCardCount)
    }

    static func popoverHeight(forVisibleSnapshotCount count: Int) -> CGFloat {
        switch count {
        case 0:
            return 220
        case 1:
            return 250
        case 2:
            return 380
        default:
            return 500
        }
    }

    @objc private func handleClick(_ sender: Any?) {
        switch NSApp.currentEvent?.type {
        case .rightMouseUp:
            showContextMenu()
        default:
            togglePopover()
        }
    }

    private func togglePopover() {
        guard let button = statusItem.button else {
            return
        }

        if popover.isShown {
            closePopover()
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        startPopoverDismissMonitoring()
        Task {
            await store.refreshNotificationAuthorizationState()
        }
    }

    private func showContextMenu() {
        closePopover()

        let menu = NSMenu()
        menu.delegate = self

        let optionsItem = NSMenuItem(title: "Options...", action: #selector(openSettingsFromMenu(_:)), keyEquivalent: "")
        optionsItem.target = self
        menu.addItem(optionsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit AIPace", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
        statusItem.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem.menu = nil
    }

    func popoverDidClose(_ notification: Notification) {
        stopPopoverDismissMonitoring()
    }

    @objc private func openSettingsFromMenu(_ sender: Any?) {
        openSettings()
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }

    private func closePopover() {
        guard popover.isShown else {
            stopPopoverDismissMonitoring()
            return
        }
        popover.performClose(nil)
        stopPopoverDismissMonitoring()
    }

    private func startPopoverDismissMonitoring() {
        if globalClickMonitor == nil {
            globalClickMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.closePopover()
                }
            }
        }

        if appDeactivationObserver == nil {
            appDeactivationObserver = NotificationCenter.default.addObserver(
                forName: NSApplication.didResignActiveNotification,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.closePopover()
                }
            }
        }
    }

    private func stopPopoverDismissMonitoring() {
        if let globalClickMonitor {
            NSEvent.removeMonitor(globalClickMonitor)
            self.globalClickMonitor = nil
        }

        if let appDeactivationObserver {
            NotificationCenter.default.removeObserver(appDeactivationObserver)
            self.appDeactivationObserver = nil
        }
    }
}
