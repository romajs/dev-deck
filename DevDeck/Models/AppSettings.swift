import Foundation

final class AppSettings: ObservableObject {
    @Published var showOnlyDevApps: Bool {
        didSet { defaults.set(showOnlyDevApps, forKey: Keys.showOnlyDevApps) }
    }

    @Published var showAllListeningPorts: Bool {
        didSet { defaults.set(showAllListeningPorts, forKey: Keys.showAllListeningPorts) }
    }

    @Published var showStatusBarIcon: Bool {
        didSet { defaults.set(showStatusBarIcon, forKey: Keys.showStatusBarIcon) }
    }

    @Published var startAtLogin: Bool {
        didSet { defaults.set(startAtLogin, forKey: Keys.startAtLogin) }
    }

    @Published var autoRefresh: Bool {
        didSet { defaults.set(autoRefresh, forKey: Keys.autoRefresh) }
    }

    @Published var refreshInterval: Double {
        didSet { defaults.set(refreshInterval, forKey: Keys.refreshInterval) }
    }

    @Published private var runtimePortsTextByKey: [String: String] {
        didSet { defaults.set(runtimePortsTextByKey, forKey: Keys.runtimePortsTextByKey) }
    }

    @Published var ignoredProcessesText: String {
        didSet { defaults.set(ignoredProcessesText, forKey: Keys.ignoredProcessesText) }
    }

    @Published var ignoredSupportPathsText: String {
        didSet { defaults.set(ignoredSupportPathsText, forKey: Keys.ignoredSupportPathsText) }
    }

    var favoritePorts: [Int] {
        Array(allConfiguredPorts).sorted()
    }

    var allConfiguredPorts: Set<Int> {
        runtimePortsTextByKey.values.reduce(into: Set<Int>()) { ports, text in
            ports.formUnion(parsePorts(text))
        }
    }

    var configurableRuntimes: [RuntimeKind] {
        RuntimeKind.allCases.filter { $0 != .other }
    }

    func portsText(for runtime: RuntimeKind) -> String {
        runtimePortsTextByKey[runtime.rawValue] ?? defaultPortsText(for: runtime)
    }

    func setPortsText(_ text: String, for runtime: RuntimeKind) {
        runtimePortsTextByKey[runtime.rawValue] = text
    }

    func ports(for runtime: RuntimeKind) -> Set<Int> {
        Set(parsePorts(portsText(for: runtime)))
    }

    var ignoredProcesses: Set<String> {
        Set(
            Self.parseList(ignoredProcessesText)
                .map { $0.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() }
                .filter { !$0.isEmpty }
        )
    }

    var ignoredSupportPaths: [String] {
        Self.parseList(ignoredSupportPathsText)
            .map(Self.standardizePath)
            .filter { !$0.isEmpty }
            .uniqued()
    }

    var defaultIgnoredProcessesText: String {
        Self.defaultIgnoredProcessesText
    }

    var defaultIgnoredSupportPathsText: String {
        Self.defaultIgnoredSupportPathsText
    }

    static var defaultIgnoredSupportPaths: [String] {
        parseList(defaultIgnoredSupportPathsText)
            .map(standardizePath)
            .filter { !$0.isEmpty }
            .uniqued()
    }

    func setIgnoredFilters(processesText: String, supportPathsText: String) {
        ignoredProcessesText = processesText
        ignoredSupportPathsText = supportPathsText
    }

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults

        let settingsVersion = defaults.integer(forKey: Keys.settingsVersion)

        if settingsVersion < 2 {
            defaults.set(true, forKey: Keys.showOnlyDevApps)
            defaults.set(false, forKey: Keys.showAllListeningPorts)
        }

        if settingsVersion < 3 {
            if defaults.object(forKey: Keys.refreshInterval) == nil || defaults.double(forKey: Keys.refreshInterval) <= 3 {
                defaults.set(5, forKey: Keys.refreshInterval)
            }

            defaults.set(3, forKey: Keys.settingsVersion)
        }

        if settingsVersion < 4 {
            if defaults.string(forKey: Keys.favoritePortsText) == nil ||
                defaults.string(forKey: Keys.favoritePortsText) == Self.legacyFavoritePortsText {
                defaults.set(Self.defaultFavoritePortsText, forKey: Keys.favoritePortsText)
            }

            defaults.set(4, forKey: Keys.settingsVersion)
        }

        if settingsVersion < 5 {
            let currentPortsText = defaults.string(forKey: Keys.favoritePortsText)
            if currentPortsText == Self.legacyFavoritePortsText || currentPortsText == Self.defaultFavoritePortsText {
                defaults.set("", forKey: Keys.favoritePortsText)
            }

            defaults.set(5, forKey: Keys.settingsVersion)
        }

