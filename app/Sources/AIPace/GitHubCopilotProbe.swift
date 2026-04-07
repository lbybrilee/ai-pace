import Foundation

@MainActor
final class GitHubCopilotProbe {
    private let credentialStore: GitHubCopilotCredentialStore
    private let apiClient: GitHubCopilotAPIClient
    private let calendar: Calendar
    private let webSession: GitHubCopilotWebSession

    init(
        credentialStore: GitHubCopilotCredentialStore = GitHubCopilotCredentialStore(),
        apiClient: GitHubCopilotAPIClient = GitHubCopilotAPIClient(),
        calendar: Calendar = .current,
        webSession: GitHubCopilotWebSession = GitHubCopilotWebSession()
    ) {
        self.credentialStore = credentialStore
        self.apiClient = apiClient
        self.calendar = calendar
        self.webSession = webSession
    }

    func fetch() async -> CopilotSnapshot {
        if let tokenSnapshot = await fetchViaToken() {
            return tokenSnapshot
        }

        return await webSession.fetchUsage()
    }

    private func fetchViaToken() async -> CopilotSnapshot? {
        do {
            guard let token = credentialStore.loadToken() else {
                return nil
            }

            let user = try await apiClient.fetchAuthenticatedUser(token)
            let components = calendar.dateComponents([.year, .month, .day], from: .now)
            guard
                let year = components.year,
                let month = components.month,
                let day = components.day
            else {
                throw ProcessRunnerError.invalidResponse("Could not determine the current date for GitHub Copilot usage.")
            }

            async let todayUsage = apiClient.fetchPremiumRequestUsage(
                token,
                user.login,
                year,
                month,
                day
            )
            async let monthUsage = apiClient.fetchPremiumRequestUsage(
                token,
                user.login,
                year,
                month,
                nil
            )

            let today = try await todayUsage
            let monthTotal = try await monthUsage

            return CopilotSnapshot(
                primary: CopilotUsageWindow(
                    kind: .month,
                    valueText: String(totalRequests(in: monthTotal)),
                    progressPercent: nil,
                    resetsAt: nil,
                    message: nil
                ),
                secondary: CopilotUsageWindow(
                    kind: .today,
                    valueText: String(totalRequests(in: today)),
                    progressPercent: nil,
                    resetsAt: nil,
                    message: nil
                ),
                detail: user.login,
                footer: nil
            )
        } catch {
            return nil
        }
    }

    func totalRequests(in response: GitHubPremiumRequestUsageResponse) -> Int {
        Int(response.usageItems.reduce(0) { partialResult, item in
            partialResult + (item.grossQuantity ?? item.netQuantity ?? 0)
        }.rounded())
    }

    nonisolated static func liveFetchAuthenticatedUser(token: String) async throws -> GitHubAuthenticatedUser {
        let request = try makeRequest(
            path: "/user",
            token: token
        )
        let data = try await perform(request, authenticationFailureMessage: "GitHub authentication failed.")
        return try JSONDecoder().decode(GitHubAuthenticatedUser.self, from: data)
    }

    nonisolated static func liveFetchPremiumRequestUsage(
        token: String,
        username: String,
        year: Int,
        month: Int,
        day: Int?
    ) async throws -> GitHubPremiumRequestUsageResponse {
        var queryItems = [
            URLQueryItem(name: "year", value: String(year)),
            URLQueryItem(name: "month", value: String(month)),
        ]
        if let day {
            queryItems.append(URLQueryItem(name: "day", value: String(day)))
        }

        let request = try makeRequest(
            path: "/users/\(username)/settings/billing/premium_request/usage",
            queryItems: queryItems,
            token: token
        )
        let data = try await perform(
            request,
            authenticationFailureMessage: "GitHub authentication failed.",
            forbiddenMessage: "GitHub token lacks the required plan:read permission, or this account cannot access the billing usage API."
        )
        return try JSONDecoder().decode(GitHubPremiumRequestUsageResponse.self, from: data)
    }

    private nonisolated static func makeRequest(
        path: String,
        queryItems: [URLQueryItem] = [],
        token: String
    ) throws -> URLRequest {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "api.github.com"
        components.path = path
        components.queryItems = queryItems.isEmpty ? nil : queryItems

        guard let url = components.url else {
            throw ProcessRunnerError.invalidResponse("GitHub API request URL was invalid.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "GET"
        request.timeoutInterval = 20
        request.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.setValue("2026-03-10", forHTTPHeaderField: "X-GitHub-Api-Version")
        request.setValue("AIPace", forHTTPHeaderField: "User-Agent")
        return request
    }

    private nonisolated static func perform(
        _ request: URLRequest,
        authenticationFailureMessage: String,
        forbiddenMessage: String? = nil
    ) async throws -> Data {
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else {
            throw ProcessRunnerError.invalidResponse("GitHub returned an invalid response.")
        }

        switch http.statusCode {
        case 200 ..< 300:
            return data
        case 401:
            throw ProcessRunnerError.invalidResponse(authenticationFailureMessage)
        case 403:
            if let forbiddenMessage {
                throw ProcessRunnerError.invalidResponse(forbiddenMessage)
            }
            throw ProcessRunnerError.invalidResponse("GitHub access was denied.")
        default:
            throw ProcessRunnerError.invalidResponse("GitHub API returned HTTP \(http.statusCode).")
        }
    }
}

struct GitHubCopilotAPIClient: Sendable {
    let fetchAuthenticatedUser: @Sendable (String) async throws -> GitHubAuthenticatedUser
    let fetchPremiumRequestUsage: @Sendable (String, String, Int, Int, Int?) async throws -> GitHubPremiumRequestUsageResponse

    init(
        fetchAuthenticatedUser: @escaping @Sendable (String) async throws -> GitHubAuthenticatedUser = GitHubCopilotProbe.liveFetchAuthenticatedUser(token:),
        fetchPremiumRequestUsage: @escaping @Sendable (String, String, Int, Int, Int?) async throws -> GitHubPremiumRequestUsageResponse = GitHubCopilotProbe.liveFetchPremiumRequestUsage(token:username:year:month:day:)
    ) {
        self.fetchAuthenticatedUser = fetchAuthenticatedUser
        self.fetchPremiumRequestUsage = fetchPremiumRequestUsage
    }
}

struct GitHubAuthenticatedUser: Decodable, Sendable {
    let login: String
}

struct GitHubPremiumRequestUsageResponse: Decodable, Sendable {
    let usageItems: [GitHubPremiumRequestUsageItem]

    enum CodingKeys: String, CodingKey {
        case usageItems = "usageItems"
    }
}

struct GitHubPremiumRequestUsageItem: Decodable, Sendable {
    let grossQuantity: Double?
    let netQuantity: Double?

    init(grossQuantity: Double?, netQuantity: Double? = nil) {
        self.grossQuantity = grossQuantity
        self.netQuantity = netQuantity
    }

    enum CodingKeys: String, CodingKey {
        case grossQuantity = "grossQuantity"
        case netQuantity = "netQuantity"
    }
}
