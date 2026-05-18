import SwiftUI
import AppKit

class SpotlightWindow: NSWindow {
    override var canBecomeKey: Bool {
        return true
    }
    
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 53 { // Escape
            NSApp.hide(nil)
        } else {
            super.keyDown(with: event)
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: SpotlightWindow?
    var hotKeyService: HotKeyService?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Create the spotlight-like window
        let contentView = ContentView()

        window = SpotlightWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 400),
            styleMask: [.fullSizeContentView, .borderless],
            backing: .buffered, defer: false)
        
        window?.setFrameAutosaveName("Main Window")
        
        // If no saved position, center it once
        if window?.frame.origin.x == 0 && window?.frame.origin.y == 0 {
            window?.center()
        }
        window?.contentView = NSHostingView(rootView: contentView)
        window?.isMovableByWindowBackground = true
        window?.backgroundColor = .clear
        window?.isOpaque = false
        window?.hasShadow = true
        
        // Ensure it stays on top like Spotlight
        window?.level = .floating
        
        // Initialize HotKey Service
        hotKeyService = HotKeyService(window: window)

        // Make key and bring to front
        window?.makeKeyAndOrderFront(nil)
        
        // Activate the app
        NSApp.activate(ignoringOtherApps: true)
    }
}

@main
struct cmdpApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate

    var body: some Scene {
        // We handle window creation in AppDelegate for more control, 
        // so we return an empty scene here or use a dummy.
        Settings {
            EmptyView()
        }
    }
}
