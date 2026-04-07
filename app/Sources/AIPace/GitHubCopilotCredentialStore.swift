import Foundation

struct GitHubCopilotCredentialStore: Sendable {
    private let keychainService: String
    private let loadOverride: (@Sendable () -> String?)?
    private let saveOverride: (@Sendable (String) -> Void)?
    private let deleteOverride: (@Sendable () -> Void)?

    init(
        keychainService: String = "AIPace GitHub Copilot",
        loadOverride: (@Sendable () -> String?)? = nil,
        saveOverride: (@Sendable (String) -> Void)? = nil,
        deleteOverride: (@Sendable () -> Void)? = nil
    ) {
        self.keychainService = keychainService
        self.loadOverride = loadOverride
        self.saveOverride = saveOverride
        self.deleteOverride = deleteOverride
    }

    func loadToken() -> String? {
        if let loadOverride {
            return loadOverride()
        }

        do {
            let output = try ProcessRunner.runSync(
                executable: "/usr/bin/security",
                arguments: ["find-generic-password", "-s", keychainService, "-w"],
                input: nil,
                timeout: 10,
                currentDirectory: nil
            )
            return normalizeToken(output)
        } catch {
            return nil
        }
    }

    func saveToken(_ token: String) {
        let normalized = normalizeToken(token)
        guard let normalized else {
            deleteToken()
            return
        }

        if let saveOverride {
            saveOverride(normalized)
            return
        }

        _ = try? ProcessRunner.runSync(
            executable: "/usr/bin/security",
            arguments: ["delete-generic-password", "-s", keychainService],
            input: nil,
            timeout: 10,
            currentDirectory: nil
        )

        _ = try? ProcessRunner.runSync(
            executable: "/usr/bin/security",
            arguments: ["add-generic-password", "-s", keychainService, "-w", normalized],
            input: nil,
            timeout: 10,
            currentDirectory: nil
        )
    }

    func deleteToken() {
        if let deleteOverride {
            deleteOverride()
            return
        }

        _ = try? ProcessRunner.runSync(
            executable: "/usr/bin/security",
            arguments: ["delete-generic-password", "-s", keychainService],
            input: nil,
            timeout: 10,
            currentDirectory: nil
        )
    }

    func hasToken() -> Bool {
        loadToken() != nil
    }

    private func normalizeToken(_ token: String?) -> String? {
        guard let token else {
            return nil
        }
        let trimmed = token.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
