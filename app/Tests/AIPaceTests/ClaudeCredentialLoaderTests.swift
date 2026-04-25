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
            keychain: InMemoryKeychain()
        )

        let resolution = loader.resolveCredentials()

        #expect(resolution.credentials?.source == .file)
        #expect(resolution.credentials?.oauth.accessToken == "file-token")
        #expect(resolution.credentials?.oauth.refreshToken == "refresh-token")
        #expect(resolution.credentials?.oauth.expiresAt == 12345)
        #expect(resolution.credentials?.oauth.subscriptionType == "pro")
    }

    @Test
    func resolveCredentialsFallsBackToEnvironment() throws {
        let homeDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: homeDirectory) }

        let loader = ClaudeCredentialLoader(
            homeDirectory: homeDirectory,
            environment: ["CLAUDE_CODE_OAUTH_TOKEN": " env-token \n"],
            keychain: InMemoryKeychain()
        )

        let resolution = loader.resolveCredentials()

        #expect(resolution.credentials?.source == .environment)
        #expect(resolution.credentials?.oauth.accessToken == "env-token")
    }

    @Test
    func resolveCredentialsReadsFromKeychainWhenFileMissing() throws {
        let homeDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: homeDirectory) }

        let keychain = InMemoryKeychain()
        let json = """
        {"claudeAiOauth":{"accessToken":"keychain-token","refreshToken":"kc-refresh","expiresAt":9999}}
        """
        keychain.items["Claude Code-credentials"] = Data(json.utf8)

        let loader = ClaudeCredentialLoader(
            homeDirectory: homeDirectory,
            environment: [:],
            keychain: keychain
        )

        let resolution = loader.resolveCredentials()

        #expect(resolution.credentials?.source == .keychain)
        #expect(resolution.credentials?.oauth.accessToken == "keychain-token")
        #expect(resolution.credentials?.oauth.refreshToken == "kc-refresh")
    }

    @Test
    func resolveCredentialsSurfacesKeychainAccessDeniedIssue() throws {
        let homeDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: homeDirectory) }

        let keychain = InMemoryKeychain()
        keychain.loadResult = .failure(.keychainAccessDenied)

        let loader = ClaudeCredentialLoader(
            homeDirectory: homeDirectory,
            environment: [:],
            keychain: keychain
        )

        let resolution = loader.resolveCredentials()

        #expect(resolution.credentials == nil)
        #expect(resolution.issue == .keychainAccessDenied)
    }

    @Test
    func needsRefreshHonorsExpiryBuffer() {
        let loader = ClaudeCredentialLoader(
            homeDirectory: FileManager.default.homeDirectoryForCurrentUser,
            environment: [:],
            keychain: InMemoryKeychain()
        )

        let now = Date().timeIntervalSince1970 * 1000
        let fresh = ClaudeOAuthCredentials(accessToken: "token", refreshToken: nil, expiresAt: now + 10 * 60 * 1000, subscriptionType: nil)
        let expiring = ClaudeOAuthCredentials(accessToken: "token", refreshToken: nil, expiresAt: now + 4 * 60 * 1000, subscriptionType: nil)

        #expect(!loader.needsRefresh(fresh))
        #expect(loader.needsRefresh(expiring))
        #expect(loader.needsRefresh(ClaudeOAuthCredentials(accessToken: "token", refreshToken: nil, expiresAt: nil, subscriptionType: nil)))
    }

    @Test
    func saveCredentialsRoundTripsUnknownTopLevelKeys() throws {
        let homeDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: homeDirectory) }

        let loader = ClaudeCredentialLoader(
            homeDirectory: homeDirectory,
            environment: [:],
            keychain: InMemoryKeychain()
        )
        let originalJSON = """
        {"existing":"value","claudeAiOauth":{"accessToken":"old"}}
        """
        let result = ClaudeCredentialResult(
            oauth: ClaudeOAuthCredentials(
                accessToken: "updated-token",
                refreshToken: "updated-refresh",
                expiresAt: 999,
                subscriptionType: "claude_max"
            ),
            source: .file,
            rawFileData: Data(originalJSON.utf8)
        )

        loader.saveCredentials(result)

        let credentialsURL = homeDirectory.appendingPathComponent(".claude/.credentials.json")
        let data = try Data(contentsOf: credentialsURL)
        let object = try #require(JSONSerialization.jsonObject(with: data) as? [String: Any])
        let oauth = try #require(object["claudeAiOauth"] as? [String: Any])

        #expect(object["existing"] as? String == "value")
        #expect(oauth["accessToken"] as? String == "updated-token")
        #expect(oauth["refreshToken"] as? String == "updated-refresh")
        #expect(oauth["expiresAt"] as? Double == 999)
        #expect(oauth["subscriptionType"] as? String == "claude_max")
    }

    @Test
    func saveCredentialsKeychainSourceWritesThroughProtocol() throws {
        let homeDirectory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: homeDirectory) }

        let keychain = InMemoryKeychain()
        let loader = ClaudeCredentialLoader(
            homeDirectory: homeDirectory,
            environment: [:],
            keychain: keychain
        )

        let result = ClaudeCredentialResult(
            oauth: ClaudeOAuthCredentials(accessToken: "kc-token", refreshToken: "kc-refresh", expiresAt: 1, subscriptionType: nil),
            source: .keychain,
            rawFileData: nil
        )

        loader.saveCredentials(result)

        let stored = try #require(keychain.items["Claude Code-credentials"])
        let object = try #require(JSONSerialization.jsonObject(with: stored) as? [String: Any])
        let oauth = try #require(object["claudeAiOauth"] as? [String: Any])
        #expect(oauth["accessToken"] as? String == "kc-token")
        #expect(oauth["refreshToken"] as? String == "kc-refresh")
    }
}

final class InMemoryKeychain: ClaudeKeychainAccessing, @unchecked Sendable {
    var items: [String: Data] = [:]
    var loadResult: Result<Data?, ClaudeCredentialLoadIssue>?

    func load(service: String) -> Result<Data?, ClaudeCredentialLoadIssue> {
        if let loadResult { return loadResult }
        return .success(items[service])
    }

    func save(service: String, data: Data) -> Result<Void, ClaudeCredentialLoadIssue> {
        items[service] = data
        return .success(())
    }
}
