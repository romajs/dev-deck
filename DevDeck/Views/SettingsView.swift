import SwiftUI

struct SettingsView: View {
    @ObservedObject var store: DevDeckStore
    var onDone: (() -> Void)?
    @State private var ignoredProcessesDraft = ""
    @State private var ignoredSupportPathsDraft = ""
    @State private var ignoredFilterDraftsLoaded = false

    var body: some View {
        Form {
            Section("Display") {
                Toggle(
                    "Show status bar icon",
                    isOn: Binding(
                        get: { store.settings.showStatusBarIcon },
                        set: { store.setStatusBarIconVisible($0) }
                    )
                )

                Toggle(
                    "Show only Dev apps",
                    isOn: Binding(
                        get: { store.settings.showOnlyDevApps },
                        set: { newValue in
                            store.settings.showOnlyDevApps = newValue

                            if newValue {
                                store.settings.showAllListeningPorts = false
                            }
                        }
                    )
                )
                Toggle(
                    "Show all listening ports",
                    isOn: Binding(
                        get: { store.settings.showAllListeningPorts },
                        set: { newValue in
                            store.settings.showAllListeningPorts = newValue

                            if newValue {
                                store.settings.showOnlyDevApps = false
                            }
                        }
                    )
                )
            }

            Section("Launch") {
                Toggle(
                    "Start at login",
                    isOn: Binding(
                        get: { store.settings.startAtLogin },
                        set: { store.setStartAtLogin($0) }
                    )
                )
            }

            Section("Ports") {
                ForEach(store.settings.configurableRuntimes, id: \.self) { runtime in
                    HStack(spacing: 12) {
                        Label {
                            Text(runtime.displayName)
                        } icon: {
                            RuntimeBadgeView(runtime: runtime)
                        }
                        .frame(width: 120, alignment: .leading)

                        TextField(
                            "Ports",
                            text: Binding(
                                get: { store.settings.portsText(for: runtime) },
                                set: { store.settings.setPortsText($0, for: runtime) }
                            )
                        )
                        .textFieldStyle(.roundedBorder)
                    }
                }

                Text("Comma-separated ports per runtime. These are used for candidate detection.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Ignored") {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Process names")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextEditor(text: $ignoredProcessesDraft)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 62)
                        .overlay(editorBorder)

                    Text("One process name per line or comma-separated.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Support paths")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)

                    TextEditor(text: $ignoredSupportPathsDraft)
                        .font(.system(size: 12, design: .monospaced))
                        .frame(minHeight: 118)
                        .overlay(editorBorder)

                    Text("Paths are ignored during project detection. Use one path per line; ~ is supported.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Button("Reset to defaults") {
                        resetIgnoredFilterDrafts()
                    }

                    Spacer()

                    Text(ignoredFiltersHaveUnsavedChanges ? "Unsaved changes" : "Saved")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Save") {
                        saveIgnoredFilterDrafts()
                    }
                    .disabled(!ignoredFiltersHaveUnsavedChanges)
                }

                Text("Reset only changes these fields. Click Save to apply the new ignored filters.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Refresh") {
                Toggle(
                    "Auto-refresh",
                    isOn: Binding(
                        get: { store.settings.autoRefresh },
                        set: { newValue in
                            store.settings.autoRefresh = newValue
                            store.restartAutoRefresh()
                        }
                    )
                )

                HStack {
                    Text("Interval")
                    Slider(
                        value: Binding(
                            get: { store.settings.refreshInterval },
                            set: { newValue in
                                store.settings.refreshInterval = newValue
                                store.restartAutoRefresh()
                            }
                        ),
                        in: 3...30,
                        step: 1
                    )
                    Text("\(Int(store.settings.refreshInterval))s")
                        .foregroundStyle(.secondary)
                        .frame(width: 34, alignment: .trailing)
                }
            }

            if let lastError = store.lastError {
                Section {
                    Label(lastError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            if let onDone {
                Section {
                    Button("Done", action: onDone)
                }
            }
        }
        .formStyle(.grouped)
        .padding(14)
        .onAppear {
            loadIgnoredFilterDraftsIfNeeded()
        }
    }

    private func binding<Value>(_ keyPath: ReferenceWritableKeyPath<AppSettings, Value>) -> Binding<Value> {
        Binding(
            get: { store.settings[keyPath: keyPath] },
            set: { store.settings[keyPath: keyPath] = $0 }
        )
    }

    private var ignoredFiltersHaveUnsavedChanges: Bool {
        ignoredProcessesDraft != store.settings.ignoredProcessesText ||
            ignoredSupportPathsDraft != store.settings.ignoredSupportPathsText
    }

    private var editorBorder: some View {
        RoundedRectangle(cornerRadius: 6, style: .continuous)
            .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
    }

    private func loadIgnoredFilterDraftsIfNeeded() {
        guard !ignoredFilterDraftsLoaded else {
            return
        }

        ignoredProcessesDraft = store.settings.ignoredProcessesText
        ignoredSupportPathsDraft = store.settings.ignoredSupportPathsText
        ignoredFilterDraftsLoaded = true
    }

    private func resetIgnoredFilterDrafts() {
        ignoredProcessesDraft = store.settings.defaultIgnoredProcessesText
        ignoredSupportPathsDraft = store.settings.defaultIgnoredSupportPathsText
    }

    private func saveIgnoredFilterDrafts() {
        store.applyIgnoredFilters(
            processesText: ignoredProcessesDraft,
            supportPathsText: ignoredSupportPathsDraft
        )
    }
}
