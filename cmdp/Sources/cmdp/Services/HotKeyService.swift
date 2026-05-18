import AppKit
import HotKey

class HotKeyService {
    private var hotKey: HotKey?
    private var window: NSWindow?

    init(window: NSWindow?) {
        self.window = window
        setupHotKey()
    }

    private func setupHotKey() {
        // Register Cmd + P (Key code 35 is 'P')
        hotKey = HotKey(key: .p, modifiers: [.command])
        
        hotKey?.keyDownHandler = { [weak self] in
            self?.toggleWindow()
        }
    }

    func toggleWindow() {
        guard let window = window else { return }

        if window.isVisible && NSApp.isActive {
            NSApp.hide(nil)
        } else {
            // Center the window before showing
            window.center()
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
