import AppKit
import Observation
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
    private var userDefaultsObserver: NSObjectProtocol?

    /// Tracks the last rendered label signature so we skip repeated ImageRenderer work
    /// when nothing that affects the status item title has changed.
    private var lastRenderedSignature: String?

    init(store: UsageStore, openSettings: @escaping @MainActor () -> Void) {
        self.store = store
        self.openSettings = openSettings
        self.statusItem = NSStatusBar.system.statusItem(withLength: 220)
        super.init()
        configureStatusItem()
        configurePopover()
        startObservingStore()
        startObservingUserDefaults()
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

    private func startObservingStore() {
        withObservationTracking { [store] in
            _ = store.claude
            _ = store.codex
        } onChange: { [weak self] in
            Task { @MainActor [weak self] in
                guard let self else { return }
                self.updateButtonTitle()
                self.updatePopoverSize()
                self.startObservingStore()
            }
        }
    }

    private func startObservingUserDefaults() {
        // Only re-render when a key that affects the status item actually changes.
        let watched: Set<String> = [
            "selectedTheme",
            AppTheme.customClaudeAccentDefaultsKey,
            AppTheme.customCodexAccentDefaultsKey,
            "menuBarDisplayMode",
            ProviderDisplayName.customClaudeNameDefaultsKey,
            ProviderDisplayName.customCodexNameDefaultsKey,
        ]
        userDefaultsObserver = NotificationCenter.default.addObserver(
            forName: UserDefaults.didChangeNotification,
            object: UserDefaults.standard,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                guard let self else { return }
                // updateButtonTitle computes a signature and short-circuits when nothing
                // visible changed, so the filter set above is a soft hint — the real
                // guard is the signature comparison.
                _ = watched
                self.updateButtonTitle()
            }
        }
    }

    private func updateButtonTitle() {
        guard let button = statusItem.button else {
            return
        }

        let themeID = UserDefaults.standard.string(forKey: "selectedTheme") ?? AppTheme.defaultTheme.id
        let claudeHex = UserDefaults.standard.string(forKey: AppTheme.customClaudeAccentDefaultsKey) ?? ""
        let codexHex = UserDefaults.standard.string(forKey: AppTheme.customCodexAccentDefaultsKey) ?? ""
        let displayMode = MenuBarDisplayMode(
            rawValue: UserDefaults.standard.string(forKey: "menuBarDisplayMode") ?? MenuBarDisplayMode.usage.rawValue
        ) ?? .usage
        let claudeName = ProviderDisplayName.displayName(for: .claude)
        let codexName = ProviderDisplayName.displayName(for: .codex)

        let claudeStatus = store.agentStatus(for: .claude)
        let codexStatus = store.agentStatus(for: .codex)
        let claudeText = claudeStatus.availability.showsInPopover
            ? StatusItemFormatter.text(prefix: claudeName, snapshot: store.claude, mode: displayMode)
            : nil
        let codexText = codexStatus.availability.showsInPopover
            ? StatusItemFormatter.text(prefix: codexName, snapshot: store.codex, mode: displayMode)
            : nil

        let signature = "\(themeID)|\(claudeHex)|\(codexHex)|\(displayMode.rawValue)|\(claudeName)|\(codexName)|\(claudeText ?? "")|\(codexText ?? "")"
        guard signature != lastRenderedSignature else {
            return
        }
        lastRenderedSignature = signature

        let theme = AppTheme.resolvedTheme(
            themeID: themeID,
            customClaudeAccentHex: claudeHex,
            customCodexAccentHex: codexHex
        )
        let view = StatusItemLabelView(claudeText: claudeText, codexText: codexText, theme: theme)
        let renderer = ImageRenderer(content: view)
        renderer.scale = NSScreen.main?.backingScaleFactor ?? 2

        guard let image = renderer.nsImage else {
            return
        }

        image.isTemplate = false
        button.image = image
        statusItem.length = image.size.width + 12
    }

    private func updatePopoverSize() {
        guard let hostingController = popoverHostingController else {
            return
        }

        let size = popoverSize()
        guard popover.contentSize != size else {
            return
        }

        popover.contentSize = size
        hostingController.preferredContentSize = size
        hostingController.view.setFrameSize(size)
        // Rebuild root view so MenuContentView picks up the new popoverHeight parameter.
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
        let visible = store.visibleSnapshots
        let sparklineRows = visible.reduce(0) { total, snapshot in
            total + sparklineRowCount(for: snapshot)
        }
        return Self.popoverHeight(
            forVisibleSnapshotCount: visible.count,
            sparklineRowCount: sparklineRows,
            erroredAgentCount: store.erroredAgents.count,
            hasClaudeProjects: !store.topClaudeProjects.isEmpty
        )
    }

    private func sparklineRowCount(for snapshot: ProviderSnapshot) -> Int {
        let fiveKey = UsageWindowKey(provider: snapshot.provider, kind: .fiveHour)
        let weekKey = UsageWindowKey(provider: snapshot.provider, kind: .weekly)
        var count = 0
        if SparklineView.hasRenderableData(store.history.samples(for: fiveKey)) { count += 1 }
        if SparklineView.hasRenderableData(store.history.samples(for: weekKey)) { count += 1 }
        return count
    }

    /// Each sparkline adds this many points to the popover height:
    /// 14pt canvas + 2pt `.padding(.top, 2)` + 5pt from the enclosing VStack's
    /// `spacing: 5` (one new gap per added child in `UsageRow`).
    static let sparklineRowHeight: CGFloat = 21

    /// Title bar + AIPace label area at the top of the popover.
    static let popoverHeaderHeight: CGFloat = 60
    /// Timestamp + theme/settings/refresh button row at the bottom.
    static let popoverFooterHeight: CGFloat = 44
    /// Spacing between cards stacked inside the popover.
    static let cardSpacing: CGFloat = 8
    /// Natural height of a populated `ProviderCard` (header row + 5h row +
    /// week row + card padding) before any optional rows are added.
    static let providerCardHeight: CGFloat = 130
    /// Empty-state card shown when there are no providers at all.
    static let emptyAgentsCardHeight: CGFloat = 116
    /// Compact attention card for an errored provider.
    static let attentionCardHeight: CGFloat = 60
    /// Pacing-advice row shown under each visible 5h bar.
    static let pacingAdviceRowHeight: CGFloat = 20
    /// "Top projects" pill rendered (collapsed) under the Claude card.
    static let topProjectsRowHeight: CGFloat = 30

    static func popoverHeight(
        forVisibleSnapshotCount count: Int,
        sparklineRowCount: Int = 0,
        erroredAgentCount: Int = 0,
        hasClaudeProjects: Bool = false
    ) -> CGFloat {
        var height = popoverHeaderHeight + popoverFooterHeight

        if count == 0 && erroredAgentCount == 0 {
            return height + emptyAgentsCardHeight
        }

        let totalCards = count + erroredAgentCount
        height += CGFloat(count) * providerCardHeight
        height += CGFloat(erroredAgentCount) * attentionCardHeight
        height += CGFloat(max(0, totalCards - 1)) * cardSpacing
        height += CGFloat(sparklineRowCount) * sparklineRowHeight
        height += CGFloat(count) * pacingAdviceRowHeight
        if hasClaudeProjects { height += topProjectsRowHeight }
        return height
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
            await store.refreshOnPopoverOpen()
        }
    }

    private func showContextMenu() {
        closePopover()

        let menu = NSMenu()
        menu.delegate = self

        let refreshItem = NSMenuItem(title: "Refresh Now", action: #selector(refreshFromMenu(_:)), keyEquivalent: "r")
        refreshItem.target = self
        menu.addItem(refreshItem)

        let copyItem = NSMenuItem(title: "Copy Usage", action: #selector(copyUsageFromMenu(_:)), keyEquivalent: "c")
        copyItem.target = self
        menu.addItem(copyItem)

        menu.addItem(.separator())

        let consoleItem = NSMenuItem(title: "Open Anthropic Console…", action: #selector(openConsoleFromMenu(_:)), keyEquivalent: "")
        consoleItem.target = self
        menu.addItem(consoleItem)

        let optionsItem = NSMenuItem(title: "Options…", action: #selector(openSettingsFromMenu(_:)), keyEquivalent: ",")
        optionsItem.target = self
        menu.addItem(optionsItem)

        menu.addItem(.separator())

        let aboutItem = NSMenuItem(title: "About AIPace", action: #selector(showAboutFromMenu(_:)), keyEquivalent: "")
        aboutItem.target = self
        menu.addItem(aboutItem)

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

    @objc private func refreshFromMenu(_ sender: Any?) {
        Task { await store.refresh() }
    }

    @objc private func copyUsageFromMenu(_ sender: Any?) {
        let displayMode = MenuBarDisplayMode(
            rawValue: UserDefaults.standard.string(forKey: "menuBarDisplayMode") ?? MenuBarDisplayMode.usage.rawValue
        ) ?? .usage
        var parts: [String] = []
        if store.agentStatus(for: .claude).availability.showsInPopover {
            parts.append(StatusItemFormatter.text(prefix: "Claude", snapshot: store.claude, mode: displayMode))
        }
        if store.agentStatus(for: .codex).availability.showsInPopover {
            parts.append(StatusItemFormatter.text(prefix: "Codex", snapshot: store.codex, mode: displayMode))
        }
        let text = parts.isEmpty ? "AIPace: no authenticated agents" : parts.joined(separator: "   ")
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    @objc private func openConsoleFromMenu(_ sender: Any?) {
        if let url = URL(string: "https://console.anthropic.com/") {
            NSWorkspace.shared.open(url)
        }
    }

    @objc private func showAboutFromMenu(_ sender: Any?) {
        NSApp.orderFrontStandardAboutPanel(nil)
        NSApp.activate(ignoringOtherApps: true)
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
