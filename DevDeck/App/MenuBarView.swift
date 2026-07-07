import AppKit
import SwiftUI

struct MenuBarView: View {
    @Environment(\.openWindow) private var openWindow
    @EnvironmentObject private var store: DevDeckStore
    @State private var selectedProcessID: DevProcess.ID?
    @State private var killCandidate: DevProcess?
    @State private var forceKillCandidate: DevProcess?

    var body: some View {
        VStack(spacing: 0) {
            header
            Divider()

            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .frame(width: 440, height: preferredPopoverHeight)
        .task {
            store.activate(surfaceID: "menu-bar-popover")
        }
        .onDisappear {
            store.setSurfaceVisible("menu-bar-popover", visible: false)
        }
        .onChange(of: store.visibleProcesses.map(\.id)) { _, processIDs in
            if let selectedProcessID, !processIDs.contains(selectedProcessID) {
                self.selectedProcessID = nil
            }
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

    @ViewBuilder
    private var content: some View {
        if let selectedProcess {
            ProcessDetailView(process: selectedProcess, store: store, compact: true) {
                selectedProcessID = nil
            } onKill: {
                killCandidate = selectedProcess
            }
        } else {
            processList
        }
    }

    private var header: some View {
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
                openMainWindow()
            } label: {
                Image(systemName: "macwindow")
            }
            .buttonStyle(.borderless)
            .help("Open window")

            Button {
                Task { await store.refresh() }
            } label: {
                Image(systemName: "arrow.clockwise")
            }
            .buttonStyle(.borderless)
            .help("Refresh")

            Button {
                openSettingsWindow()
            } label: {
                Image(systemName: "gearshape")
            }
            .buttonStyle(.borderless)
            .help("Open settings")

            Button {
                NSApplication.shared.terminate(nil)
            } label: {
                Image(systemName: "power")
            }
            .buttonStyle(.borderless)
            .help("Quit DevDeck")
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }

    private var processList: some View {
        ScrollView {
            LazyVStack(alignment: .leading, spacing: 0) {
                if let lastError = store.lastError {
                    Label(lastError, systemImage: "exclamationmark.triangle")
                        .font(.caption)
                        .foregroundStyle(.red)
                        .padding(10)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }

                if store.visibleProcesses.isEmpty {
                    ContentUnavailableView(
                        store.isRefreshing ? "Scanning..." : emptyTitle,
                        systemImage: store.isRefreshing ? "arrow.clockwise" : "network.slash",
                        description: Text(store.isRefreshing ? "Looking for local TCP listeners." : emptyDescription)
                    )
                    .frame(maxWidth: .infinity, minHeight: 220)
                } else {
                    ForEach(store.visibleProcesses) { process in
                        Button {
                            selectedProcessID = process.id
                        } label: {
                            HStack(alignment: .center, spacing: 8) {
                                ProcessListItemView(process: process, compactMetrics: true)

                                Spacer(minLength: 8)

                                Image(systemName: "chevron.right")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.tertiary)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)

                        if process.id != store.visibleProcesses.last?.id {
                            Divider()
                                .padding(.leading, 10)
                        }
                    }
                }
            }
            .padding(.vertical, 8)
        }
    }

    private var selectedProcess: DevProcess? {
        guard let selectedProcessID else {
            return nil
        }

        return store.visibleProcesses.first { $0.id == selectedProcessID }
    }

    private var emptyTitle: String {
        store.settings.showOnlyDevApps ? "No Dev apps" : "No listening ports"
    }

    private var emptyDescription: String {
        store.settings.showOnlyDevApps ? "No development listeners were detected." : "No matching local TCP listeners were detected."
    }

    private var preferredPopoverHeight: CGFloat {
        if selectedProcess != nil {
            let headerHeight: CGFloat = 82
            let metricsHeight: CGFloat = 58
            let rowHeight: CGFloat = 23
            let verticalPadding: CGFloat = 28
            let detailRows: CGFloat = 14

            return min(max(headerHeight + metricsHeight + detailRows * rowHeight + verticalPadding, 420), 540)
        }

        let headerHeight: CGFloat = 58
        let verticalPadding: CGFloat = 16
        let rowHeight: CGFloat = 82
        let errorHeight: CGFloat = store.lastError == nil ? 0 : 42
        let contentHeight = store.visibleProcesses.isEmpty ? 190 : CGFloat(store.visibleProcesses.count) * rowHeight
        return min(max(headerHeight + verticalPadding + errorHeight + contentHeight, 220), 540)
    }

    private func openMainWindow() {
        openWindow(id: "main-window")
        NSApp.activate(ignoringOtherApps: true)
    }

    private func openSettingsWindow() {
        selectedProcessID = nil
        store.windowShowingSettings = true
        openMainWindow()
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
