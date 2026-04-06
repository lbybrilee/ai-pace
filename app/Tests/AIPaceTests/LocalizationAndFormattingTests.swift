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
        #expect(StatusItemFormatter.text(prefix: "Cx", snapshot: insightSnapshot, mode: .insight) == "Cx +10%")
    }
}
