import Foundation

final class GitInspector {
    func inspect(projectFolder: String?) async -> GitMetadata? {
        guard let projectFolder else {
            return nil
        }

        let directory = URL(fileURLWithPath: projectFolder, isDirectory: true)
        let branchResult = await Shell.run(
            "/usr/bin/git",
            arguments: ["rev-parse", "--abbrev-ref", "HEAD"],
            currentDirectoryURL: directory,
            timeout: 2
        )

        guard branchResult.succeeded else {
            return nil
        }

        let branch = branchResult.trimmedStdout
        guard !branch.isEmpty else {
            return nil
        }

        let statusResult = await Shell.run(
            "/usr/bin/git",
            arguments: ["status", "--porcelain"],
            currentDirectoryURL: directory,
            timeout: 2
        )

        let remoteResult = await Shell.run(
            "/usr/bin/git",
            arguments: ["remote", "get-url", "origin"],
            currentDirectoryURL: directory,
            timeout: 2
        )

        return GitMetadata(
            branch: branch,
            isDirty: !statusResult.trimmedStdout.isEmpty,
            remoteOriginURL: remoteResult.succeeded ? remoteResult.trimmedStdout : nil
        )
    }
}
