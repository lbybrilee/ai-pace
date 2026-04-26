@preconcurrency import AppKit
import Combine
import OSLog
import SwiftUI

@MainActor
final class StatusItemController: NSObject, NSMenuDelegate, NSPopoverDelegate {
    private let popoverWidth: CGFloat = 440
    private static let statusItemLengthPadding: CGFloat = 12
    private static let minimumStatusItemLength: CGFloat = 32

    private let store: UsageStore
    private let openSettings: @MainActor () -> Void
    private var statusItem: NSStatusItem?
    private let popover = NSPopover()
    private let logger = Logger(subsystem: "com.aipace.app", category: "StatusItem")
    private var popoverHostingController: NSHostingController<MenuContentView>?
    private var globalClickMonitor: Any?
    private var appDeactivationObserver: NSObjectProtocol?
    private var lifecycleObservers: [(center: NotificationCenter, token: NSObjectProtocol)] = []
    private var cancellables = Set<AnyCancellable>()
    private var wakeFollowupTask: Task<Void, Never>?
    private var rebuildCount = 0
    private var statusItemCreatedAt: Date?
    private var isInRendererFallback = false
    private var isUsingFallbackLabel = false
    private lazy var repairDebouncer = StatusItemRepairDebouncer { [weak self] reason in
        self?.rebuildStatusItem(reason: reason)
    }

    init(store: UsageStore, openSettings: @escaping @MainActor () -> Void) {
        self.store = store
        self.openSettings = openSettings
        super.init()
        createStatusItem(reason: .launch)
        configurePopover()
        bindStore()
        registerLifecycleRepairTriggers()
    }

    deinit {
        wakeFollowupTask?.cancel()
        lifecycleObservers.forEach { observer in
            observer.center.removeObserver(observer.token)
        }
    }

    private func createStatusItem(reason: StatusItemRepairReason) {
        logger.info("Creating status item: \(reason.rawValue, privacy: .public)")
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItemCreatedAt = Date()
        configureStatusItem(reason: reason)
    }

    private func removeStatusItem(reason: StatusItemRepairReason) {
        guard let statusItem else {
            return
        }

        logger.info("Removing status item: \(reason.rawValue, privacy: .public)")
        statusItem.menu = nil
        NSStatusBar.system.removeStatusItem(statusItem)
        self.statusItem = nil
        statusItemCreatedAt = nil
    }

    private func rebuildStatusItem(reason: StatusItemRepairReason) {
        rebuildCount += 1
        let priorAge = statusItemCreatedAt.map { Date().timeIntervalSince($0) } ?? 0
        logger.info(
            "Rebuilding status item (#\(self.rebuildCount), prior age \(priorAge, format: .fixed(precision: 1))s): \(reason.rawValue, privacy: .public)"
        )
        closePopover()
        removeStatusItem(reason: reason)
        createStatusItem(reason: reason)
        logPostRebuildState(reason: reason)
    }

    private func configureStatusItem(reason: StatusItemRepairReason) {
        guard let button = statusItem?.button else {
            logger.error("Status item configuration skipped because the button is unavailable: \(reason.rawValue, privacy: .public)")
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

    private func registerLifecycleRepairTriggers() {
        let workspaceCenter = NSWorkspace.shared.notificationCenter
        let wakeObserver = workspaceCenter.addObserver(
            forName: NSWorkspace.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleStatusItemRepair(reason: .wake)
                self?.scheduleSecondWakeRepair()
            }
        }
        lifecycleObservers.append((workspaceCenter, wakeObserver))

        let displayObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.scheduleStatusItemRepair(reason: .displayChange)
            }
        }
        lifecycleObservers.append((NotificationCenter.default, displayObserver))
    }

    private func scheduleStatusItemRepair(reason: StatusItemRepairReason) {
        logger.info("Scheduling status item repair: \(reason.rawValue, privacy: .public)")
        repairDebouncer.schedule(reason: reason)
    }

    private func scheduleSecondWakeRepair() {
        wakeFollowupTask?.cancel()
        wakeFollowupTask = Task { @MainActor [weak self] in
            try? await Task.sleep(for: .seconds(2))
            guard !Task.isCancelled else {
                return
            }
            self?.rebuildStatusItem(reason: .wakeFollowup)
        }
    }

    private func logPostRebuildState(reason: StatusItemRepairReason) {
        let button = statusItem?.button
        let buttonPresent = button != nil
        let hasWindow = button?.window != nil
        let length = statusItem?.length ?? 0
        let usesFallback = isInRendererFallback || isUsingFallbackLabel
        logger.info(
            "Status item rebuild result: reason=\(reason.rawValue, privacy: .public) button=\(buttonPresent) window=\(hasWindow) length=\(length, format: .fixed(precision: 1)) fallback=\(usesFallback)"
        )
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
        guard let button = statusItem?.button else {
            logger.error("Status item update skipped because the button is unavailable")
            return
        }

        let themeID = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.defaultTheme.id
        let theme = AppTheme.resolvedTheme(themeID: themeID)
        let view = statusLabelView(theme: theme)
        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        guard let image = renderer.nsImage else {
            if !isInRendererFallback {
                logger.error("Status item renderer failed; applying text fallback")
            }
            applyTextFallback(to: button)
            return
        }

        if isInRendererFallback {
            logger.info("Status item renderer recovered")
            isInRendererFallback = false
        }

        image.isTemplate = false
        button.title = ""
        button.imagePosition = .imageOnly
        button.image = image
        statusItem?.length = Self.statusItemLength(forContentWidth: image.size.width)
    }

    private func statusLabelView(theme: AppTheme? = nil) -> StatusItemLabelView {
        let resolvedTheme = theme ?? AppTheme.resolvedTheme(
            themeID: UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.defaultTheme.id
        )
        let displayMode = MenuBarDisplayMode(
            rawValue: UserDefaults.standard.string(forKey: "menuBarDisplayMode") ?? MenuBarDisplayMode.usage.rawValue
        ) ?? .usage
        let claudeStatus = store.agentStatus(for: .claude)
        let codexStatus = store.agentStatus(for: .codex)
        let claudeName = ProviderDisplayName.displayName(for: .claude)
        let codexName = ProviderDisplayName.displayName(for: .codex)
        let claudeText = claudeStatus.availability.showsInPopover
            ? StatusItemFormatter.text(prefix: claudeName, snapshot: store.claude, mode: displayMode)
            : nil
        let codexText = codexStatus.availability.showsInPopover
            ? StatusItemFormatter.text(prefix: codexName, snapshot: store.codex, mode: displayMode)
            : nil

        let usesFallbackLabel = StatusItemLabelView.resolvedFallbackText(claudeText: claudeText, codexText: codexText) != nil
        if usesFallbackLabel, !isUsingFallbackLabel {
            logger.info("Using fallback status item label")
        }
        isUsingFallbackLabel = usesFallbackLabel

        return StatusItemLabelView(
            claudeText: claudeText,
            codexText: codexText,
            theme: resolvedTheme
        )
    }

    private func applyTextFallback(to button: NSStatusBarButton) {
        isInRendererFallback = true
        button.image = nil
        button.imagePosition = .noImage
        button.title = StatusItemLabelView.defaultFallbackText
        statusItem?.length = NSStatusItem.variableLength
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

    static func statusItemLength(forContentWidth width: CGFloat) -> CGFloat {
        max(width + statusItemLengthPadding, minimumStatusItemLength)
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
        guard let button = statusItem?.button else {
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

        statusItem?.menu = menu
        statusItem?.button?.performClick(nil)
    }

    func menuDidClose(_ menu: NSMenu) {
        statusItem?.menu = nil
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
