import Foundation
import Testing
@testable import AIPace

struct LocalizationAndFormattingTests {
    @Test
    func localizationMapsWindowLabelsAndLoadingMessages() {
        let korean = Loc(lang: .korean)

        #expect(korean.windowLabel(.fiveHour) == "5시간")
        #expect(korean.windowLabel(.weekly) == "주간")
        #expect(korean.displayMessage("Loading…") == "로딩 중…")
        #expect(korean.colors == "색상")
        #expect(korean.reset == "재설정")
        #expect(korean.claudeColor == "Claude 색상")
        #expect(korean.claudeName == "Claude 이름")
        #expect(korean.launchAtStartup == "시동 시 실행")
    }

    @Test
    func localizationBuildsInsightAndStatusInstructions() {
        let english = Loc(lang: .english)
        let status = AgentStatus(provider: .codex, availability: .notInstalled, message: nil)

        #expect(english.insightMessage(delta: -11) == "11% over pace")
        #expect(english.insightMessage(delta: 9) == "9% to spare")
        #expect(english.statusTitle(status) == "Not installed")
        #expect(english.statusInstruction(status) == "Install the Codex CLI and make sure `codex` is on PATH.")
    }

    @Test
    func themeFallbackAndStatusItemFormatting() {
        let snapshot = makeSnapshot(.claude, fiveHourUsed: 12.4, weeklyUsed: 76.6)
        let insightSnapshot = makeSnapshot(
            .codex,
            fiveHourUsed: 5,
            weeklyUsed: 40,
            weeklyReset: Date().addingTimeInterval(3.5 * 24 * 60 * 60)
        )

        #expect(AppTheme.find("missing-theme").id == AppTheme.defaultTheme.id)
        #expect(StatusItemFormatter.text(prefix: "Cl", snapshot: snapshot, mode: .usage) == "Cl 12/77")
        #expect(StatusItemFormatter.text(prefix: "Cl", snapshot: snapshot, mode: .remaining) == "Cl 88/23")
        #expect(StatusItemFormatter.text(prefix: "Cx", snapshot: insightSnapshot, mode: .insight) == "Cx +10%")
        #expect(StatusItemFormatter.text(prefix: "Cx", snapshot: insightSnapshot, mode: .usageAndInsight) == "Cx 5/40 +10%")
        #expect(StatusItemFormatter.text(prefix: "Cx", snapshot: insightSnapshot, mode: .remainingAndInsight) == "Cx 95/60 +10%")
    }

    @Test
    func customAccentHexOverridesSelectedTheme() {
        let suiteName = "AIPaceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("#123ABC", forKey: AppTheme.customClaudeAccentDefaultsKey)

        let theme = AppTheme.resolvedTheme(themeID: AppTheme.sunset.id, userDefaults: defaults)

        #expect(AppColorHex.normalized("f60") == "#FF6600")
        #expect(AppColorHex.string(from: theme.claudeAccent) == "#123ABC")
        #expect(AppColorHex.string(from: theme.codexAccent) == AppColorHex.string(from: AppTheme.sunset.codexAccent))
    }

    @Test
    func customProviderNamesAreTrimmedAndCapped() {
        let suiteName = "AIPaceTests-\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer {
            defaults.removePersistentDomain(forName: suiteName)
        }

        defaults.set("  SonnetPro  ", forKey: ProviderDisplayName.customClaudeNameDefaultsKey)
        defaults.set("  ", forKey: ProviderDisplayName.customCodexNameDefaultsKey)

        #expect(ProviderDisplayName.maxLength == 7)
        #expect(ProviderDisplayName.sanitizedInput("CodeRunner") == "CodeRun")
        #expect(ProviderDisplayName.displayName(for: .claude, userDefaults: defaults) == "SonnetP")
        #expect(ProviderDisplayName.displayName(for: .codex, userDefaults: defaults) == "Cx")
    }
}
