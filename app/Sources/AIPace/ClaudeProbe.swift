import Foundation

struct ClaudeProbe: Sendable {
    private let credentialLoader: ClaudeCredentialLoader
    private let accountInfoResolver: ClaudeAccountInfoResolver
    private let apiClient: ClaudeAPIClient

    init(
        credentialLoader: ClaudeCredentialLoader = ClaudeCredentialLoader(),
        accountInfoResolver: ClaudeAccountInfoResolver = ClaudeAccountInfoResolver(),
        apiClient: ClaudeAPIClient = ClaudeAPIClient()
    ) {
        self.credentialLoader = credentialLoader
        self.accountInfoResolver = accountInfoResolver
        self.apiClient = apiClient
    }

    func fetch() async -> ProviderSnapshot {
        do {
            let accountInfo = accountInfoResolver.resolve()
            let resolution = credentialLoader.resolveCredentials()

            guard let credentials = resolution.credentials else {
                if let issue = resolution.issue {
                    throw ProcessRunnerError.invalidResponse(issue.message)
                }
                if let statusData = try? await apiClient.fetchStatus(), statusData.loggedIn == true {
                    throw ProcessRunnerError.invalidResponse("Claude is logged in, but credentials could not be read from file, Keychain, or environment.")
                }
                throw ProcessRunnerError.invalidResponse("Claude credentials not found.")
            }

            // Claude Code owns token rotation. A usage monitor must never consume or rewrite its refresh token.
            let usage = try await apiClient.fetchUsage(credentials.oauth.accessToken)
            return ProviderSnapshot(
                provider: .claude,
                fiveHour: UsageWindow(
                    kind: .fiveHour,
                    usedPercentage: usage.fiveHour?.utilization,
                    resetsAt: parseISODate(usage.fiveHour?.resetsAt),
                    message: usage.fiveHour == nil ? "No 5h limit returned." : nil
                ),
                weekly: UsageWindow(
                    kind: .weekly,
                    usedPercentage: usage.sevenDay?.utilization,
                    resetsAt: parseISODate(usage.sevenDay?.resetsAt),
                    message: usage.sevenDay == nil ? "No weekly limit returned." : nil
                ),
                detail: detailText(from: credentials, accountInfo: accountInfo)
            )
        } catch {
            let message = error.localizedDescription
            return ProviderSnapshot(
                provider: .claude,
                fiveHour: UsageWindow(kind: .fiveHour, usedPercentage: nil, resetsAt: nil, message: message),
                weekly: UsageWindow(kind: .weekly, usedPercentage: nil, resetsAt: nil, message: message),
                detail: nil
            )
        }
    }

    static func liveFetchStatus() async throws -> ClaudeAuthStatus {
        let output = try await ProcessRunner.run(
            executable: "claude",
            arguments: ["auth", "status", "--json"],
            timeout: 10
        )
        return try JSONDecoder().decode(ClaudeAuthStatus.self, from: Data(output.utf8))
    }

    static func liveFetchUsage(with accessToken: String) async throws -> ClaudeUsageResponse {
        var request = URLRequest(url: URL(string: "https://api.anthropic.com/api/oauth/usage")!)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(accessToken.trimmingCharacters(in: .whitespacesAndNewlines))", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("oauth-2025-04-20", forHTTPHeaderField: "anthropic-beta")
        request.setValue("AIPace", forHTTPHeaderField: "User-Agent")

        do {
            let (data, response) = try await URLSession.shared.data(for: request)
            guard let http = response as? HTTPURLResponse else {
                throw ProcessRunnerError.invalidResponse("Claude usage endpoint returned an invalid response.")
            }

            switch http.statusCode {
            case 200 ..< 300:
                return try JSONDecoder().decode(ClaudeUsageResponse.self, from: data)
            case 401, 403:
                throw ProcessRunnerError.invalidResponse("Claude authentication failed.")
            default:
                throw ProcessRunnerError.invalidResponse("Claude usage endpoint returned HTTP \(http.statusCode).")
            }
        } catch let error as ProcessRunnerError {
            throw error
        } catch {
            throw ProcessRunnerError.invalidResponse("Claude usage request failed: \(error.localizedDescription)")
        }
    }

    func parseISODate(_ isoString: String?) -> Date? {
        guard let isoString else {
            return nil
        }

        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = formatter.date(from: isoString) {
            return date
        }

        formatter.formatOptions = [.withInternetDateTime]
        return formatter.date(from: isoString)
    }

    func detailText(from credentials: ClaudeCredentialResult, accountInfo: ClaudeAccountInfo?) -> String? {
        let tier = credentials.oauth.subscriptionType
            .map(formatSubscriptionType(_:))
        let identity = accountInfo?.displayName ?? accountInfo?.email ?? accountInfo?.organizationName

        return [tier, identity].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
    }

    func formatSubscriptionType(_ raw: String) -> String {
        switch raw.lowercased() {
        case "claude_max", "max":
            return "Max"
        case "claude_pro", "pro":
            return "Pro"
        case "api", "claude_api":
            return "API"
        default:
            return raw
        }
    }

}

struct ClaudeAPIClient: Sendable {
    let fetchStatus: @Sendable () async throws -> ClaudeAuthStatus
    let fetchUsage: @Sendable (String) async throws -> ClaudeUsageResponse

    init(
        fetchStatus: @escaping @Sendable () async throws -> ClaudeAuthStatus = ClaudeProbe.liveFetchStatus,
        fetchUsage: @escaping @Sendable (String) async throws -> ClaudeUsageResponse = ClaudeProbe.liveFetchUsage(with:)
    ) {
        self.fetchStatus = fetchStatus
        self.fetchUsage = fetchUsage
    }
}

struct ClaudeAuthStatus: Decodable, Sendable {
    let loggedIn: Bool?
}

struct ClaudeUsageResponse: Decodable, Sendable {
    let fiveHour: ClaudeQuotaData?
    let sevenDay: ClaudeQuotaData?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

struct ClaudeQuotaData: Decodable, Sendable {
    let utilization: Double?
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
