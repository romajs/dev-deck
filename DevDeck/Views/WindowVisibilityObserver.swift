import AppKit
import SwiftUI

struct WindowVisibilityObserver: NSViewRepresentable {
    var autosaveName: String?
    let onChange: (Bool) -> Void

    func makeCoordinator() -> Coordinator {
        Coordinator(autosaveName: autosaveName, onChange: onChange)
    }

    func makeNSView(context: Context) -> NSView {
        let view = NSView()
        DispatchQueue.main.async {
            context.coordinator.attach(to: view.window)
        }
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {
        DispatchQueue.main.async {
            context.coordinator.attach(to: nsView.window)
        }
    }

    final class Coordinator {
        private let autosaveName: String?
        private let onChange: (Bool) -> Void
        private weak var window: NSWindow?
        private var observers: [NSObjectProtocol] = []

        init(autosaveName: String?, onChange: @escaping (Bool) -> Void) {
            self.autosaveName = autosaveName
            self.onChange = onChange
        }

        deinit {
            removeObservers()
        }

        func attach(to window: NSWindow?) {
            guard self.window !== window else {
                publishVisibility()
                return
            }

            removeObservers()
            self.window = window

            guard let window else {
                onChange(false)
                return
            }

            configurePersistence(for: window)

            let names: [Notification.Name] = [
                NSWindow.didMiniaturizeNotification,
                NSWindow.didDeminiaturizeNotification,
                NSWindow.didBecomeKeyNotification,
                NSWindow.didResignKeyNotification,
                NSWindow.willCloseNotification
            ]

            observers = names.map { name in
                NotificationCenter.default.addObserver(
                    forName: name,
                    object: window,
                    queue: .main
                ) { [weak self] _ in
                    self?.publishVisibility()
                }
            }

            publishVisibility()
        }

        private func configurePersistence(for window: NSWindow) {
            guard let autosaveName else {
                return
            }

            let identifier = NSUserInterfaceItemIdentifier(autosaveName)
            let frameAutosaveName = NSWindow.FrameAutosaveName(autosaveName)

            window.identifier = identifier
            window.isRestorable = true
            window.setFrameUsingName(frameAutosaveName, force: true)
            window.setFrameAutosaveName(frameAutosaveName)
        }

        private func publishVisibility() {
            guard let window else {
                onChange(false)
                return
            }

            onChange(window.isVisible && !window.isMiniaturized)
        }

        private func removeObservers() {
            for observer in observers {
                NotificationCenter.default.removeObserver(observer)
            }

            observers = []
        }
    }
}
