import Foundation

struct Command: Identifiable, Equatable {
    let id: String
    let name: String
    let iconName: String // SF Symbol name
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
            script: "tell application \"Finder\" to sleep"
        ),
        Command(
            id: "restart",
            name: "Restart...",
            iconName: Symbols.restart,
            script: "tell application \"Finder\" to restart"
        ),
        Command(
            id: "shutdown",
            name: "Shut Down...",
            iconName: Symbols.shutdown,
            script: "tell application \"Finder\" to shut down"
        ),
        Command(
            id: "lock",
            name: "Lock Screen",
            iconName: Symbols.lock,
            script: "do shell script \"/usr/bin/pmset displaysleepnow\""
        ),
        Command(
            id: "empty-trash",
            name: "Empty Trash",
            iconName: Symbols.trash,
            script: "tell application \"Finder\"\nif (count of items in trash) > 0 then\nempty trash\nend if\nend tell"
        ),
        Command(
            id: "reset-index",
            name: "Reset Index",
            iconName: Symbols.resetIndex,
            script: "RESET_INDEX"
        ),
        Command(
            id: "nav-web",
            name: "Web Search Mode",
            iconName: Symbols.web,
            script: "INTERNAL_NAV"
        ),
        Command(
            id: "nav-shelf",
            name: "Shelf",
            iconName: Symbols.shelf,
            script: "INTERNAL_NAV"
        ),
        Command(
            id: "nav-clipboard",
            name: "Clipboard History",
            iconName: Symbols.clipboard,
            script: "INTERNAL_NAV"
        ),
        Command(
            id: "nav-activity",
            name: "Activity Monitor",
            iconName: Symbols.activity,
            script: "INTERNAL_NAV"
        ),
        Command(
            id: "nav-settings",
            name: "Settings",
            iconName: Symbols.settings,
            script: "INTERNAL_NAV"
        )
    ]
}
