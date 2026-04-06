import AppKit
import SwiftUI

// MARK: - Main Popover

struct MenuContentView: View {
    @ObservedObject var store: UsageStore
    let openSettings: () -> Void
    let popoverHeight: CGFloat
    @AppStorage("selectedTheme") private var selectedThemeID = AppTheme.defaultTheme.id
    @AppStorage(AppTheme.customClaudeAccentDefaultsKey) private var customClaudeAccentHex = ""
    @AppStorage(AppTheme.customCodexAccentDefaultsKey) private var customCodexAccentHex = ""
    @AppStorage("appLanguage") private var langID = AppLanguage.english.rawValue
    @AppStorage("menuBarDisplayMode") private var menuBarDisplayModeID = MenuBarDisplayMode.usage.rawValue

    private var theme: AppTheme {
        AppTheme.resolvedTheme(
            themeID: selectedThemeID,
            customClaudeAccentHex: customClaudeAccentHex,
            customCodexAccentHex: customCodexAccentHex
        )
    }
    private var lang: AppLanguage { AppLanguage(rawValue: langID) ?? .english }
    private var loc: Loc { Loc(lang: lang) }
    private let popoverWidth: CGFloat = 440

    var body: some View {
        let visibleSnapshots = store.visibleSnapshots

        VStack(spacing: 0) {
            // Header
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                AppLogoView(size: 18)
                Text("AIPace")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            // Provider cards
            VStack(spacing: 8) {
                if visibleSnapshots.isEmpty {
                    EmptyAgentsCard(loc: loc, openSettings: openSettings)
                } else {
                    ForEach(visibleSnapshots, id: \.provider.rawValue) { snapshot in
                        ProviderCard(
                            snapshot: snapshot,
                            store: store,
                            accent: accent(for: snapshot.provider),
                            lang: lang
                        )
                    }
                }
            }
            .padding(.horizontal, 20)

            // Footer
            HStack {
                if let ts = store.lastUpdated {
                    Text(ts.formatted(date: .omitted, time: .shortened))
                        .font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.tertiary)
                }
                Spacer()
                HStack(spacing: 12) {
                    footerMenu(icon: "paintpalette") {
                        ForEach(AppTheme.all) { t in
                            Button {
                                selectedThemeID = t.id
                            } label: {
                                if t.id == selectedThemeID {
                                    Label(t.name, systemImage: "checkmark")
                                } else {
                                    Text(t.name)
                                }
                            }
                        }
                    }

                    footerButton(icon: "gearshape") {
                        openSettings()
                    }

                    footerButton(icon: "arrow.clockwise", dimmed: store.isRefreshing) {
                        Task { await store.refresh() }
                    }
                    .disabled(store.isRefreshing)
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 10)
            .padding(.bottom, 14)
        }
        .frame(width: popoverWidth)
        .frame(height: popoverHeight, alignment: .top)
        .transaction { transaction in
            transaction.animation = nil
        }
    }

    private func accent(for provider: ProviderKind) -> Color {
        switch provider {
        case .claude:
            return theme.claudeAccent
        case .codex:
            return theme.codexAccent
        }
    }

    // MARK: Footer Helpers

    private func footerButton(icon: String, dimmed: Bool = false, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(dimmed ? .tertiary : .secondary)
        }
        .buttonStyle(.plain)
        .pointerOnHover()
    }

    private func footerMenu<Content: View>(icon: String, @ViewBuilder content: @escaping () -> Content) -> some View {
        Menu { content() } label: {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .menuStyle(.borderlessButton)
        .menuIndicator(.hidden)
        .fixedSize()
        .pointerOnHover()
    }
}

private struct EmptyAgentsCard: View {
    let loc: Loc
    let openSettings: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(loc.noAgentsMessage)
                .font(.system(size: 14, weight: .semibold))
            Text(loc.noAgentsHint)
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Button(loc.openSettings, action: openSettings)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .pointerOnHover()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(0.035))
        )
    }
}

// MARK: - Provider Card

private struct ProviderCard: View {
    let snapshot: ProviderSnapshot
    @ObservedObject var store: UsageStore
    let accent: Color
    let lang: AppLanguage
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            let insight = WeeklyPacingInsight(window: snapshot.weekly, lang: lang)

