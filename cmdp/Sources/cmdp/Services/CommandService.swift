import Foundation
import AppKit

class CommandService {
    static let shared = CommandService()
    
    private init() {}
    
    func execute(_ command: Command) {
        let scriptSource = command.script
        
        // Execute AppleScript asynchronously to avoid blocking the UI
        DispatchQueue.global(qos: .userInitiated).async {
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
