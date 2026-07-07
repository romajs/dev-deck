import Darwin
import Foundation

enum KillResult: Equatable {
    case terminated
    case stillRunning
    case failed(String)
}

final class ProcessKiller {
    func terminate(pid: Int32) async -> KillResult {
        guard kill(pid, SIGTERM) == 0 else {
            return .failed(errorMessage())
        }

        for _ in 0..<30 {
            if !isRunning(pid: pid) {
                return .terminated
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        return .stillRunning
    }

    func forceKill(pid: Int32) async -> KillResult {
        guard kill(pid, SIGKILL) == 0 else {
            return .failed(errorMessage())
        }

        for _ in 0..<10 {
            if !isRunning(pid: pid) {
                return .terminated
            }

            try? await Task.sleep(nanoseconds: 100_000_000)
        }

        return .stillRunning
    }

    private func isRunning(pid: Int32) -> Bool {
        kill(pid, 0) == 0 || errno == EPERM
    }

    private func errorMessage() -> String {
        String(cString: strerror(errno))
    }
}