            // Provider header
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Circle()
                    .fill(accent)
                    .frame(width: 7, height: 7)
                    .offset(y: -0.5)
                Text(snapshot.provider.rawValue)
                    .font(.system(size: 15, weight: .semibold))
                if let insight {
                    FlashingDot(color: insight.color)
                        .offset(y: -0.5)
                    Text(insight.message)
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(insight.color)
                        .lineLimit(1)
                }
                Spacer()
                if let detail = snapshot.detail {
                    Text(detail)
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                }
            }

            // Usage rows
            UsageRow(window: snapshot.fiveHour, provider: snapshot.provider, store: store, accent: accent, lang: lang)
            UsageRow(window: snapshot.weekly, provider: snapshot.provider, store: store, accent: accent, lang: lang)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: 8, style: .continuous)
                .fill(Color.primary.opacity(colorScheme == .dark ? 0.035 : 0.06))
        )
    }
}

// MARK: - Weekly Pacing Insight

private struct WeeklyPacingInsight {
    let message: String
    let color: Color

    init?(window: UsageWindow, lang: AppLanguage, now: Date = .now) {
        guard let delta = WeeklyPacing.delta(for: window, now: now) else {
            return nil
        }

        message = Loc(lang: lang).insightMessage(delta: delta)

        switch delta {
        case ..<(-5): color = .orange
        case -5...5: color = .green
        default: color = .blue
        }
    }
}

// MARK: - Usage Row (Two-Tier Layout)

private struct UsageRow: View {
    let window: UsageWindow
    let provider: ProviderKind
    @ObservedObject var store: UsageStore
    let accent: Color
    let lang: AppLanguage

    private var key: UsageWindowKey { UsageWindowKey(provider: provider, kind: window.kind) }
    private var notifyEnabled: Bool { store.refreshNotificationsEnabled(for: key) }
    private var loc: Loc { Loc(lang: lang) }
    private let barLeadingInset: CGFloat = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            // Top tier: stats
            HStack(spacing: 6) {
                Button {
                    Task { await store.setRefreshNotificationsEnabled(!notifyEnabled, for: key) }
                } label: {
                    Image(systemName: notifyEnabled ? "bell.fill" : "bell")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(notifyEnabled ? .primary : .tertiary)
                        .symbolRenderingMode(.hierarchical)
                        .frame(width: 16, height: 16)
                        .frame(width: 20, height: 20)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .pointerOnHover()
                .padding(.leading, 4)

                Text(loc.windowLabel(window.kind))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(.secondary)

                Spacer()

                Group {
                    if let used = window.usedPercentage {
                        Text("\(Int(used.rounded()))%")
                            .font(.system(size: 14, weight: .medium, design: .monospaced))
                    } else {
                        Text(loc.displayMessage(window.message))
                            .font(.system(size: 12))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(minWidth: 36, alignment: .trailing)

                Group {
                    if let resetsAt = window.resetsAt {
                        Text(formatReset(resetsAt))
                            .font(.system(size: 12, design: .monospaced))
                            .foregroundStyle(.tertiary)
                    }
                }
                .frame(width: 86, alignment: .trailing)
            }

            // Bottom tier: full-width bar
            UsageBar(percentage: window.usedPercentage, accent: accent)
                .padding(.leading, barLeadingInset)
        }
    }

    private func formatReset(_ date: Date) -> String {
        let secs = max(0, Int(date.timeIntervalSinceNow.rounded(.down)))
        if secs < 60 { return "<1m" }
        let tot = secs / 60
        let d = tot / 1440
        let h = (tot % 1440) / 60
        let m = tot % 60
        var p: [String] = []
        if d > 0 { p.append("\(d)d") }
        if h > 0 || d > 0 { p.append("\(h)h") }
        p.append(String(format: "%02dm", m))
        return p.joined(separator: " ")
    }
}

private struct FlashingDot: View {
    let color: Color
    @State private var isDimmed = false

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: 6, height: 6)
            .opacity(isDimmed ? 0.25 : 1.0)
            .scaleEffect(isDimmed ? 0.8 : 1.0)
            .onAppear {
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) {
                    isDimmed = true
                }
            }
    }
}

