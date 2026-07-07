import SwiftUI

struct MainWindowView: View {
    @EnvironmentObject private var store: DevDeckStore
    @State private var selectedProcessID: DevProcess.ID?
    @State private var killCandidate: DevProcess?
    @State private var forceKillCandidate: DevProcess?

    var body: some View {
        HSplitView {
            sidebar
                .frame(minWidth: 220, idealWidth: 240, maxWidth: 340, maxHeight: .infinity)

            detail
                .frame(minWidth: 520, maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            WindowVisibilityObserver(autosaveName: "DevDeckMainWindowV3") { isVisible in
                store.setSurfaceVisible("main-window", visible: isVisible)
            }
        )
        .task {
            store.activate(surfaceID: "main-window")
            selectFirstProcessIfNeeded()
        }
        .onDisappear {
            store.setSurfaceVisible("main-window", visible: false)
        }
        .onChange(of: store.visibleProcesses.map(\.id)) { _, processIDs in
            if let selectedProcessID, processIDs.contains(selectedProcessID) {
                return
            }

            selectedProcessID = processIDs.first
        }
        .alert("Terminate process?", isPresented: killAlertBinding, presenting: killCandidate) { process in
            Button("Cancel", role: .cancel) {
                killCandidate = nil
            }
            Button("Terminate", role: .destructive) {
                Task {
                    let result = await store.terminate(process)
                    killCandidate = nil

                    if result == .stillRunning {
                        forceKillCandidate = process
                    }
                }
            }
        } message: { process in
            Text("Send SIGTERM to \(process.displayName) on :\(process.port) with PID \(process.pid).")
        }
        .alert("Process still running", isPresented: forceKillAlertBinding, presenting: forceKillCandidate) { process in
            Button("Cancel", role: .cancel) {
                forceKillCandidate = nil
            }
            Button("Force Kill", role: .destructive) {
                Task {
                    _ = await store.forceKill(process)
                    forceKillCandidate = nil
                }
            }
        } message: { process in
            Text("Send SIGKILL to PID \(process.pid). This cannot be undone.")
        }
    }

    private var sidebar: some View {
        VStack(spacing: 0) {
            windowHeader

            Divider()

            if let lastError = store.lastError {
                Label(lastError, systemImage: "exclamationmark.triangle")
                    .font(.caption)
                    .foregroundStyle(.red)
                    .padding(12)
                    .frame(maxWidth: .infinity, alignment: .leading)

                Divider()
            }

            if store.visibleProcesses.isEmpty {
                ContentUnavailableView(
                    store.isRefreshing ? "Scanning..." : "No Dev apps",
                    systemImage: store.isRefreshing ? "arrow.clockwise" : "network.slash",
                    description: Text(store.isRefreshing ? "Looking for local TCP listeners." : "No development listeners were detected.")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                VStack(spacing: 0) {
                    List(selection: $selectedProcessID) {
                        Section("Processes") {
                            ForEach(store.visibleProcesses) { process in
                                ProcessListItemView(process: process)
                                    .tag(process.id)
                            }
                        }
                    }
                    .listStyle(.sidebar)
                    .frame(maxHeight: .infinity)
                    .onChange(of: selectedProcessID) { _, _ in
                        store.windowShowingSettings = false
                    }

                }
            }
        }
    }

    private var windowHeader: some View {
        HStack(spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Processes")
                    .font(.headline)

                Text("\(store.visibleProcesses.count) \(store.settings.showAllListeningPorts ? "listeners" : "dev listeners")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if store.isRefreshing {
                ProgressView()
                    .controlSize(.small)
                    .frame(width: 22, height: 22)
            }

            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")

            Button {
                store.windowShowingSettings.toggle()
            } label: {
                Image(systemName: store.windowShowingSettings ? "sidebar.left" : "gearshape")
            }
            .buttonStyle(.borderless)
            .help(store.windowShowingSettings ? "Show details" : "Settings")
        }
        .padding(14)
    }

    @ViewBuilder
    private var detail: some View {
        if store.windowShowingSettings {
            windowSettings
        } else if let selectedProcess {
            ProcessDetailView(
                process: selectedProcess,
                store: store,
                onKill: { killCandidate = selectedProcess }
            )
        } else {
            ContentUnavailableView(
                "No process selected",
                systemImage: "info.circle",
                description: Text("Select a process to inspect details.")
            )
        }
    }

    private var windowSettings: some View {
        VStack(spacing: 0) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Settings")
                        .font(.title2.weight(.semibold))

                    Text("Display, refresh, ports, and launch behavior")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    store.windowShowingSettings = false
                } label: {
                    Label("Done", systemImage: "checkmark")
                }
                .controlSize(.small)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            SettingsView(store: store)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .ignoresSafeArea(.container, edges: .top)
    }

    private var selectedProcess: DevProcess? {
        if let selectedProcessID,
           let process = store.visibleProcesses.first(where: { $0.id == selectedProcessID }) {
            return process
        }

        return store.visibleProcesses.first
    }

    private func selectFirstProcessIfNeeded() {
        guard selectedProcessID == nil else {
            return
        }

        selectedProcessID = store.visibleProcesses.first?.id
    }

    private var killAlertBinding: Binding<Bool> {
        Binding(
            get: { killCandidate != nil },
            set: { isPresented in
                if !isPresented {
                    killCandidate = nil
                }
            }
        )
    }

    private var forceKillAlertBinding: Binding<Bool> {
        Binding(
            get: { forceKillCandidate != nil },
            set: { isPresented in
                if !isPresented {
                    forceKillCandidate = nil
                }
            }
        )
    }
}
