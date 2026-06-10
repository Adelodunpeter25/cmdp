import SwiftUI
import AppKit
import Sparkle

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

class AppDelegate: NSObject, NSApplicationDelegate, SPUUpdaterDelegate {
    static var shared: AppDelegate?
    var window: SpotlightWindow?
    var hotKeyService: HotKeyService?
    var updaterController: SPUStandardUpdaterController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        AppDelegate.shared = self
        // Initialize Sparkle
        updaterController = SPUStandardUpdaterController(startingUpdater: true, updaterDelegate: self, userDriverDelegate: nil)

        // Create the spotlight-like window
        let contentView = ContentView()

        window = SpotlightWindow(
            contentRect: NSRect(x: 0, y: 0, width: 600, height: 64),
            styleMask: [.fullSizeContentView, .borderless],
            backing: .buffered, defer: false)
        
        window?.setFrameAutosaveName("Main Window")
        
        let hostingView = NSHostingView(rootView: contentView)
        window?.contentView = hostingView
        
        // Allow the window to resize based on its content (the SwiftUI view)
        window?.setContentSize(hostingView.fittingSize)
        
        // Re-center if it's the first run
        if window?.frame.origin.x == 0 && window?.frame.origin.y == 0 {
            window?.center()
        }

        window?.isMovableByWindowBackground = true
        window?.backgroundColor = .clear
        window?.isOpaque = false
        window?.hasShadow = true
        
        // Ensure it stays on top like Spotlight
        window?.level = .floating
        
        // Set collection behavior to appear on all spaces and in front of full-screen apps
        window?.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        
        // Initialize HotKey Service
        hotKeyService = HotKeyService(window: window)

        // Make key and bring to front
        window?.makeKeyAndOrderFront(nil)
        
        // Activate the app
        NSApp.activate(ignoringOtherApps: true)

        // Check Apple Events permission for system commands
        CommandService.shared.checkAppleEventsPermission()
    }

    func feedURLString(for updater: SPUUpdater) -> String? {
        let url: String
        #if arch(arm64)
        url = "https://github.com/Adelodunpeter25/cmdp/releases/latest/download/appcast-arm64.xml"
        #else
        url = "https://github.com/Adelodunpeter25/cmdp/releases/latest/download/appcast-x64.xml"
        #endif
        print("Sparkle: Providing feed URL: \(url)")
        return url
    }
    
    func updater(_ updater: SPUUpdater, didAbortWithError error: Error) {
        print("Sparkle: Update aborted with error: \(error.localizedDescription)")
    }
    
    func updater(_ updater: SPUUpdater, didFinishLoading appcast: SUAppcast) {
        print("Sparkle: Finished loading appcast with \(appcast.items.count) items")
    }
    
    func updaterDidNotFindUpdate(_ updater: SPUUpdater) {
        print("Sparkle: No update found")
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
