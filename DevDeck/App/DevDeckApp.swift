import AppKit
import SwiftUI

final class AppDelegate: NSObject, NSApplicationDelegate {
    var reopenMainWindow: (() -> Void)?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.regular)
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        if !flag {
            reopenMainWindow?()
        }

        return true
    }
}

@main
struct DevDeckApp: App {
    @Environment(\.openWindow) private var openWindow
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate
    @StateObject private var store = DevDeckStore()

    @SceneBuilder
    var body: some Scene {
        mainWindow
        MenuBarExtra(
            "DevDeck",
            systemImage: "point.3.connected.trianglepath.dotted",
            isInserted: statusBarIconBinding
        ) {
            MenuBarView()
                .environmentObject(store)
                .frame(width: 440)
        }
        .menuBarExtraStyle(.window)
    }

    private var mainWindow: some Scene {
        Window("DevDeck", id: "main-window") {
            MainWindowView()
                .environmentObject(store)
                .frame(minWidth: 780, minHeight: 520)
                .onAppear {
                    appDelegate.reopenMainWindow = openMainWindow
                }
        }
        .defaultSize(width: 820, height: 574)
        .windowStyle(.hiddenTitleBar)
        .commands {
            CommandGroup(replacing: .appSettings) {
                Button("Settings...") {
                    openSettingsWindow()
                }
                .keyboardShortcut(",", modifiers: .command)
            }
        }
    }

    private var statusBarIconBinding: Binding<Bool> {
        Binding(
            get: { store.settings.showStatusBarIcon },
            set: { store.setStatusBarIconVisible($0) }
        )
    }

    private func openSettingsWindow() {
        store.windowShowingSettings = true
        openMainWindow()
    }

    private func openMainWindow() {
        openWindow(id: "main-window")
        NSApp.activate(ignoringOtherApps: true)
    }
}
