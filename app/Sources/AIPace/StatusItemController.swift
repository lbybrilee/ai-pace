import AppKit
import Combine
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate {
    private let popoverWidth: CGFloat = 440
    private let store: UsageStore
    private let openSettings: @MainActor () -> Void
    private let statusItem: NSStatusItem
    private let popover = NSPopover()
    private var popoverHostingController: NSHostingController<MenuContentView>?
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
        Publishers.CombineLatest(store.$claude, store.$codex)
            .receive(on: RunLoop.main)
            .sink { [weak self] _, _ in
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
        let theme = AppTheme.find(themeID)
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
        let resolvedTheme = theme ?? AppTheme.find(
            UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.defaultTheme.id
        )
        let displayMode = MenuBarDisplayMode(
            rawValue: UserDefaults.standard.string(forKey: "menuBarDisplayMode") ?? MenuBarDisplayMode.usage.rawValue
        ) ?? .usage
        let claudeStatus = store.agentStatus(for: .claude)
        let codexStatus = store.agentStatus(for: .codex)

        return StatusItemLabelView(
            claudeText: claudeStatus.availability.showsInPopover
                ? StatusItemFormatter.text(prefix: "Cl", snapshot: store.claude, mode: displayMode)
                : nil,
            codexText: codexStatus.availability.showsInPopover
                ? StatusItemFormatter.text(prefix: "Cx", snapshot: store.codex, mode: displayMode)
                : nil,
            theme: resolvedTheme
        )
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
        Self.popoverHeight(forVisibleSnapshotCount: store.visibleSnapshots.count)
    }

    static func popoverHeight(forVisibleSnapshotCount count: Int) -> CGFloat {
        switch count {
        case 0:
            return 220
        case 1:
            return 250
        default:
            return 380
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
            popover.performClose(nil)
            return
        }

        NSApp.activate(ignoringOtherApps: true)
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
    }

    private func showContextMenu() {
        popover.performClose(nil)

        let menu = NSMenu()
        menu.delegate = self

        let optionsItem = NSMenuItem(title: "Options...", action: #selector(openSettingsFromMenu(_:)), keyEquivalent: "")
        optionsItem.target = self
        menu.addItem(optionsItem)

        menu.addItem(.separator())

        let quitItem = NSMenuItem(title: "Quit AIPace", action: #selector(quit(_:)), keyEquivalent: "q")
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.popUpMenu(menu)
    }

    func menuDidClose(_ menu: NSMenu) {
    }

    @objc private func openSettingsFromMenu(_ sender: Any?) {
        openSettings()
    }

    @objc private func quit(_ sender: Any?) {
        NSApp.terminate(nil)
    }
}
