import AppKit
import Foundation
import Testing
@testable import AIPace

struct StatusItemControllerTests {
    @Test
    @MainActor
    func popoverHeightUsesEmptyStateWhenNoCards() {
        let expected = StatusItemController.popoverHeaderHeight
            + StatusItemController.popoverFooterHeight
            + StatusItemController.emptyAgentsCardHeight
        #expect(StatusItemController.popoverHeight(forVisibleSnapshotCount: 0) == expected)
    }

    @Test
    @MainActor
    func popoverHeightAddsPerVisibleCardWithPacingRow() {
        let chrome = StatusItemController.popoverHeaderHeight + StatusItemController.popoverFooterHeight
        let card = StatusItemController.providerCardHeight + StatusItemController.pacingAdviceRowHeight

        #expect(StatusItemController.popoverHeight(forVisibleSnapshotCount: 1) == chrome + card)
        // Two cards add card spacing in between.
        #expect(StatusItemController.popoverHeight(forVisibleSnapshotCount: 2)
                == chrome + 2 * card + StatusItemController.cardSpacing)
    }

    @Test
    @MainActor
    func popoverHeightAddsSparklineSpace() {
        let baseline = StatusItemController.popoverHeight(forVisibleSnapshotCount: 2)
        let withSparklines = StatusItemController.popoverHeight(
            forVisibleSnapshotCount: 2, sparklineRowCount: 4
        )
        #expect(withSparklines == baseline + 4 * StatusItemController.sparklineRowHeight)
    }

    @Test
    @MainActor
    func popoverHeightAccountsForProjectsAndAttentionCards() {
        let baseline = StatusItemController.popoverHeight(forVisibleSnapshotCount: 1)
        let withProjects = StatusItemController.popoverHeight(
            forVisibleSnapshotCount: 1, hasClaudeProjects: true
        )
        #expect(withProjects == baseline + StatusItemController.topProjectsRowHeight)

        let oneVisibleOneError = StatusItemController.popoverHeight(
            forVisibleSnapshotCount: 1, erroredAgentCount: 1
        )
        // Adds an attention card and one extra inter-card gap.
        #expect(oneVisibleOneError
                == baseline + StatusItemController.attentionCardHeight + StatusItemController.cardSpacing)
    }
}
