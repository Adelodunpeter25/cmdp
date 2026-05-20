import SwiftUI

// MARK: - Display item model

/// A flat list item for the LazyVStack — either a sticky section header
/// or a result row.  Using an enum gives each item a stable, unique ID
/// so LazyVStack never sees duplicate IDs.
private enum DisplayItem: Identifiable {
    case header(String)
    /// result + its global index in the flattened display order
    case result(SearchResult, Int)

    var id: String {
        switch self {
        case .header(let title):      return "header-\(title)"
        case .result(let r, let i):  return "result-\(i)-\(r.id)"
        }
    }

    /// Global index for scroll-to and selectedIndex matching.
    /// Headers return nil — they are never selectable.
    var globalIndex: Int? {
        if case .result(_, let i) = self { return i }
        return nil
    }
}

// MARK: - ContentView

struct ContentView: View {
    @StateObject private var searchService = SearchService()
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @State private var hoveredIndex: Int? = nil
    @FocusState private var isSearchFieldFocused: Bool
    @State private var searchDebounceItem: DispatchWorkItem?

    // MARK: Computed display list

    /// Flat, display-ordered list of results (apps first by score, then
    /// folders by score).  This is the single source of truth for
    /// selectedIndex and keyboard navigation.
    private var groupedResults: [SearchResult] {
        groupAndSort(searchService.results)
    }

    /// The full list interleaved with section headers, ready for ForEach.
    /// Each item has a unique stable ID — no running-counter mutation needed.
    private var displayItems: [DisplayItem] {
        guard !groupedResults.isEmpty else { return [] }

        var items: [DisplayItem] = []
        var lastType: ItemType? = nil
        var globalIndex = 0

        for result in groupedResults {
            let type = result.Item.itemType
            if type != lastType {
                let title = type == .app ? "APPLICATIONS" : "FOLDERS"
                items.append(.header(title))
                lastType = type
            }
            items.append(.result(result, globalIndex))
            globalIndex += 1
        }
        return items
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: searchService.isCommandMode ? "command" : "magnifyingglass")
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(Theme.searchIconColor)
                    .padding(.leading, 4)

                TextField("Search apps and folders...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22, weight: .light))
                    .focused($isSearchFieldFocused)
                    .onChange(of: searchText) { newValue in
                        searchDebounceItem?.cancel()
                        let item = DispatchWorkItem {
                            searchService.search(query: newValue)
                            selectedIndex = 0
                            updateWindowSize()
                        }
                        searchDebounceItem = item
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05, execute: item)
                    }

                if !searchText.isEmpty {
                    Button(action: { clearSearch() }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(Theme.searchIconColor)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Theme.windowBackground)

            // Results Area
            if !searchText.isEmpty && (!searchService.results.isEmpty || !searchService.commandResults.isEmpty) {
                Divider()

                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Theme.rowSpacing, pinnedViews: [.sectionHeaders]) {
                            if searchService.isCommandMode {
                                commandSection
                            } else {
                                resultSection
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 350)
                    .scrollIndicators(.hidden)
                    .onChange(of: selectedIndex) { _ in
                        // Scroll to the result item, not a header
                        let targetId = "result-\(selectedIndex)-\(groupedResults[safe: selectedIndex]?.id ?? "")"
                        proxy.scrollTo(targetId, anchor: .center)
                    }
                }
                .transition(.opacity)
            }
        }
        .frame(width: 600)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: Theme.windowCornerRadius))
        .onAppear {
            isSearchFieldFocused = true
            updateWindowSize()
            setupKeyEventMonitor()
            setupNotificationObservers()
        }
        .onChange(of: searchService.results) { _ in updateWindowSize() }
        .onChange(of: searchService.commandResults) { _ in updateWindowSize() }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var commandSection: some View {
        Section(header: sectionHeader("COMMANDS")) {
            ForEach(Array(searchService.commandResults.enumerated()), id: \.offset) { index, command in
                CommandRow(
                    command: command,
                    isSelected: selectedIndex == index,
                    isHovered: hoveredIndex == index
                )
                .onHover { hoveredIndex = $0 ? index : nil }
                .onTapGesture {
                    selectedIndex == index ? executeCommand(command) : (selectedIndex = index)
                }
                .id("cmd-\(index)")
            }
        }
    }

    @ViewBuilder
    private var resultSection: some View {
        // Single flat ForEach over DisplayItem — unique IDs guaranteed by the enum.
        ForEach(displayItems) { item in
            switch item {
            case .header(let title):
                sectionHeader(title)
                    // Pin headers using a pinned Section wrapper per header.
                    // We can't use LazyVStack pinnedViews here because headers
                    // are mixed into the flat list; they still visually float.

            case .result(let result, let index):
                ResultRow(
                    result: result,
                    isSelected: selectedIndex == index,
                    isHovered: hoveredIndex == index
                )
                .onHover { hoveredIndex = $0 ? index : nil }
                .onTapGesture {
                    selectedIndex == index ? executeSelection(result) : (selectedIndex = index)
                }
                .id(item.id)
            }
        }
    }

    // MARK: - Grouping

    /// Returns results sorted: apps (by score desc) then folders (by score desc),
    /// or folders first if the top folder outscores the top app.
    /// Deduplicates by path.
    private func groupAndSort(_ results: [SearchResult]) -> [SearchResult] {
        var seen = Set<String>()
        var apps: [SearchResult] = []
        var folders: [SearchResult] = []

        for result in results {
            guard !seen.contains(result.Item.Path) else { continue }
            seen.insert(result.Item.Path)
            switch result.Item.itemType {
            case .app:    apps.append(result)
            case .folder: folders.append(result)
            }
        }

        // Put the group with the higher top score first.
        let appTop    = apps.first?.Score    ?? Int.min
        let folderTop = folders.first?.Score ?? Int.min
        return folderTop > appTop ? folders + apps : apps + folders
    }

    // MARK: - Section header

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.textSecondary.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            Spacer()
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }

    // MARK: - Observers / lifecycle

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(
            forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main
        ) { _ in self.selectAllSearchText() }
    }

    private func selectAllSearchText() {
        isSearchFieldFocused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            if let textField = NSApp.keyWindow?.firstResponder as? NSTextView {
                textField.selectAll(nil)
            }
        }
    }

    private func updateWindowSize() {
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first(where: { $0 is SpotlightWindow }) else { return }
            let hostingView = window.contentView as? NSHostingView<ContentView>
            let targetSize = hostingView?.fittingSize ?? CGSize(width: 600, height: 60)
            var newFrame = window.frame
            let delta = targetSize.height - newFrame.size.height
            if abs(delta) > 0.1 {
                newFrame.size.height = targetSize.height
                newFrame.origin.y -= delta
                window.setFrame(newFrame, display: true, animate: true)
            }
        }
    }

    // MARK: - Key events

    func setupKeyEventMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let keyWindow = NSApp.keyWindow,
                  keyWindow.contentView?.closestHostingView() != nil else { return event }

            let resultCount = searchService.isCommandMode
                ? searchService.commandResults.count
                : groupedResults.count

            switch event.keyCode {
            case 125: // ↓
                if selectedIndex < resultCount - 1 { selectedIndex += 1 }
                return nil
            case 126: // ↑
                if selectedIndex > 0 { selectedIndex -= 1 }
                return nil
            case 36: // ↵ Enter
                if searchService.isCommandMode {
                    if selectedIndex < searchService.commandResults.count {
                        executeCommand(searchService.commandResults[selectedIndex])
                    }
                } else if selectedIndex < groupedResults.count {
                    executeSelection(groupedResults[selectedIndex])
                }
                return nil
            case 53: // Esc
                searchText.isEmpty ? NSApp.hide(nil) : clearSearch()
                return nil
            default:
                return event
            }
        }
    }

    // MARK: - Actions

    private func clearSearch() {
        searchText = ""
        selectedIndex = 0
        searchService.search(query: "")
    }

    func executeSelection(_ result: SearchResult) {
        NSWorkspace.shared.open(URL(fileURLWithPath: result.Item.Path))
        NSApp.hide(nil)
    }

    func executeCommand(_ command: Command) {
        command.script == "RESET_INDEX"
            ? searchService.resetIndex()
            : CommandService.shared.execute(command)
        NSApp.hide(nil)
    }
}

