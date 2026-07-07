import AppKit
import Combine
import Foundation
import ServiceManagement

@MainActor
final class DevDeckStore: ObservableObject {
    @Published private(set) var processes: [DevProcess] = []
    @Published private(set) var isRefreshing = false
    @Published var windowShowingSettings = false
    @Published var lastError: String?
    @Published private(set) var lastUpdated: Date?

    let settings = AppSettings()

    private let portScanner = PortScanner()
    private let processInspector = ProcessInspector()
    private let processKiller = ProcessKiller()
    private var autoRefreshTask: Task<Void, Never>?
    private var settingsCancellable: AnyCancellable?
    private var activeSurfaceIDs: Set<String> = []

    init() {
        settingsCancellable = settings.objectWillChange.sink { [weak self] _ in
            Task { @MainActor in
                self?.objectWillChange.send()
            }
        }
    }

    var visibleProcesses: [DevProcess] {
        let ignored = settings.ignoredProcesses

        return processes.filter { process in
            if ignored.contains(process.processName.lowercased()) {
                return false
            }

            if isIgnoredBySupportPath(process) {
                return false
            }

            if settings.showAllListeningPorts {
                return true
            }

            if settings.showOnlyDevApps {
                return process.isDevApp
            }

            return process.isDevApp || settings.allConfiguredPorts.contains(process.port) || process.project.framework != .other
        }
    }

    private func isIgnoredBySupportPath(_ process: DevProcess) -> Bool {
        let ignoredPaths = settings.ignoredSupportPaths
        guard !ignoredPaths.isEmpty else {
            return false
        }

        if let cwd = process.cwd, path(cwd, isUnderAny: ignoredPaths) {
            return true
        }

        if let projectFolder = process.project.projectFolder,
           path(projectFolder, isUnderAny: ignoredPaths) {
            return true
        }

        let lowerCommand = process.command.lowercased()
        return ignoredPaths.contains { prefix in
            commandText(lowerCommand, containsPathPrefix: prefix.lowercased())
        }
    }

    private func path(_ path: String, isUnderAny prefixes: [String]) -> Bool {
        let standardizedPath = NSString(string: path).standardizingPath

        return prefixes.contains { prefix in
            standardizedPath == prefix || standardizedPath.hasPrefix(prefix + "/")
        }
    }

    private func commandText(_ lowerText: String, containsPathPrefix lowerPrefix: String) -> Bool {
        lowerText == lowerPrefix ||
            lowerText.hasPrefix(lowerPrefix + "/") ||
            lowerText.hasPrefix(lowerPrefix + " ") ||
            lowerText.hasSuffix(" " + lowerPrefix) ||
            lowerText.contains(" " + lowerPrefix + "/") ||
            lowerText.contains("\"" + lowerPrefix + "/") ||
            lowerText.contains("'" + lowerPrefix + "/") ||
            lowerText.contains("=" + lowerPrefix + "/")
    }

    func activate(surfaceID: String) {
        activeSurfaceIDs.insert(surfaceID)

        if processes.isEmpty {
            Task { await refresh() }
        }

        restartAutoRefresh()
    }

    func setSurfaceVisible(_ surfaceID: String, visible: Bool) {
        let changed: Bool

        if visible {
            changed = activeSurfaceIDs.insert(surfaceID).inserted
        } else {
            changed = activeSurfaceIDs.remove(surfaceID) != nil
        }

        if changed {
            restartAutoRefresh()
        }
    }

    func restartAutoRefresh() {
        autoRefreshTask?.cancel()

        guard settings.autoRefresh, !activeSurfaceIDs.isEmpty else {
            return
        }

        autoRefreshTask = Task { [weak self] in
            while !Task.isCancelled {
                await self?.refresh()

                let interval = max(1, self?.settings.refreshInterval ?? 3)
                try? await Task.sleep(nanoseconds: UInt64(interval * 1_000_000_000))
            }
        }
    }

    func setStatusBarIconVisible(_ visible: Bool) {
        settings.showStatusBarIcon = visible

        if !visible {
            setSurfaceVisible("menu-bar-popover", visible: false)
        }
    }

    func applyIgnoredFilters(processesText: String, supportPathsText: String) {
        settings.setIgnoredFilters(
            processesText: processesText,
            supportPathsText: supportPathsText
        )

        Task { await refresh() }
    }

    func refresh() async {
        guard !isRefreshing else {
            return
        }

        isRefreshing = true
        defer { isRefreshing = false }

        let ports = await portScanner.scan()
        let inspected = await processInspector.inspect(
            ports,
            includeAll: settings.showAllListeningPorts,
            configuredDevPorts: settings.allConfiguredPorts,
            ignoredSupportPaths: settings.ignoredSupportPaths
        )

        let sorted = inspected.sorted { lhs, rhs in
            if lhs.isDevApp != rhs.isDevApp {
                return lhs.isDevApp && !rhs.isDevApp
            }

            if lhs.isLikelyDevelopment != rhs.isLikelyDevelopment {
                return lhs.isLikelyDevelopment && !rhs.isLikelyDevelopment
            }

            if lhs.port != rhs.port {
                return lhs.port < rhs.port
            }

            return lhs.displayName.localizedCaseInsensitiveCompare(rhs.displayName) == .orderedAscending
        }

        processes = sorted
        lastUpdated = Date()
        lastError = nil
    }

    func openInBrowser(_ process: DevProcess) {
        guard let url = URL(string: "http://localhost:\(process.port)") else {
            return
        }

        NSWorkspace.shared.open(url)
    }

    func terminate(_ process: DevProcess) async -> KillResult {
        let result = await processKiller.terminate(pid: process.pid)

        switch result {
        case .terminated:
            await refresh()
        case .failed(let message):
            lastError = message
        case .stillRunning:
            break
        }

        return result
    }

    func forceKill(_ process: DevProcess) async -> KillResult {
        let result = await processKiller.forceKill(pid: process.pid)

        switch result {
        case .terminated:
            await refresh()
        case .failed(let message):
            lastError = message
        case .stillRunning:
            lastError = "Process \(process.pid) is still running."
        }

        return result
    }

    func setStartAtLogin(_ enabled: Bool) {
        do {
            if enabled {
                try SMAppService.mainApp.register()
            } else {
                try SMAppService.mainApp.unregister()
            }

            settings.startAtLogin = enabled
            lastError = nil
        } catch {
            settings.startAtLogin = !enabled
            lastError = "Start at login could not be updated: \(error.localizedDescription)"
        }
    }
}
