import Foundation

final class ProcessInspector {
    private let metricsCollector: MetricsCollector
    private let devProjectDetector: DevProjectDetector
    private let gitInspector: GitInspector
    private var cwdCache: [Int32: CacheEntry<String?>] = [:]
    private var projectCache: [String: CacheEntry<ProjectMetadata>] = [:]
    private var gitCache: [String: CacheEntry<GitMetadata?>] = [:]
    private var runtimeVersionCache: [RuntimeKind: CacheEntry<String?>] = [:]

    private enum CacheTTL {
        static let cwd: TimeInterval = 30
        static let project: TimeInterval = 30
        static let git: TimeInterval = 30
        static let runtimeVersion: TimeInterval = 60
    }

    init(
        metricsCollector: MetricsCollector = MetricsCollector(),
        devProjectDetector: DevProjectDetector = DevProjectDetector(),
        gitInspector: GitInspector = GitInspector()
    ) {
        self.metricsCollector = metricsCollector
        self.devProjectDetector = devProjectDetector
        self.gitInspector = gitInspector
    }

    func inspect(
        _ listeningPorts: [ListeningPort],
        includeAll: Bool,
        configuredDevPorts: Set<Int>,
        ignoredSupportPaths: [String]
    ) async -> [DevProcess] {
        let uniquePIDs = Array(Set(listeningPorts.map(\.pid))).sorted()
        let metricsByPID = await metricsCollector.collect(pids: uniquePIDs)
        let candidatePIDs = Set(
            listeningPorts.compactMap { port -> Int32? in
                let command = metricsByPID[port.pid]?.command ?? port.command
                return shouldDeepInspect(
                    port,
                    command: command,
                    includeAll: includeAll,
                    configuredDevPorts: configuredDevPorts,
                    ignoredSupportPaths: ignoredSupportPaths
                ) ? port.pid : nil
            }
        )
        let cwdByPID = await cwd(for: Array(candidatePIDs))

        var inspected: [DevProcess] = []
        inspected.reserveCapacity(listeningPorts.count)

        for listeningPort in listeningPorts {
            let metrics = metricsByPID[listeningPort.pid]
            let command = metrics?.command.isEmpty == false ? metrics?.command ?? listeningPort.command : listeningPort.command
            let needsDeepInspection = shouldDeepInspect(
                listeningPort,
                command: command,
                includeAll: includeAll,
                configuredDevPorts: configuredDevPorts,
                ignoredSupportPaths: ignoredSupportPaths
            )

            guard needsDeepInspection else {
                inspected.append(
                    DevProcess(
                        listeningPort: listeningPort,
                        cwd: nil,
                        project: .unknown,
                        git: nil,
                        metrics: metrics,
                        runtimeVersion: nil,
                        isDevApp: false
                    )
                )
                continue
            }

            let cwd = cwdByPID[listeningPort.pid]
            let project = await detectProject(
                cwd: cwd,
                processName: listeningPort.processName,
                command: command,
                ignoredSupportPaths: ignoredSupportPaths
            )
            let isDevApp = devProjectDetector.isDevApp(
                processName: listeningPort.processName,
                command: command,
                project: project,
                ignoredSupportPaths: ignoredSupportPaths
            )
            let projectFolder = project.projectFolder ?? cwd
            let shouldInspectGit = isDevApp || project.framework != .other
            let git = shouldInspectGit ? await inspectGit(projectFolder: projectFolder) : nil
            let runtimeVersion = isDevApp ? await detectRuntimeVersion(for: project.runtime) : nil

            inspected.append(
                DevProcess(
                    listeningPort: listeningPort,
                    cwd: cwd,
                    project: project,
                    git: git,
                    metrics: metrics,
                    runtimeVersion: runtimeVersion,
                    isDevApp: isDevApp
                )
            )
        }

        return inspected
    }

    func inspect(_ listeningPort: ListeningPort) async -> DevProcess {
        await inspect(
            [listeningPort],
            includeAll: true,
            configuredDevPorts: RuntimeKind.allCommonPorts,
            ignoredSupportPaths: AppSettings.defaultIgnoredSupportPaths
        )[0]
    }