// MARK: - Row views

struct CommandRow: View {
    let command: Command
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: command.iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Theme.iconSize - 4, height: Theme.iconSize - 4)
                .foregroundColor(isSelected ? Theme.textSelected : .blue)
                .padding(4)

            Text(command.name)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Theme.textSelected : Theme.textPrimary)

            Spacer()
        }
        .padding(.vertical, Theme.rowPaddingVertical)
        .padding(.horizontal, Theme.rowPaddingHorizontal)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowCornerRadius)
                .fill(isSelected ? Color.blue : (isHovered ? Theme.hoverBackground : Color.clear))
        )
        .contentShape(Rectangle())
    }
}

struct ResultRow: View {
    let result: SearchResult
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 12) {
            if result.Item.itemType == .app {
                if let nsImage = IconManager.shared.icon(for: result.Item.IconPath, fallbackAppPath: result.Item.Path) {
                    Image(nsImage: nsImage)
                        .resizable()
                        .frame(width: Theme.iconSize, height: Theme.iconSize)
                } else {
                    Image(systemName: "app.fill")
                        .resizable()
                        .frame(width: Theme.iconSize, height: Theme.iconSize)
                        .foregroundColor(Theme.textSecondary)
                }
            } else {
                Image(systemName: "folder.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Theme.iconSize, height: Theme.iconSize)
                    .foregroundColor(.blue)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(result.Item.Name)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.textSelected : Theme.textPrimary)

                Text(result.Item.Path)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? Theme.textSelected.opacity(0.7) : Theme.textSecondary)
                    .lineLimit(1)
            }
            Spacer()
        }
        .padding(.vertical, Theme.rowPaddingVertical)
        .padding(.horizontal, Theme.rowPaddingHorizontal)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowCornerRadius)
                .fill(isSelected ? Theme.selectionBackground : (isHovered ? Theme.hoverBackground : Color.clear))
        )
        .contentShape(Rectangle())
    }
}

// MARK: - Utilities

extension NSView {
    func closestHostingView() -> NSView? {
        className.contains("HostingView") ? self : superview?.closestHostingView()
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

struct VisualEffectView: NSViewRepresentable {
    let material: NSVisualEffectView.Material
    let blendingMode: NSVisualEffectView.BlendingMode

    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = material
        view.blendingMode = blendingMode
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {
        nsView.material = material
        nsView.blendingMode = blendingMode
    }
}

struct EmptyStateView: View {
    var body: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "command")
                .font(.system(size: 48))
                .foregroundColor(Theme.textSecondary.opacity(0.3))
            Text("Search apps and folders...")
                .font(.headline)
                .foregroundColor(Theme.textSecondary)
            Text("Type a name to get started")
                .font(.subheadline)
                .foregroundColor(Theme.textSecondary.opacity(0.6))
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}