// MARK: - Custom Progress Bar

private struct UsageBar: View {
    let percentage: Double?
    let accent: Color
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.primary.opacity(colorScheme == .dark ? 0.08 : 0.12))
                if let pct = percentage {
                    Capsule()
                        .fill(accent.opacity(barOpacity(for: pct)))
                        .frame(width: max(2, geo.size.width * min(max(pct, 0), 100) / 100))
                }
            }
        }
        .frame(height: 5)
    }

    private func barOpacity(for pct: Double) -> Double {
        colorScheme == .dark ? (pct > 80 ? 1.0 : pct > 60 ? 0.85 : 0.75) : 1.0
    }
}

// MARK: - Settings

struct SettingsView: View {
    @ObservedObject var store: UsageStore
    @AppStorage("selectedTheme") private var selectedThemeID = AppTheme.defaultTheme.id
    @AppStorage(AppTheme.customClaudeAccentDefaultsKey) private var customClaudeAccentHex = ""
    @AppStorage(AppTheme.customCodexAccentDefaultsKey) private var customCodexAccentHex = ""
    @AppStorage("appLanguage") private var langID = AppLanguage.english.rawValue
    @AppStorage("menuBarDisplayMode") private var menuBarDisplayModeID = MenuBarDisplayMode.usage.rawValue

    private var lang: AppLanguage { AppLanguage(rawValue: langID) ?? .english }
    private var loc: Loc { Loc(lang: lang) }
    private var baseTheme: AppTheme { AppTheme.find(selectedThemeID) }

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            settingsCard {
                settingRow(loc.language) {
                    Picker("", selection: $langID) {
                        ForEach(AppLanguage.allCases) { l in
                            Text(l.displayName).tag(l.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 180)
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    settingRow(loc.autoRefresh) {
                        Picker("", selection: Binding(
                            get: { store.autoRefreshInterval },
                            set: { store.setAutoRefreshInterval($0) }
                        )) {
                            ForEach(AutoRefreshInterval.allCases) { interval in
                                Text(loc.refreshLabel(interval)).tag(interval)
                            }
                        }
                        .pickerStyle(.menu)
                        .labelsHidden()
                        .frame(width: 180)
                    }

                    Text(loc.autoRefreshDesc)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 136)
                }

                Divider()

                settingRow(loc.menuBarDisplay) {
                    Picker("", selection: $menuBarDisplayModeID) {
                        ForEach(MenuBarDisplayMode.allCases) { mode in
                            Text(loc.menuBarDisplayLabel(mode)).tag(mode.rawValue)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 180)
                }
            }

            settingsCard(title: loc.agents) {
                AgentStatusRow(status: store.agentStatus(for: .claude))

                Divider()

                AgentStatusRow(status: store.agentStatus(for: .codex))
            }

            settingsCard(title: loc.notifications) {
                VStack(alignment: .leading, spacing: 8) {
                    settingRow(loc.notificationSound) {
                        HStack(spacing: 8) {
                            Picker("", selection: Binding(
                                get: { store.notificationSound },
                                set: { store.setNotificationSound($0) }
                            )) {
                                ForEach(NotificationSoundOption.allCases) { option in
                                    Text(loc.notificationSoundLabel(option)).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                            .labelsHidden()
                            .frame(width: 140)

                            Button {
                                store.previewNotificationSound()
                            } label: {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 11, weight: .medium))
                                    .frame(width: 24, height: 24)
                            }
                            .buttonStyle(.borderless)
                            .pointerOnHover()
                        }
                    }

                    Text(loc.notificationsDesc)
                        .font(.system(size: 11))
                        .foregroundStyle(.tertiary)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 136)
                }
            }

            settingsCard(title: loc.colors) {
                settingRow(loc.theme) {
                    Picker("", selection: $selectedThemeID) {
                        ForEach(AppTheme.all) { theme in
                            Text(theme.name).tag(theme.id)
                        }
                    }
                    .pickerStyle(.menu)
                    .labelsHidden()
                    .frame(width: 180)
                }

                Divider()

                settingRow(loc.claudeColor) {
                    AccentColorControl(
                        hexValue: $customClaudeAccentHex,
                        fallbackColor: baseTheme.claudeAccent,
                        resetLabel: loc.reset
                    )
                }

                Divider()

                settingRow(loc.codexColor) {
                    AccentColorControl(
                        hexValue: $customCodexAccentHex,
                        fallbackColor: baseTheme.codexAccent,
                        resetLabel: loc.reset
                    )
                }

                Text(loc.colorsDesc)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 136)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(20)
        .frame(width: 500)
    }

