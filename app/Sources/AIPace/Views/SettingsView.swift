import SwiftUI

struct SettingsView: View {
    @Bindable var store: UsageStore
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
                    settingRow(loc.launchAtStartup) {
                        HStack(spacing: 8) {
                            Toggle(
                                "",
                                isOn: Binding(
                                    get: { store.launchAtStartupEnabled },
                                    set: { store.setLaunchAtStartupEnabled($0) }
                                )
                            )
                            .labelsHidden()

                            if store.launchAtStartupNeedsApproval {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundStyle(.orange)

                                Button(loc.openSystemSettings) {
                                    if let url = URL(string: "x-apple.systempreferences:com.apple.LoginItems-Settings.extension") {
                                        NSWorkspace.shared.open(url)
                                    }
                                }
                                .buttonStyle(.borderless)
                                .controlSize(.small)
                                .pointerOnHover()
                            }
                            Spacer()
                        }
                    }

                    Text(launchAtStartupDescription)
                        .font(.system(size: 11))
                        .foregroundStyle(launchAtStartupDescriptionColor)
                        .fixedSize(horizontal: false, vertical: true)
                        .padding(.leading, 136)

                    Divider()

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

                    Divider()

                    settingRow(loc.refreshOnOpen) {
                        Toggle(
                            "",
                            isOn: Binding(
                                get: { store.refreshOnOpen },
                                set: { store.setRefreshOnOpen($0) }
                            )
                        )
                        .labelsHidden()
                    }

                    Text(loc.refreshOnOpenDesc)
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
                    if store.notificationsDisabledInSystem {
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundStyle(.orange)
                                .padding(.top, 2)

                            Text(loc.notificationsDisabledWarning)
                                .font(.system(size: 11))
                                .foregroundStyle(.secondary)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .padding(.leading, 136)
                    }

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
        .task {
            await store.refreshNotificationAuthorizationState()
        }
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
        .background(CardBackground())
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

    private var launchAtStartupDescription: String {
        if let error = store.launchAtStartupErrorMessage {
            return error
        }
        if store.launchAtStartupNeedsApproval {
            return loc.launchAtStartupApprovalDesc
        }
        if !store.launchAtStartupSupported {
            return loc.launchAtStartupUnsupportedDesc
        }
        return loc.launchAtStartupDesc
    }

    private var launchAtStartupDescriptionColor: Color {
        if store.launchAtStartupErrorMessage != nil {
            return .orange
        }
        if store.launchAtStartupNeedsApproval {
            return .orange
        }
        return .secondary
    }
}
