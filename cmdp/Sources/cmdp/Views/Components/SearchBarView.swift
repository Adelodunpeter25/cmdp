import SwiftUI

struct SearchBarView: View {
    @Binding var searchText: String
    let isActivityMonitorMode: Bool
    let isWebSearchMode: Bool
    let isShelfMode: Bool
    let isClipboardMode: Bool
    var isSearchFieldFocused: FocusState<Bool>.Binding
    let onClear: () -> Void

    var body: some View {
        HStack {
            Image(systemName: isActivityMonitorMode ? "cpu" : (isWebSearchMode ? "globe" : (isShelfMode ? "square.and.arrow.down.on.square" : (isClipboardMode ? "doc.on.clipboard" : (searchText.hasPrefix("/") ? "magnifyingglass" : "command")))))
                .font(.system(size: 22, weight: .light))
                .foregroundColor(Theme.searchIconColor)
                .padding(.leading, 4)

            TextField(
                isActivityMonitorMode ? "Search processes..." : (isWebSearchMode ? "Search the web..." : (isShelfMode ? "Search shelf items..." : (isClipboardMode ? "Search clipboard history..." : "Search file, folder or command..."))),
                text: $searchText
            )
            .textFieldStyle(.plain)
            .font(.system(size: 22, weight: .light))
            .focused(isSearchFieldFocused)

            if !searchText.isEmpty {
                Button(action: onClear) {
                    Image(systemName: "xmark.circle.fill")
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
