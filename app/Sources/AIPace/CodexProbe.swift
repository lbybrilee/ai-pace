import Foundation

struct CodexProbe: Sendable {
    func fetch() async -> ProviderSnapshot {
        do {
            let limits = try await fetchRateLimits()
            return ProviderSnapshot(
                provider: .codex,
                fiveHour: UsageWindow(
                    kind: .fiveHour,
                    usedPercentage: limits.primary?.usedPercent,
                    resetsAt: limits.primary?.resetsAt,
                    message: limits.primary == nil ? "No 5h limit returned." : nil
                ),
                weekly: UsageWindow(
                    kind: .weekly,
                    usedPercentage: limits.secondary?.usedPercent,
                    resetsAt: limits.secondary?.resetsAt,
                    message: limits.secondary == nil ? "No weekly limit returned." : nil
                ),
                detail: limits.planType.map { "Plan: \($0)" }
            )
        } catch {
            return ProviderSnapshot(
                provider: .codex,
                fiveHour: UsageWindow(kind: .fiveHour, usedPercentage: nil, resetsAt: nil, message: error.localizedDescription),
                weekly: UsageWindow(kind: .weekly, usedPercentage: nil, resetsAt: nil, message: error.localizedDescription),
                detail: nil
            )
        }
    }

    private func fetchRateLimits() async throws -> CodexRateLimits {
        guard let executable = ProcessRunner.which("codex") else {
            throw ProcessRunnerError.executableNotFound("codex")
        }

        let process = Process()
        let stdin = Pipe()
        let stdout = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = ["-s", "read-only", "-a", "untrusted", "app-server"]
        process.standardInput = stdin
        process.standardOutput = stdout
        process.standardError = FileHandle.nullDevice
        process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser
        process.environment = ProcessRunner.environment()

        try process.run()
        defer {
            if process.isRunning {
                process.terminate()
            }
        }

        try writeJSONLine([
            "jsonrpc": "2.0",
            "id": 1,
            "method": "initialize",
            "params": [
                "clientInfo": [
                    "name": "aipace",
                    "version": "0.1.0",
                ],
            ],
        ], to: stdin.fileHandleForWriting)

        _ = try await readResponse(
            withID: 1,
            from: stdout.fileHandleForReading.bytes.lines
        )

        try writeJSONLine([
            "jsonrpc": "2.0",
            "method": "initialized",
            "params": [:],
        ], to: stdin.fileHandleForWriting)

        try writeJSONLine([
            "jsonrpc": "2.0",
            "id": 2,
            "method": "account/rateLimits/read",
            "params": [:],
        ], to: stdin.fileHandleForWriting)

        let payload = try await readResponse(
            withID: 2,
            from: stdout.fileHandleForReading.bytes.lines
        )
        guard
            let result = payload["result"] as? [String: Any],
            let rateLimits = result["rateLimits"] as? [String: Any]
        else {
            throw ProcessRunnerError.invalidResponse("Codex rate limit response was missing result.rateLimits.")
        }

        return CodexRateLimits(
            primary: parseWindow(rateLimits["primary"]),
            secondary: parseWindow(rateLimits["secondary"]),
            planType: rateLimits["planType"] as? String
        )
    }

    func parseWindow(_ value: Any?) -> CodexRateLimitWindow? {
        guard let window = value as? [String: Any] else {
            return nil
        }
        guard let usedPercent = numericValue(window["usedPercent"]) else {
            return nil
        }
        let resetsAt = numericValue(window["resetsAt"]).map(Date.init(timeIntervalSince1970:))
        return CodexRateLimitWindow(usedPercent: usedPercent, resetsAt: resetsAt)
    }

    func numericValue(_ value: Any?) -> Double? {
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
}

struct CodexRateLimits {
    let primary: CodexRateLimitWindow?
    let secondary: CodexRateLimitWindow?
    let planType: String?
}

struct CodexRateLimitWindow: Sendable, Equatable {
    let usedPercent: Double
    let resetsAt: Date?
}

func writeJSONLine(_ object: [String: Any], to handle: FileHandle) throws {
    let data = try JSONSerialization.data(withJSONObject: object)
    handle.write(data)
    handle.write(Data([0x0A]))
}

func readResponse<S: AsyncSequence>(
    withID id: Int,
    from lines: S
) async throws -> [String: Any] where S.Element == String {
    for try await line in lines {
        guard !line.isEmpty, let data = line.data(using: .utf8) else {
            continue
        }
        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else {
            continue
        }

        guard let lineID = integerValue(json["id"]), lineID == id else {
            continue
        }

        if let error = json["error"] as? [String: Any],
           let message = error["message"] as? String {
            throw ProcessRunnerError.invalidResponse(message)
        }
        return json
    }
    throw ProcessRunnerError.invalidResponse("Codex app-server closed before returning response id \(id).")
}

func integerValue(_ value: Any?) -> Int? {
    switch value {
    case let number as Int:
        return number
    case let number as NSNumber:
        return number.intValue
    case let string as String:
        return Int(string)
    default:
        return nil
    }
}
