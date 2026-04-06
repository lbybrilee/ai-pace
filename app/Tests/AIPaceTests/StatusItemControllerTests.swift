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
}
