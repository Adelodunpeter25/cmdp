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
        // Register Cmd + Space
        hotKey = HotKey(key: .space, modifiers: [.command])
        
        hotKey?.keyDownHandler = { [weak self] in
            self?.toggleWindow()
        }
    }

    func toggleWindow() {
        guard let window = window else { return }

        if window.isVisible && NSApp.isActive {
            NSApp.hide(nil)
        } else {
            // Bring to front at last known position
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
        }
    }
}
