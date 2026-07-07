import Foundation

struct DevProcess: Identifiable, Equatable {
    let listeningPort: ListeningPort
    let cwd: String?
    let project: ProjectMetadata
    let git: GitMetadata?
    let metrics: ProcessMetrics?
    let runtimeVersion: String?
    let isDevApp: Bool

    var id: String {
        listeningPort.id
    }

    var port: Int {
        listeningPort.port
    }

    var pid: Int32 {
        listeningPort.pid
    }

    var processName: String {
        listeningPort.processName
    }

    var command: String {
        let fullCommand = metrics?.command.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return fullCommand.isEmpty ? listeningPort.command : fullCommand
    }

    var displayName: String {
        if project.name != "Unknown project" {
            return project.name
        }

        if let cwd {
            let folderName = URL(fileURLWithPath: cwd).lastPathComponent
            if !folderName.isEmpty {
                return folderName
            }
        }

        return processName
    }

    var branchText: String {
        git?.branch ?? "No Git"
    }

    var isRuntimeCommonPort: Bool {
        project.runtime.commonPorts.contains(port)
    }

    var isLikelyDevelopment: Bool {
        isDevApp || isRuntimeCommonPort || project.framework != .other
    }
}
