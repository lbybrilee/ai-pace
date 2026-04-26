import AppKit
import Foundation
import Testing
@testable import AIPace

struct StatusItemControllerTests {
    @Test
    @MainActor
    func popoverHeightBucketsMatchVisibleAgentCounts() {
        #expect(StatusItemController.popoverHeight(forVisibleSnapshotCount: 0) == 220)
        #expect(StatusItemController.popoverHeight(forVisibleSnapshotCount: 1) == 250)
        #expect(StatusItemController.popoverHeight(forVisibleSnapshotCount: 2) == 380)
        #expect(StatusItemController.popoverHeight(forVisibleSnapshotCount: 5) == 380)
    }

    @Test
    func statusItemLabelFallsBackWhenProviderTextsAreMissingOrBlank() {
        #expect(StatusItemLabelView.resolvedFallbackText(claudeText: nil, codexText: nil) == "AIPace")
        #expect(StatusItemLabelView.resolvedFallbackText(claudeText: " ", codexText: "\n") == "AIPace")
        #expect(StatusItemLabelView.resolvedFallbackText(claudeText: "Cl 12/34", codexText: nil) == nil)
        #expect(StatusItemLabelView.resolvedFallbackText(claudeText: nil, codexText: "Cx 56/78") == nil)
    }

    @Test
    @MainActor
    func statusItemLengthIsClampedToMinimumVisibleWidth() {
        #expect(StatusItemController.statusItemLength(forContentWidth: 0) == 32)
        #expect(StatusItemController.statusItemLength(forContentWidth: 10) == 32)
        #expect(StatusItemController.statusItemLength(forContentWidth: 40) == 52)
    }
}