        if settingsVersion < 6 {
            var runtimePorts = Self.defaultRuntimePortsTextByKey
            let legacyExtraPortsText = defaults.string(forKey: Keys.favoritePortsText) ?? ""

            if !legacyExtraPortsText.isEmpty,
               legacyExtraPortsText != Self.legacyFavoritePortsText,
               legacyExtraPortsText != Self.defaultFavoritePortsText {
                runtimePorts[RuntimeKind.other.rawValue] = legacyExtraPortsText
            }

            defaults.set(runtimePorts, forKey: Keys.runtimePortsTextByKey)
            defaults.set(6, forKey: Keys.settingsVersion)
        }

        if settingsVersion < 7 {
            if defaults.object(forKey: Keys.ignoredProcessesText) == nil {
                defaults.set(Self.defaultIgnoredProcessesText, forKey: Keys.ignoredProcessesText)
            }

            if defaults.object(forKey: Keys.ignoredSupportPathsText) == nil {
                defaults.set(Self.defaultIgnoredSupportPathsText, forKey: Keys.ignoredSupportPathsText)
            }

            defaults.set(7, forKey: Keys.settingsVersion)
        }

        if defaults.object(forKey: Keys.showOnlyDevApps) == nil,
           let oldNodeOnly = defaults.object(forKey: Keys.showOnlyNodeApps) as? Bool {
            defaults.set(oldNodeOnly, forKey: Keys.showOnlyDevApps)
        }

        showOnlyDevApps = defaults.object(forKey: Keys.showOnlyDevApps) as? Bool ?? true
        showAllListeningPorts = defaults.object(forKey: Keys.showAllListeningPorts) as? Bool ?? false
        showStatusBarIcon = defaults.object(forKey: Keys.showStatusBarIcon) as? Bool ?? true
        startAtLogin = defaults.object(forKey: Keys.startAtLogin) as? Bool ?? false
        autoRefresh = defaults.object(forKey: Keys.autoRefresh) as? Bool ?? true
        refreshInterval = defaults.object(forKey: Keys.refreshInterval) as? Double ?? 5
        runtimePortsTextByKey = defaults.dictionary(forKey: Keys.runtimePortsTextByKey) as? [String: String] ?? Self.defaultRuntimePortsTextByKey
        ignoredProcessesText = defaults.string(forKey: Keys.ignoredProcessesText) ?? Self.defaultIgnoredProcessesText
        ignoredSupportPathsText = defaults.string(forKey: Keys.ignoredSupportPathsText) ?? Self.defaultIgnoredSupportPathsText
    }

    private func defaultPortsText(for runtime: RuntimeKind) -> String {
        runtime.commonPorts.sorted().map(String.init).joined(separator: ",")
    }

    private func parsePorts(_ text: String) -> [Int] {
        text
            .split(separator: ",")
            .compactMap { Int($0.trimmingCharacters(in: .whitespacesAndNewlines)) }
            .filter { (1...65_535).contains($0) }
    }

    private static func parseList(_ text: String) -> [String] {
        text
            .split { character in
                character == "," || character.isNewline
            }
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    private static func standardizePath(_ path: String) -> String {
        let expandedPath = NSString(string: path).expandingTildeInPath
        return NSString(string: expandedPath).standardizingPath
    }

    private enum Keys {
        static let settingsVersion = "settingsVersion"
        static let showOnlyDevApps = "showOnlyDevApps"
        static let showOnlyNodeApps = "showOnlyNodeApps"
        static let showAllListeningPorts = "showAllListeningPorts"
        static let showStatusBarIcon = "showStatusBarIcon"
        static let startAtLogin = "startAtLogin"
        static let autoRefresh = "autoRefresh"
        static let refreshInterval = "refreshInterval"
        static let favoritePortsText = "favoritePortsText"
        static let runtimePortsTextByKey = "runtimePortsTextByKey"
        static let ignoredProcessesText = "ignoredProcessesText"
        static let ignoredSupportPathsText = "ignoredSupportPathsText"
    }

    private static let legacyFavoritePortsText = "3000,3001,3002,5173,4173,8080,4000,5000,6006,9229"
    private static let defaultIgnoredProcessesText = ""
    private static let defaultIgnoredSupportPathsText = """
    ~/Library
    /Library
    /System
    /Applications
    /private/var/folders
    /var/folders
    """
    private static let defaultFavoritePortsText = RuntimeKind.allCommonPorts.sorted().map(String.init).joined(separator: ",")
    private static let defaultRuntimePortsTextByKey = Dictionary(
        uniqueKeysWithValues: RuntimeKind.allCases.map { runtime in
            (
                runtime.rawValue,
                runtime.commonPorts.sorted().map(String.init).joined(separator: ",")
            )
        }
    )
}

private extension Array where Element: Hashable {
    func uniqued() -> [Element] {
        var seen: Set<Element> = []
        return filter { seen.insert($0).inserted }
    }
}
