import Foundation
import AppKit

class CommandService {
    static let shared = CommandService()
    
    private init() {}
    
    func execute(_ command: Command) {
        let scriptSource = command.script
        
        // Some AppleScripts (especially those interacting with Finder or System Events UI)
        // work more reliably when executed on the main thread.
        DispatchQueue.main.async {
            if let script = NSAppleScript(source: scriptSource) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)
                
                if let err = error {
                    print("CommandService: AppleScript Error: \(err)")
                }
            }
        }
    }
}