    private func settingsCard<Content: View>(title: String? = nil, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title {
                Text(title)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }

            content()
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 10, style: .continuous)
                .fill(Color.primary.opacity(0.05))
        )
    }

    private func settingRow<Content: View>(_ title: String, @ViewBuilder control: () -> Content) -> some View {
        HStack(alignment: .center) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
                .frame(width: 120, alignment: .leading)
            Spacer(minLength: 20)
            control()
        }
    }
}

private struct AccentColorControl: View {
    @Binding var hexValue: String
    let fallbackColor: Color
    let resetLabel: String

    @FocusState private var isFocused: Bool
    @State private var draftHex = ""

    var body: some View {
        HStack(spacing: 8) {
            ColorPicker(
                "",
                selection: Binding(
                    get: { AppColorHex.color(from: hexValue) ?? fallbackColor },
                    set: { newColor in
                        guard let resolvedHex = AppColorHex.string(from: newColor) else {
                            return
                        }
                        hexValue = resolvedHex
                        draftHex = resolvedHex
                    }
                ),
                supportsOpacity: false
            )
            .labelsHidden()
            .frame(width: 32)

            TextField("#F26B1D", text: $draftHex)
                .textFieldStyle(.roundedBorder)
                .font(.system(size: 12, design: .monospaced))
                .frame(width: 96)
                .focused($isFocused)
                .onSubmit(commitDraft)
                .onChange(of: isFocused) { _, focused in
                    if !focused {
                        commitDraft()
                    }
                }
                .onChange(of: hexValue) { _, _ in
                    if !isFocused {
                        syncDraft()
                    }
                }

            Button(resetLabel) {
                hexValue = ""
                draftHex = ""
            }
            .buttonStyle(.borderless)
            .disabled(AppColorHex.normalized(hexValue) == nil)
            .pointerOnHover()
        }
        .onAppear(perform: syncDraft)
    }

    private func commitDraft() {
        let trimmed = draftHex.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            hexValue = ""
            draftHex = ""
            return
        }

        guard let normalized = AppColorHex.normalized(trimmed) else {
            syncDraft()
            return
        }

        hexValue = normalized
        draftHex = normalized
    }

    private func syncDraft() {
        draftHex = AppColorHex.normalized(hexValue) ?? ""
    }
}

private struct PointerOnHoverModifier: ViewModifier {
    func body(content: Content) -> some View {
        content.onHover { inside in
            if inside {
                NSCursor.pointingHand.push()
            } else {
                NSCursor.pop()
            }
        }
    }
}

private extension View {
    func pointerOnHover() -> some View {
        modifier(PointerOnHoverModifier())
    }
}

private struct AgentStatusRow: View {
    let status: AgentStatus
    @AppStorage("appLanguage") private var langID = AppLanguage.english.rawValue

    private var lang: AppLanguage { AppLanguage(rawValue: langID) ?? .english }
    private var loc: Loc { Loc(lang: lang) }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(status.provider.rawValue)
                    .font(.system(size: 13, weight: .semibold))
                Spacer()
                Text(loc.statusTitle(status))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(statusColor)
            }

            if let message = status.message, case .error = status.availability {
                Text(message)
                    .font(.system(size: 11))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let instruction = loc.statusInstruction(status) {
                Text(instruction)
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var statusColor: Color {
        switch status.availability {
        case .available:
            return .green
        case .loading:
            return .secondary
        case .missingAuth, .accessDenied, .sessionExpired, .notInstalled, .notLoggedIn:
            return .orange
        case .error:
            return .red
        }
    }
}
