import Foundation
import Testing
@testable import AIPace

struct GitHubCopilotProbeTests {
    @Test
    func fetchReturnsTodayAndMonthRequestCounts() async {
        let credentialStore = GitHubCopilotCredentialStore(
            loadOverride: { "token" },
            saveOverride: { _ in },
            deleteOverride: {}
        )
        let apiClient = GitHubCopilotAPIClient(
            fetchAuthenticatedUser: { _ in
                GitHubAuthenticatedUser(login: "octocat")
            },
            fetchPremiumRequestUsage: { _, _, _, _, day in
                if day == nil {
                    return GitHubPremiumRequestUsageResponse(usageItems: [
                        GitHubPremiumRequestUsageItem(grossQuantity: 18),
                        GitHubPremiumRequestUsageItem(grossQuantity: 4),
                    ])
                }
                return GitHubPremiumRequestUsageResponse(usageItems: [
                    GitHubPremiumRequestUsageItem(grossQuantity: 3),
                ])
            }
        )

        let snapshot = await GitHubCopilotProbe(
            credentialStore: credentialStore,
            apiClient: apiClient,
            calendar: Calendar(identifier: .gregorian),
            webSession: GitHubCopilotWebSession(
                fetchOverride: { makeCopilotSnapshot(primaryMessage: "unused") }
            )
        ).fetch()

        #expect(snapshot.primary.kind == .month)
        #expect(snapshot.primary.valueText == "22")
        #expect(snapshot.secondary?.kind == .today)
        #expect(snapshot.secondary?.valueText == "3")
        #expect(snapshot.detail == "octocat")
    }

    @Test
    func fetchReportsMissingToken() async {
        let snapshot = await GitHubCopilotProbe(
            credentialStore: GitHubCopilotCredentialStore(
                loadOverride: { nil },
                saveOverride: { _ in },
                deleteOverride: {}
            ),
            apiClient: GitHubCopilotAPIClient(
                fetchAuthenticatedUser: { _ in
                    Issue.record("fetchAuthenticatedUser should not be called without a token")
                    return GitHubAuthenticatedUser(login: "octocat")
                },
                fetchPremiumRequestUsage: { _, _, _, _, _ in
                    Issue.record("fetchPremiumRequestUsage should not be called without a token")
                    return GitHubPremiumRequestUsageResponse(usageItems: [])
                }
            ),
            webSession: GitHubCopilotWebSession(
                fetchOverride: {
                    makeCopilotSnapshot(primaryMessage: "GitHub sign in required.")
                }
            )
        ).fetch()

        #expect(snapshot.primary.message == "GitHub sign in required.")
    }
}
