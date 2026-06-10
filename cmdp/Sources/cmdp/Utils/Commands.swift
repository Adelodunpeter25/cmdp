import Foundation
import SwiftUI

struct Command: Identifiable, Equatable {
    let id: String
    let name: String
    let iconName: String // SF Symbol name
    let color: Color
    let script: String
    
    struct Symbols {
        static let sleep = "moon.fill"
        static let restart = "arrow.clockwise"
        static let shutdown = "power"
        static let lock = "lock.fill"
        static let trash = "trash"
        static let resetIndex = "arrow.counterclockwise.circle"
        static let web = "globe"
        static let shelf = "square.and.arrow.down.on.square"
        static let clipboard = "doc.on.clipboard"
        static let activity = "cpu"
        static let settings = "gearshape"
        static let search = "magnifyingglass"
        static let terminal = "terminal"
        static let command = "command"
        static let xmark = "xmark.circle.fill"
        static let memory = "memorychip"
    }
    
    static let allCommands: [Command] = [
        Command(
            id: "sleep",
            name: "Sleep",
            iconName: Symbols.sleep,
            color: .blue,
            script: "tell application \"Finder\" to sleep"
        ),
        Command(
            id: "restart",
            name: "Restart...",
            iconName: Symbols.restart,
            color: .orange,
            script: "tell application \"Finder\" to restart"
        ),
        Command(
            id: "shutdown",
            name: "Shut Down...",
            iconName: Symbols.shutdown,
            color: .red,
            script: "tell application \"Finder\" to shut down"
        ),
        Command(
            id: "lock",
            name: "Lock Screen",
            iconName: Symbols.lock,
            color: .purple,
            script: "do shell script \"/usr/bin/pmset displaysleepnow\""
        ),
        Command(
            id: "empty-trash",
            name: "Empty Trash",
            iconName: Symbols.trash,
            color: .gray,
            script: "tell application \"Finder\"\nif (count of items in trash) > 0 then\nempty trash\nend if\nend tell"
        ),
        Command(
            id: "reset-index",
            name: "Reset Index",
            iconName: Symbols.resetIndex,
            color: .teal,
            script: "RESET_INDEX"
        ),
        Command(
            id: "nav-shelf",
            name: "Shelf",
            iconName: Symbols.shelf,
            color: .orange,
            script: "INTERNAL_NAV"
        ),
        Command(
            id: "nav-clipboard",
            name: "Clipboard History",
            iconName: Symbols.clipboard,
            color: .green,
            script: "INTERNAL_NAV"
        ),
        Command(
            id: "nav-activity",
            name: "Activity Monitor",
            iconName: Symbols.activity,
            color: .purple,
            script: "INTERNAL_NAV"
        ),
        Command(
            id: "nav-settings",
            name: "Settings",
            iconName: Symbols.settings,
            color: .gray,
            script: "INTERNAL_NAV"
        )
    ]
}
