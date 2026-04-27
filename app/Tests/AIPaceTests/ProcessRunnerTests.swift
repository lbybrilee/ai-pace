import Foundation
import Testing
@testable import AIPace

struct ProcessRunnerTests {
    @Test
    func expandUserPathUsesProvidedHomeDirectory() {
        #expect(ProcessRunner.expandUserPath("~/bin", homeDirectory: "/tmp/home") == "/tmp/home/bin")
        #expect(ProcessRunner.expandUserPath("/usr/bin", homeDirectory: "/tmp/home") == "/usr/bin")
    }

    @Test
    func pathDirectoriesDeduplicatesAndPreservesOrder() {
        let directories = ProcessRunner.pathDirectories(
            environment: ["PATH": "~/bin:/usr/bin:/usr/bin"],
            loginShellPath: "/custom/bin:~/.local/bin:/usr/bin",
            homeDirectory: "/tmp/home"
        )

        #expect(Array(directories.prefix(4)) == ["/tmp/home/bin", "/usr/bin", "/custom/bin", "/tmp/home/.local/bin"])
        #expect(directories.contains("/opt/homebrew/bin"))
    }

    @Test
    func environmentBuildsPathFromProvidedDirectories() {
        let environment = ProcessRunner.environment(
            base: ["LANG": "en_US.UTF-8"],
            pathDirectories: ["/usr/local/bin", "/usr/bin"]
        )

        #expect(environment["LANG"] == "en_US.UTF-8")
        #expect(environment["PATH"] == "/usr/local/bin:/usr/bin")
    }

    @Test
    func whichFindsExecutableInSpecifiedDirectories() throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }

        let executable = directory.appendingPathComponent("demo-tool")
        try Data("#!/bin/sh\nexit 0\n".utf8).write(to: executable)
        try FileManager.default.setAttributes([.posixPermissions: 0o755], ofItemAtPath: executable.path)

        #expect(ProcessRunner.which("demo-tool", directories: [directory.path]) == executable.path)
        #expect(ProcessRunner.which("missing-tool", directories: [directory.path]) == nil)
    }

    @Test
    func zshPathProbeUsesInteractiveLoginShell() {
        #expect(ProcessRunner.shellPathProbeArguments(for: "/bin/zsh").prefix(2) == ["-l", "-i"])
    }

    @Test
    func shellPathProbeOutputIgnoresStartupNoise() {
        let output = """
        startup warning
        __AIPACE_PATH__/Users/example/.nvm/versions/node/v24.14.1/bin:/usr/bin
        """

        #expect(ProcessRunner.shellPath(fromProbeOutput: output) == "/Users/example/.nvm/versions/node/v24.14.1/bin:/usr/bin")
    }
}
