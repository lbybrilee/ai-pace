import Foundation
import Security

struct ClaudeOAuthCredentials: Sendable, Equatable, Codable {
    var accessToken: String
    var refreshToken: String?
    var expiresAt: Double?
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

struct ClaudeCredentialResult: Sendable, Equatable {
    var oauth: ClaudeOAuthCredentials
    let source: ClaudeCredentialSource
    /// Raw bytes of the original JSON document, preserved so top-level keys we don't
    /// know about round-trip safely on save. Nil means "no pre-existing document".
    var rawFileData: Data?
}

struct ClaudeCredentialResolution: Sendable {
    let credentials: ClaudeCredentialResult?
    let issue: ClaudeCredentialLoadIssue?
}

protocol ClaudeKeychainAccessing: Sendable {
    func load(service: String) -> Result<Data?, ClaudeCredentialLoadIssue>
    func save(service: String, data: Data) -> Result<Void, ClaudeCredentialLoadIssue>
}

struct ClaudeKeychain: ClaudeKeychainAccessing {
    func load(service: String) -> Result<Data?, ClaudeCredentialLoadIssue> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
            kSecReturnData as String: true,
            kSecMatchLimit as String: kSecMatchLimitOne,
        ]

        var item: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &item)

        switch status {
        case errSecSuccess:
            return .success(item as? Data)
        case errSecItemNotFound:
            return .success(nil)
        case errSecUserCanceled, errSecAuthFailed, errSecInteractionNotAllowed:
            return .failure(.keychainAccessDenied)
        default:
            return .failure(.keychainFailure("Claude Keychain lookup failed (OSStatus \(status))."))
        }
    }

    func save(service: String, data: Data) -> Result<Void, ClaudeCredentialLoadIssue> {
        let query: [String: Any] = [
            kSecClass as String: kSecClassGenericPassword,
            kSecAttrService as String: service,
        ]
        let update: [String: Any] = [kSecValueData as String: data]

        let updateStatus = SecItemUpdate(query as CFDictionary, update as CFDictionary)
        switch updateStatus {
        case errSecSuccess:
            return .success(())
        case errSecItemNotFound:
            break
        case errSecUserCanceled, errSecAuthFailed, errSecInteractionNotAllowed:
            return .failure(.keychainAccessDenied)
        default:
            return .failure(.keychainFailure("Claude Keychain update failed (OSStatus \(updateStatus))."))
        }

        var addQuery = query
        addQuery[kSecValueData as String] = data
        let addStatus = SecItemAdd(addQuery as CFDictionary, nil)
        switch addStatus {
        case errSecSuccess:
            return .success(())
        case errSecUserCanceled, errSecAuthFailed, errSecInteractionNotAllowed:
            return .failure(.keychainAccessDenied)
        default:
            return .failure(.keychainFailure("Claude Keychain add failed (OSStatus \(addStatus))."))
        }
    }
}

struct ClaudeCredentialLoader: Sendable {
    private let homeDirectory: URL
    private let environment: [String: String]
    private let keychainService: String
    private let keychain: any ClaudeKeychainAccessing
    private static let refreshBufferMs: Double = 5 * 60 * 1000

    init(
        homeDirectory: URL = FileManager.default.homeDirectoryForCurrentUser,
        environment: [String: String] = ProcessInfo.processInfo.environment,
        keychainService: String = "Claude Code-credentials",
        keychain: any ClaudeKeychainAccessing = ClaudeKeychain()
    ) {
        self.homeDirectory = homeDirectory
        self.environment = environment
        self.keychainService = keychainService
        self.keychain = keychain
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

    func needsRefresh(_ oauth: ClaudeOAuthCredentials) -> Bool {
        guard let expiresAt = oauth.expiresAt else {
            return true
        }
        let nowMs = Date().timeIntervalSince1970 * 1000
        return nowMs + Self.refreshBufferMs >= expiresAt
    }

    func saveCredentials(_ result: ClaudeCredentialResult) {
        guard let merged = mergedJSONData(for: result) else {
            return
        }

        switch result.source {
        case .file:
            saveToFile(data: merged)
        case .keychain:
            _ = keychain.save(service: keychainService, data: merged)
        case .environment:
            return
        }
    }

    private func credentialsFileURL() -> URL {
        homeDirectory.appendingPathComponent(".claude/.credentials.json")
    }

    private func loadFromFile() -> ClaudeCredentialResult? {
        let url = credentialsFileURL()
        guard
            FileManager.default.fileExists(atPath: url.path),
            let data = try? Data(contentsOf: url)
        else {
            return nil
        }
        return parseCredentials(from: data, source: .file)
    }

    private func loadFromKeychain() -> Result<ClaudeCredentialResult?, ClaudeCredentialLoadIssue> {
        switch keychain.load(service: keychainService) {
        case .success(let data):
            guard let data else {
                return .success(nil)
            }
            return .success(parseCredentials(from: data, source: .keychain))
        case .failure(let issue):
            return .failure(issue)
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
            oauth: ClaudeOAuthCredentials(
                accessToken: token,
                refreshToken: nil,
                expiresAt: nil,
                subscriptionType: nil
            ),
            source: .environment,
            rawFileData: nil
        )
    }

    private func parseCredentials(from data: Data, source: ClaudeCredentialSource) -> ClaudeCredentialResult? {
        guard
            let object = try? JSONSerialization.jsonObject(with: data),
            let root = object as? [String: Any],
            let oauthDict = root["claudeAiOauth"] as? [String: Any],
            let rawToken = oauthDict["accessToken"] as? String
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
                refreshToken: trimmed(oauthDict["refreshToken"] as? String),
                expiresAt: parseExpiresAt(oauthDict["expiresAt"]),
                subscriptionType: trimmed(oauthDict["subscriptionType"] as? String)
            ),
            source: source,
            rawFileData: data
        )
    }

    private func saveToFile(data: Data) {
        let url = credentialsFileURL()
        try? FileManager.default.createDirectory(
            at: url.deletingLastPathComponent(),
            withIntermediateDirectories: true
        )
        try? data.write(to: url, options: .atomic)
    }

    private func mergedJSONData(for result: ClaudeCredentialResult) -> Data? {
        var root: [String: Any] = [:]
        if let rawFileData = result.rawFileData,
           let object = try? JSONSerialization.jsonObject(with: rawFileData),
           let existing = object as? [String: Any] {
            root = existing
        }

        var oauth: [String: Any] = [
            "accessToken": result.oauth.accessToken,
        ]
        if let refreshToken = result.oauth.refreshToken {
            oauth["refreshToken"] = refreshToken
        }
        if let expiresAt = result.oauth.expiresAt {
            oauth["expiresAt"] = expiresAt
        }
        if let subscriptionType = result.oauth.subscriptionType {
            oauth["subscriptionType"] = subscriptionType
        }
        root["claudeAiOauth"] = oauth

        return try? JSONSerialization.data(withJSONObject: root, options: [.prettyPrinted, .sortedKeys])
    }

    private func parseExpiresAt(_ value: Any?) -> Double? {
        switch value {
        case let number as Double:
            return number
        case let number as Int:
            return Double(number)
        case let number as NSNumber:
            return number.doubleValue
        case let string as String:
            return Double(string)
        default:
            return nil
        }
    }

    private func trimmed(_ value: String?) -> String? {
        guard let value else {
            return nil
        }
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
