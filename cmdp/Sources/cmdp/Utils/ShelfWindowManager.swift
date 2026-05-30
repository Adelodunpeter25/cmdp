import SwiftUI
import AppKit

class ShelfWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
}

class ShelfWindowManager {
    static let shared = ShelfWindowManager()
    
    private var shelfWindow: ShelfWindow?
    
    func openShelfWindow() {
        if let window = shelfWindow {
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            return
        }
        
        let contentView = ShelfView()
        
        let window = ShelfWindow(
            contentRect: NSRect(x: 0, y: 0, width: 350, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
            backing: .buffered, defer: false)
        
        window.title = "File Shelf"
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isMovableByWindowBackground = true
        window.backgroundColor = .clear
        window.isOpaque = false
        window.hasShadow = true
        
        let hostingView = NSHostingView(rootView: contentView)
        window.contentView = hostingView
        window.setContentSize(NSSize(width: 350, height: 500))
        
        window.center()
        
        // Handle window closing
        NotificationCenter.default.addObserver(
            forName: NSWindow.willCloseNotification,
            object: window,
            queue: .main
        ) { [weak self] _ in
            self?.shelfWindow = nil
        }
        
        self.shelfWindow = window
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}
