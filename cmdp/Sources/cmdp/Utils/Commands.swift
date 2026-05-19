import Foundation

struct Command: Identifiable, Equatable {
    let id: String
    let name: String
    let iconName: String // SF Symbol name
    let script: String
    
    static let allCommands: [Command] = [
        Command(
            id: "sleep",
            name: "Sleep",
            iconName: "moon.fill",
            script: "tell application \"System Events\" to sleep"
        ),
        Command(
            id: "restart",
            name: "Restart...",
            iconName: "arrow.clockwise",
            script: "tell application \"System Events\" to restart"
        ),
        Command(
            id: "shutdown",
            name: "Shut Down...",
            iconName: "power",
            script: "tell application \"System Events\" to shut down"
        ),
        Command(
            id: "lock",
            name: "Lock Screen",
            iconName: "lock.fill",
            script: "tell application \"System Events\" to keystroke \"q\" using {command down, control down}"
        ),
        Command(
            id: "empty-trash",
            name: "Empty Trash",
            iconName: "trash",
            script: "tell application \"Finder\" to empty trash without confirmations"
        )
    ]
}
