import Foundation
import AppKit
import Security

class CommandService {
    static let shared = CommandService()

    private init() {}

    func checkAppleEventsPermission() {
        let target = NSAppleEventDescriptor(bundleIdentifier: "com.apple.systemevents")
        let status = AEDeterminePermissionToAutomateTarget(target.aeDesc, typeWildCard, typeWildCard, true)
        if status == errAEEventNotPermitted {
            showPermissionDeniedAlert()
        }
    }

    func execute(_ command: Command) {
        let scriptSource = command.script

        DispatchQueue.main.async {
            if let script = NSAppleScript(source: scriptSource) {
                var error: NSDictionary?
                script.executeAndReturnError(&error)

                if let err = error {
                    let errNumber = err[NSAppleScriptErrorNumber] as? Int ?? 0
                    print("CommandService: AppleScript Error: \(err)")

                    if errNumber == errAEEventNotPermitted {
                        self.showPermissionDeniedAlert()
                    }
                }
            }
        }
    }

    private func showPermissionDeniedAlert() {
        let alert = NSAlert()
        alert.messageText = "Permission Required"
        alert.informativeText = "cmdp needs permission to control System Events. Please grant access in System Settings > Privacy & Security > Automation."
        alert.alertStyle = .warning
        alert.addButton(withTitle: "Open System Settings")
        alert.addButton(withTitle: "OK")

        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Automation") {
                NSWorkspace.shared.open(url)
            }
        }
    }
}
