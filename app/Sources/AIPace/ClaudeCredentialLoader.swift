import Foundation

struct ClaudeOAuthCredentials: Sendable, Equatable {
    var accessToken: String
    var subscriptionType: String?
}

enum ClaudeCredentialSource: Sendable, Equatable {
    case file
    case keychain
    case environment
}

enum ClaudeCredentialLoadIssue: Error, Sendable, Equatable {
    case keychainAccessDenied
    case keychainFailure(String)

    var message: String {
        switch self {
        case .keychainAccessDenied:
            return "Claude Keychain access denied."
        case .keychainFailure(let message):
            return message
        }
    }
}

struct ClaudeCredentialResult: Sendable {
    var oauth: ClaudeOAuthCredentials
    let source: ClaudeCredentialSource
}

struct ClaudeCredentialResolution {
    let credentials: ClaudeCredentialResult?
    let issue: ClaudeCredentialLoadIssue?
}

struct ClaudeCredentialLoader {
    private let homeDirectory: URL
    private let environment: [String: String]
    private let keychainService: String
    private let keychainLoadOverride: Result<ClaudeCredentialResult?, ClaudeCredentialLoadIssue>?

    init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        keychainService: String = "Claude Code-credentials",
        keychainLoadOverride: Result<ClaudeCredentialResult?, ClaudeCredentialLoadIssue>? = nil
    ) {
        self.homeDirectory = homeDirectory
        self.environment = environment
        self.keychainService = keychainService
        self.keychainLoadOverride = keychainLoadOverride
    }

    func loadCredentials() -> ClaudeCredentialResult? {
        resolveCredentials().credentials
    }

    func resolveCredentials() -> ClaudeCredentialResolution {
        if let credentials = loadFromFile() {
            return ClaudeCredentialResolution(credentials: credentials, issue: nil)
        }

        let keychainResult = loadFromKeychain()
        if case .success(let credentials) = keychainResult, let credentials {
            return ClaudeCredentialResolution(credentials: credentials, issue: nil)
        }

        if let credentials = loadFromEnvironment() {
            return ClaudeCredentialResolution(credentials: credentials, issue: nil)
        }

        switch keychainResult {
        case .success:
            return ClaudeCredentialResolution(credentials: nil, issue: nil)
        case .failure(let issue):
            return ClaudeCredentialResolution(credentials: nil, issue: issue)
        }
    }

    private func credentialsFileURL() -> URL {
        homeDirectory.appendingPathComponent(".claude/.credentials.json")
    }

    private func loadFromFile() -> ClaudeCredentialResult? {
        let url = credentialsFileURL()
        guard
            FileManager.default.fileExists(atPath: url.path),
            let data = try? Data(contentsOf: url),
            let object = try? JSONSerialization.jsonObject(with: data),
            let root = object as? [String: Any]
        else {
            return nil
        }
        return makeCredentialResult(from: root, source: .file)
    }

    private func loadFromKeychain() -> Result<ClaudeCredentialResult?, ClaudeCredentialLoadIssue> {
        if let keychainLoadOverride {
            return keychainLoadOverride
        }

        do {
            let output = try ProcessRunner.runSync(
                executable: "/usr/bin/security",
                arguments: ["find-generic-password", "-s", keychainService, "-w"],
                input: nil,
                timeout: nil,
                currentDirectory: nil
            )

            guard
                let data = output.data(using: .utf8),
                let object = try? JSONSerialization.jsonObject(with: data),
                let root = object as? [String: Any]
            else {
                return .success(nil)
            }

            return .success(makeCredentialResult(from: root, source: .keychain))
        } catch let error as ProcessRunnerError {
            return mapKeychainError(error)
        } catch {
            return .failure(.keychainFailure("Claude Keychain lookup failed: \(error.localizedDescription)"))
        }
    }

    private func loadFromEnvironment() -> ClaudeCredentialResult? {
        guard let rawToken = environment["CLAUDE_CODE_OAUTH_TOKEN"] else {
            return nil
        }
        let token = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !token.isEmpty else {
            return nil
        }

        return ClaudeCredentialResult(
            oauth: ClaudeOAuthCredentials(accessToken: token, subscriptionType: nil),
            source: .environment
        )
    }

    private func makeCredentialResult(from root: [String: Any], source: ClaudeCredentialSource) -> ClaudeCredentialResult? {
        guard
            let oauth = root["claudeAiOauth"] as? [String: Any],
            let rawToken = oauth["accessToken"] as? String
        else {
            return nil
        }

        let accessToken = rawToken.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !accessToken.isEmpty else {
            return nil
        }

        return ClaudeCredentialResult(
            oauth: ClaudeOAuthCredentials(
                accessToken: accessToken,
                subscriptionType: trimmed(oauth["subscriptionType"] as? String)
            ),
            source: source
        )
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }

    func mapKeychainError(_ error: ProcessRunnerError) -> Result<ClaudeCredentialResult?, ClaudeCredentialLoadIssue> {
        guard case .terminated(_, let output) = error else {
            return .failure(.keychainFailure(error.localizedDescription))
        }

        let normalized = output.lowercased()
        if normalized.contains("could not be found in the keychain") || normalized.contains("item could not be found") {
            return .success(nil)
        }

        if normalized.contains("user interaction is not allowed")
            || normalized.contains("authorization was denied")
            || normalized.contains("user canceled")
            || normalized.contains("user cancelled") {
            return .failure(.keychainAccessDenied)
        }

        let message = output.trimmingCharacters(in: .whitespacesAndNewlines)
        if message.isEmpty {
            return .failure(.keychainFailure("Claude Keychain lookup failed."))
        }
        return .failure(.keychainFailure("Claude Keychain lookup failed: \(message)"))
    }
}
