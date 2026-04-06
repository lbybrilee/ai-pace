import Foundation

struct ClaudeProbe {
    private let credentialLoader: ClaudeCredentialLoader
    private let accountInfoResolver: ClaudeAccountInfoResolver

    init(
        credentialLoader: ClaudeCredentialLoader = ClaudeCredentialLoader(),
        accountInfoResolver: ClaudeAccountInfoResolver = ClaudeAccountInfoResolver()
    ) {
        self.credentialLoader = credentialLoader
        self.accountInfoResolver = accountInfoResolver
    }

    func fetch() async -> ProviderSnapshot {
        do {
            let accountInfo = accountInfoResolver.resolve()
            let resolution = credentialLoader.resolveCredentials()

            guard var credentials = resolution.credentials else {
                if let issue = resolution.issue {
                    throw ProcessRunnerError.invalidResponse(issue.message)
                }
                if let statusData = try? await fetchStatus(), statusData.loggedIn == true {
                    throw ProcessRunnerError.invalidResponse("Claude is logged in, but credentials could not be read from file, Keychain, or environment.")
                }
                throw ProcessRunnerError.invalidResponse("Claude credentials not found.")
            }

            if credentialLoader.needsRefresh(credentials.oauth) {
                if credentials.source == .environment {
                    // setup-token style credentials have no refresh flow; use them as-is
                } else if credentials.oauth.refreshToken != nil {
                    credentials = try await refreshToken(credentials)
                } else {
                    throw ProcessRunnerError.invalidResponse("Claude session expired; log in again.")
                }
            }

            let usage: ClaudeUsageResponse
            do {
                usage = try await fetchUsage(with: credentials.oauth.accessToken)
            } catch let error as ProcessRunnerError {
                if shouldRetryAfterAuthenticationError(error),
                   credentials.source != .environment,
                   credentials.oauth.refreshToken != nil {
                    credentials = try await refreshToken(credentials)
                    usage = try await fetchUsage(with: credentials.oauth.accessToken)
                } else {
                    throw error
                }
            }
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

    private func fetchStatus() async throws -> ClaudeAuthStatus {
        let output = try await ProcessRunner.run(
            executable: "claude",
            arguments: ["auth", "status", "--json"],
            timeout: 10
        )
        return try JSONDecoder().decode(ClaudeAuthStatus.self, from: Data(output.utf8))
    }

    private func refreshToken(_ credentials: ClaudeCredentialResult) async throws -> ClaudeCredentialResult {
        guard let refreshToken = credentials.oauth.refreshToken else {
            return credentials
        }

        var request = URLRequest(url: URL(string: "https://platform.claude.com/v1/oauth/token")!)
        request.httpMethod = "POST"
        request.timeoutInterval = 20
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: [
            "grant_type": "refresh_token",
            "refresh_token": refreshToken,
            "client_id": "9d1c250a-e61b-44d9-88ed-5944d1962f5e",
            "scope": "user:profile user:inference user:sessions:claude_code",
        ])

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProcessRunnerError.invalidResponse("Claude refresh endpoint returned an invalid response.")
        }

        if http.statusCode == 400 || http.statusCode == 401 {
            if let payload = try? JSONDecoder().decode(ClaudeRefreshErrorResponse.self, from: data),
               payload.error == "invalid_grant" {
                throw ProcessRunnerError.invalidResponse("Claude session expired; log in again.")
            }
            throw ProcessRunnerError.invalidResponse("Claude session expired; log in again.")
        }

        guard (200 ..< 300).contains(http.statusCode) else {
            throw ProcessRunnerError.invalidResponse("Claude token refresh failed with HTTP \(http.statusCode).")
        }

        let payload = try JSONDecoder().decode(ClaudeRefreshResponse.self, from: data)
        guard let accessToken = payload.accessToken?.trimmingCharacters(in: .whitespacesAndNewlines), !accessToken.isEmpty else {
            throw ProcessRunnerError.invalidResponse("Claude token refresh returned no access token.")
        }

        var updated = credentials
        updated.oauth.accessToken = accessToken
        if let refreshToken = payload.refreshToken {
            updated.oauth.refreshToken = refreshToken
        }
        if let expiresIn = payload.expiresIn {
            updated.oauth.expiresAt = Date().timeIntervalSince1970 * 1000 + Double(expiresIn) * 1000
        }
        credentialLoader.saveCredentials(updated)
        return updated
    }

    private func fetchUsage(with accessToken: String) async throws -> ClaudeUsageResponse {
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

    private func parseISODate(_ isoString: String?) -> Date? {
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

    private func detailText(from credentials: ClaudeCredentialResult, accountInfo: ClaudeAccountInfo?) -> String? {
        let tier = credentials.oauth.subscriptionType
            .map(formatSubscriptionType(_:))
        let identity = accountInfo?.displayName ?? accountInfo?.email ?? accountInfo?.organizationName

        return [tier, identity].compactMap { $0 }.joined(separator: " · ").nilIfEmpty
    }

    private func formatSubscriptionType(_ raw: String) -> String {
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

    private func shouldRetryAfterAuthenticationError(_ error: ProcessRunnerError) -> Bool {
        guard case .invalidResponse(let message) = error else {
            return false
        }
        return message == "Claude authentication failed."
    }
}

private struct ClaudeAuthStatus: Decodable {
    let loggedIn: Bool?
}

private struct ClaudeUsageResponse: Decodable {
    let fiveHour: ClaudeQuotaData?
    let sevenDay: ClaudeQuotaData?

    enum CodingKeys: String, CodingKey {
        case fiveHour = "five_hour"
        case sevenDay = "seven_day"
    }
}

private struct ClaudeQuotaData: Decodable {
    let utilization: Double?
    let resetsAt: String?

    enum CodingKeys: String, CodingKey {
        case utilization
        case resetsAt = "resets_at"
    }
}

private struct ClaudeRefreshResponse: Decodable {
    let accessToken: String?
    let refreshToken: String?
    let expiresIn: Int?

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case refreshToken = "refresh_token"
        case expiresIn = "expires_in"
    }
}

private struct ClaudeRefreshErrorResponse: Decodable {
    let error: String?
}

private extension String {
    var nilIfEmpty: String? {
        isEmpty ? nil : self
    }
}
