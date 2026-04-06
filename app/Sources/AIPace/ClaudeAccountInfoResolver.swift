import Foundation

struct ClaudeAccountInfo: Sendable, Equatable {
    let email: String?
    let displayName: String?
    let organizationName: String?
}

struct ClaudeAccountInfoResolver {
    private let configURL: URL

    init(configURL: URL? = nil) {
        self.configURL = configURL ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".claude.json")
    }

    func resolve() -> ClaudeAccountInfo? {
        guard
            FileManager.default.fileExists(atPath: configURL.path),
            let data = try? Data(contentsOf: configURL),
            let object = try? JSONSerialization.jsonObject(with: data),
            let root = object as? [String: Any],
            let oauthAccount = root["oauthAccount"] as? [String: Any]
        else {
            return nil
        }

        let email = oauthAccount["emailAddress"] as? String
        let displayName = oauthAccount["displayName"] as? String
        let organizationName = oauthAccount["organizationName"] as? String

        guard email != nil || displayName != nil || organizationName != nil else {
            return nil
        }

        return ClaudeAccountInfo(email: email, displayName: displayName, organizationName: organizationName)
    }
}
