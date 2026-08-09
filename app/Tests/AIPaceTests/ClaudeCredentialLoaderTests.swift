import Foundation
import Testing
@testable import AIPace

struct ClaudeCredentialLoaderTests {
    @Test
    func resolveCredentialsPrefersFileOverEnvironment() throws {
        let homeDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: homeDirectory) }

        let credentialsURL = homeDirectory.appendingPathComponent(".claude/.credentials.json")
        try FileManager.default.createDirectory(at: credentialsURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data(
            """
            {
              "claudeAiOauth": {
                "accessToken": " file-token ",
                "refreshToken": " refresh-token ",
                "expiresAt": "12345",
                "subscriptionType": " pro "
              }
            }
            """.utf8
        ).write(to: credentialsURL)

        let loader = ClaudeCredentialLoader(
            homeDirectory: homeDirectory,
            environment: ["CLAUDE_CODE_OAUTH_TOKEN": "env-token"],
            keychainLoadOverride: .success(nil)
        )

        let resolution = loader.resolveCredentials()

        #expect(resolution.credentials?.source == .file)
        #expect(resolution.credentials?.oauth.accessToken == "file-token")
        #expect(resolution.credentials?.oauth.subscriptionType == "pro")
    }

    @Test
    func resolveCredentialsFallsBackToEnvironment() throws {
        let homeDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: homeDirectory) }

        let loader = ClaudeCredentialLoader(
            homeDirectory: homeDirectory,
            environment: ["CLAUDE_CODE_OAUTH_TOKEN": " env-token \n"],
            keychainLoadOverride: .success(nil)
        )

        let resolution = loader.resolveCredentials()

        #expect(resolution.credentials?.source == .environment)
        #expect(resolution.credentials?.oauth.accessToken == "env-token")
    }

    @Test
    func mapKeychainErrorCategorizesCommonFailures() throws {
        let loader = ClaudeCredentialLoader(
            homeDirectory: try makeTemporaryDirectory(),
            environment: [:],
            keychainLoadOverride: .success(nil)
        )

        switch loader.mapKeychainError(.terminated(1, "User interaction is not allowed.")) {
        case .failure(let issue):
            #expect(issue == .keychainAccessDenied)
        default:
            Issue.record("Expected access denied classification")
        }

        switch loader.mapKeychainError(.terminated(44, "The specified item could not be found in the keychain.")) {
        case .success(let credentials):
            #expect(credentials == nil)
        default:
            Issue.record("Expected missing keychain item to map to no credentials")
        }
    }
}
