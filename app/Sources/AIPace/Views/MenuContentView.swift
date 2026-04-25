import AppKit
import SwiftUI

struct MenuContentView: View {
    @Bindable var store: UsageStore
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
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                AppLogoView(size: 18)
                Text("AIPace")
                    .font(.system(size: 16, weight: .semibold))
                Spacer()
            }
            .padding(.horizontal, 20)
            .padding(.top, 18)
            .padding(.bottom, 14)

            VStack(spacing: 8) {
                let errored = store.erroredAgents

                if visibleSnapshots.isEmpty && errored.isEmpty {
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
                    ForEach(errored, id: \.provider.rawValue) { status in
                        AgentAttentionCard(status: status, openSettings: openSettings)
                    }
                }
            }
            .padding(.horizontal, 20)

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
        .task {
            await store.refreshNotificationAuthorizationState()
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

/// Compact card surfacing a provider that's currently in an error state
/// (auth missing, Keychain denied, session expired, etc). Replaces the old
/// behaviour of silently hiding errored providers from the popover.
struct AgentAttentionCard: View {
    let status: AgentStatus
    let openSettings: () -> Void
    @AppStorage("appLanguage") private var langID = AppLanguage.english.rawValue
    private var loc: Loc { Loc(lang: AppLanguage(rawValue: langID) ?? .english) }

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.orange)
                .padding(.top, 2)
            AgentStatusRow(status: status)
            Button(loc.openSettings, action: openSettings)
                .buttonStyle(.bordered)
                .controlSize(.small)
                .pointerOnHover()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(CardBackground())
    }
}

struct EmptyAgentsCard: View {
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
        .background(CardBackground())
    }
}
