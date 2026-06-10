import SwiftUI

struct SearchBarView: View {
    @Binding var searchText: String
    let isActivityMonitorMode: Bool
    let isWebSearchMode: Bool
    let isShelfMode: Bool
    let isClipboardMode: Bool
    let isSettingsMode: Bool
    var isSearchFieldFocused: FocusState<Bool>.Binding
    let onClear: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isActivityMonitorMode ? Command.Symbols.activity : (isWebSearchMode ? Command.Symbols.web : (isShelfMode ? Command.Symbols.shelf : (isClipboardMode ? Command.Symbols.clipboard : (isSettingsMode ? Command.Symbols.settings : (searchText.hasPrefix("/") ? Command.Symbols.search : (searchText.hasPrefix(">") ? Command.Symbols.terminal : Command.Symbols.command)))))))
                .font(.system(size: 22, weight: .light))
                .foregroundColor(Theme.searchIconColor)
                .padding(.leading, 4)

            TextField(
                isActivityMonitorMode ? "Search processes..." : (isWebSearchMode ? "Search the web..." : (isShelfMode ? "Search shelf items..." : (isClipboardMode ? "Search clipboard history..." : (isSettingsMode ? "Settings" : (searchText.hasPrefix(">") ? "Search commands..." : "Search file, folder or command..."))))),
                text: $searchText
            )
            .textFieldStyle(.plain)
            .font(.system(size: 22, weight: .light))
            .focused(isSearchFieldFocused)

            if !searchText.isEmpty {
                Button(action: onClear) {
                    Image(systemName: Command.Symbols.xmark)
                        .foregroundColor(Theme.searchIconColor)
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(Theme.windowBackground)
    }
}
