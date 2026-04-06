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
        which(executable, directories: pathDirectories())
    }

    static func environment() -> [String: String] {
        environment(base: ProcessInfo.processInfo.environment, pathDirectories: pathDirectories())
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
        process.environment = environment()

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

    static func which(_ executable: String, directories: [String]) -> String? {
        for directory in directories {
            let candidate = URL(fileURLWithPath: directory).appendingPathComponent(executable).path
            if FileManager.default.isExecutableFile(atPath: candidate) {
                return candidate
            }
        }
        return nil
    }

    static func environment(base: [String: String], pathDirectories: [String]) -> [String: String] {
        var env = base
        env["PATH"] = pathDirectories.joined(separator: ":")
        return env
    }

    static func pathDirectories(
        environment: [String: String] = ProcessInfo.processInfo.environment,
        loginShellPath: String? = ProcessRunner.loginShellPath(),
        homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> [String] {
        var directories: [String] = []

        func appendPathEntries(from path: String?) {
            guard let path else { return }
            for entry in path.split(separator: ":") {
                let directory = expandUserPath(String(entry), homeDirectory: homeDirectory)
                guard !directory.isEmpty else { continue }
                guard !directories.contains(directory) else { continue }
                directories.append(directory)
            }
        }

        appendPathEntries(from: environment["PATH"])
        appendPathEntries(from: loginShellPath)

        for directory in [
            "/opt/homebrew/bin",
            "/usr/local/bin",
            "/usr/bin",
            "/bin",
            "/usr/sbin",
            "/sbin",
            "~/bin",
            "~/.local/bin",
        ] {
            let expanded = expandUserPath(directory, homeDirectory: homeDirectory)
            guard !directories.contains(expanded) else { continue }
            directories.append(expanded)
        }

        return directories
    }

    private static func loginShellPath() -> String? {
        let shellCandidates = [
            ProcessInfo.processInfo.environment["SHELL"],
            "/bin/zsh",
            "/bin/bash",
        ].compactMap { $0 }

        for shell in shellCandidates where FileManager.default.isExecutableFile(atPath: shell) {
            let process = Process()
            let stdout = Pipe()

            process.executableURL = URL(fileURLWithPath: shell)
            process.arguments = ["-l", "-c", "printf %s \"$PATH\""]
            process.standardOutput = stdout
            process.standardError = FileHandle.nullDevice
            process.environment = ProcessInfo.processInfo.environment
            process.currentDirectoryURL = FileManager.default.homeDirectoryForCurrentUser

            do {
                try process.run()
                process.waitUntilExit()
                guard process.terminationStatus == 0 else { continue }

                let data = stdout.fileHandleForReading.readDataToEndOfFile()
                let path = String(decoding: data, as: UTF8.self)
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                if !path.isEmpty {
                    return path
                }
            } catch {
                continue
            }
        }

        return nil
    }

    static func expandUserPath(
        _ path: String,
        homeDirectory: String = FileManager.default.homeDirectoryForCurrentUser.path
    ) -> String {
        guard path.hasPrefix("~") else {
            return path
        }

        if path == "~" {
            return homeDirectory
        }
        if path.hasPrefix("~/") {
            return homeDirectory + String(path.dropFirst())
        }
        return path
    }
}