    private func shouldDeepInspect(
        _ listeningPort: ListeningPort,
        command: String,
        includeAll: Bool,
        configuredDevPorts: Set<Int>,
        ignoredSupportPaths: [String]
    ) -> Bool {
        if includeAll || configuredDevPorts.contains(listeningPort.port) {
            return true
        }

        return devProjectDetector.isDevApp(
            processName: listeningPort.processName,
            command: command,
            project: .unknown,
            ignoredSupportPaths: ignoredSupportPaths
        )
    }

    private func cwd(for pids: [Int32]) async -> [Int32: String] {
        let uniquePIDs = Array(Set(pids)).sorted()
        guard !uniquePIDs.isEmpty else {
            return [:]
        }

        var cwdByPID: [Int32: String] = [:]
        var missingPIDs: [Int32] = []

        for pid in uniquePIDs {
            if let entry = validEntry(cwdCache[pid]) {
                if let cwd = entry.value {
                    cwdByPID[pid] = cwd
                }
            } else {
                missingPIDs.append(pid)
            }
        }

        guard !missingPIDs.isEmpty else {
            return cwdByPID
        }

        let result = await Shell.run(
            "/usr/sbin/lsof",
            arguments: ["-a", "-p", missingPIDs.map(String.init).joined(separator: ","), "-d", "cwd", "-Fn"],
            timeout: 2
        )

        var currentPID: Int32?
        var freshCWDByPID: [Int32: String?] = Dictionary(uniqueKeysWithValues: missingPIDs.map { ($0, nil) })

        if result.succeeded || !result.stdout.isEmpty {
            for line in result.stdout.split(whereSeparator: \.isNewline) {
                if line.hasPrefix("p") {
                    currentPID = Int32(line.dropFirst())
                } else if line.hasPrefix("n"), let currentPID {
                    let path = line.dropFirst()
                    freshCWDByPID[currentPID] = path.isEmpty ? nil : String(path)
                }
            }
        }

        let expiry = Date().addingTimeInterval(CacheTTL.cwd)
        for (pid, cwd) in freshCWDByPID {
            cwdCache[pid] = CacheEntry(value: cwd, expiresAt: expiry)

            if let cwd {
                cwdByPID[pid] = cwd
            }
        }

        return cwdByPID
    }

    private func detectProject(
        cwd: String?,
        processName: String,
        command: String,
        ignoredSupportPaths: [String]
    ) async -> ProjectMetadata {
        let cacheKey = [
            cwd ?? "",
            processName,
            command,
            ignoredSupportPaths.joined(separator: "\u{1e}")
        ].joined(separator: "\u{1f}")

        if let entry = validEntry(projectCache[cacheKey]) {
            return entry.value
        }

        let project = devProjectDetector.detect(
            cwd: cwd,
            processName: processName,
            command: command,
            ignoredSupportPaths: ignoredSupportPaths
        )

        projectCache[cacheKey] = CacheEntry(value: project, expiresAt: Date().addingTimeInterval(CacheTTL.project))
        return project
    }

    private func inspectGit(projectFolder: String?) async -> GitMetadata? {
        guard let projectFolder, !projectFolder.isEmpty else {
            return nil
        }

        if let entry = validEntry(gitCache[projectFolder]) {
            return entry.value
        }

        let git = await gitInspector.inspect(projectFolder: projectFolder)
        gitCache[projectFolder] = CacheEntry(value: git, expiresAt: Date().addingTimeInterval(CacheTTL.git))
        return git
    }

    private func detectRuntimeVersion(for runtime: RuntimeKind) async -> String? {
        guard let versionCommand = runtime.versionCommand else {
            return nil
        }

        if let entry = validEntry(runtimeVersionCache[runtime]) {
            return entry.value
        }

        let result = await Shell.run(
            "/usr/bin/env",
            arguments: versionCommand,
            timeout: 2
        )

        guard result.succeeded || !result.stderr.isEmpty else {
            return nil
        }

        let version = result.trimmedStdout.isEmpty ? result.trimmedStderr : result.trimmedStdout
        let runtimeVersion = version.split(whereSeparator: \.isNewline).first.map(String.init)
        runtimeVersionCache[runtime] = CacheEntry(value: runtimeVersion, expiresAt: Date().addingTimeInterval(CacheTTL.runtimeVersion))
        return runtimeVersion
    }

    private func validEntry<Value>(_ entry: CacheEntry<Value>?) -> CacheEntry<Value>? {
        guard let entry, entry.expiresAt > Date() else {
            return nil
        }

        return entry
    }
}

private struct CacheEntry<Value> {
    let value: Value
    let expiresAt: Date
}
