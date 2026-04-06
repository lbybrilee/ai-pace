import Foundation

enum ProcessRunnerError: LocalizedError {
    case executableNotFound(String)
    case terminated(Int32, String)
    case invalidResponse(String)

    var errorDescription: String? {
        switch self {
        case .executableNotFound(let name):
            return "\(name) is not installed or not on PATH."
        case .terminated(let status, let output):
            if output.isEmpty {
                return "Process exited with status \(status)."
            }
            return output
        case .invalidResponse(let message):
            return message
        }
    }
}

enum ProcessRunner {
    static func which(_ executable: String) -> String? {
        let env = ProcessInfo.processInfo.environment
        let path = env["PATH"] ?? ""
        for directory in path.split(separator: ":") {
            let candidate = URL(fileURLWithPath: String(directory)).appendingPathComponent(executable).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    static func run(
        executable: String,
        arguments: [String],
        input: String? = nil,
        timeout: TimeInterval = 20,
        currentDirectory: URL? = nil
    ) async throws -> String {
        guard let resolved = which(executable) else {
            throw ProcessRunnerError.executableNotFound(executable)
        }

        return try await Task.detached(priority: .utility) {
            try runSync(
                executable: resolved,
                arguments: arguments,
                input: input,
                timeout: timeout,
                currentDirectory: currentDirectory
            )
        }.value
    }

    static func runSync(
        executable: String,
        arguments: [String],
        input: String?,
        timeout: TimeInterval?,
        currentDirectory: URL?
    ) throws -> String {
        let process = Process()
        let stdout = Pipe()
        let stderr = Pipe()
        let stdin = Pipe()

        process.executableURL = URL(fileURLWithPath: executable)
        process.arguments = arguments
        process.standardOutput = stdout
        process.standardError = stderr
        process.standardInput = stdin
        process.currentDirectoryURL = currentDirectory

        try process.run()

        if let input {
            stdin.fileHandleForWriting.write(Data(input.utf8))
        }
        try? stdin.fileHandleForWriting.close()

        if let timeout {
            let deadline = Date().addingTimeInterval(timeout)
            while process.isRunning && Date() < deadline {
                usleep(50_000)
            }

            if process.isRunning {
                process.terminate()
                usleep(100_000)
                if process.isRunning {
                    process.interrupt()
                }
            }
        } else {
            process.waitUntilExit()
        }

        let outputData = stdout.fileHandleForReading.readDataToEndOfFile()
        let errorData = stderr.fileHandleForReading.readDataToEndOfFile()
        let output = String(decoding: outputData, as: UTF8.self)
        let error = String(decoding: errorData, as: UTF8.self)

        guard process.terminationStatus == 0 else {
            throw ProcessRunnerError.terminated(process.terminationStatus, error.isEmpty ? output : error)
        }

        return output
    }
}
