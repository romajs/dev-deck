import Darwin
import Foundation

struct ShellCommandResult: Sendable {
    let exitCode: Int32
    let stdout: String
    let stderr: String
    let timedOut: Bool

    var trimmedStdout: String {
        stdout.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var trimmedStderr: String {
        stderr.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var succeeded: Bool {
        exitCode == 0 && !timedOut
    }
}

enum Shell {
    static func run(
        _ executable: String,
        arguments: [String] = [],
        currentDirectoryURL: URL? = nil,
        timeout: TimeInterval = 5
    ) async -> ShellCommandResult {
        await Task.detached(priority: .utility) {
            runSync(
                executable,
                arguments: arguments,
                currentDirectoryURL: currentDirectoryURL,
                timeout: timeout
            )
        }.value
    }

    private static func runSync(
        _ executable: String,
        arguments: [String],
        currentDirectoryURL: URL?,
        timeout: TimeInterval
    ) -> ShellCommandResult {
            let process = Process()
            let stdoutPipe = Pipe()
            let stderrPipe = Pipe()

            process.executableURL = URL(fileURLWithPath: executable)
            process.arguments = arguments
            process.standardOutput = stdoutPipe
            process.standardError = stderrPipe

            if let currentDirectoryURL {
                process.currentDirectoryURL = currentDirectoryURL
            }

            do {
                try process.run()
            } catch {
                return ShellCommandResult(
                    exitCode: -1,
                    stdout: "",
                    stderr: error.localizedDescription,
                    timedOut: false
                )
            }

            let group = DispatchGroup()
            group.enter()

            DispatchQueue.global(qos: .utility).async {
                process.waitUntilExit()
                group.leave()
            }

            let timeoutResult = group.wait(timeout: .now() + timeout)
            let timedOut = timeoutResult == .timedOut

            if timedOut {
                process.terminate()

                if process.isRunning {
                    kill(process.processIdentifier, SIGKILL)
                }

                process.waitUntilExit()
            }

            let stdoutData = stdoutPipe.fileHandleForReading.readDataToEndOfFile()
            let stderrData = stderrPipe.fileHandleForReading.readDataToEndOfFile()

            return ShellCommandResult(
                exitCode: process.terminationStatus,
                stdout: String(data: stdoutData, encoding: .utf8) ?? "",
                stderr: String(data: stderrData, encoding: .utf8) ?? "",
                timedOut: timedOut
            )
    }
}
