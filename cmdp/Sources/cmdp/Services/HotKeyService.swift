import AppKit
import HotKey

class HotKeyService {
    private var hotKeys: [HotKey] = []
    private var window: NSWindow?

    init(window: NSWindow?) {
        self.window = window
        setupHotKeys()
    }

    private func setupHotKeys() {
        // Register Cmd + Space
        let spaceHotKey = HotKey(key: .space, modifiers: [.command])
        spaceHotKey.keyDownHandler = { [weak self] in
            self?.toggleWindow()
        }

        hotKeys = [spaceHotKey]
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
