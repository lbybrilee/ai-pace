import Foundation
import Testing
@testable import AIPace

struct ClaudeAccountInfoResolverTests {
    @Test
    func resolveReturnsAccountInfoFromConfigFile() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configURL = directory.appendingPathComponent(".claude.json")
        try Data(
            """
            {
              "oauthAccount": {
                "emailAddress": "user@example.com",
                "displayName": "Test User",
                "organizationName": "OpenAI"
              }
            }
            """.utf8
        ).write(to: configURL)

        let resolver = ClaudeAccountInfoResolver(configURL: configURL)
        let accountInfo = resolver.resolve()

        #expect(accountInfo?.email == "user@example.com")
        #expect(accountInfo?.displayName == "Test User")
        #expect(accountInfo?.organizationName == "OpenAI")
    }

    @Test
    func resolveReturnsNilWhenConfigHasNoUsefulAccountData() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let configURL = directory.appendingPathComponent(".claude.json")
        try Data("{\"oauthAccount\":{}}".utf8).write(to: configURL)

        #expect(ClaudeAccountInfoResolver(configURL: configURL).resolve() == nil)
    }
}
