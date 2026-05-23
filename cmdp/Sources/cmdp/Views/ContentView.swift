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
    @StateObject private var processService = ProcessService()
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @State private var hoveredIndex: Int? = nil
    @State private var activeWebURL: URL? = nil
    @State private var isWebSearchMode: Bool = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var searchDebounceItem: DispatchWorkItem?

    // MARK: Computed display list

    /// Flat, display-ordered list of results (apps first by score, then
    /// folders by score).  This is the single source of truth for
    /// selectedIndex and keyboard navigation.
    private var groupedResults: [SearchResult] {
        if searchText.hasPrefix("/") {
            return searchService.results
        }
        return groupAndSort(searchService.results)
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
                let title = type == .app ? "APPLICATIONS" : (type == .folder ? "FOLDERS" : "COMMANDS")
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
                Image(systemName: isWebSearchMode ? "globe" : (searchText.hasPrefix("/") ? "magnifyingglass" : "command"))
                    .font(.system(size: 22, weight: .light))
                    .foregroundColor(Theme.searchIconColor)
                    .padding(.leading, 4)

                TextField(isWebSearchMode ? "Search the web..." : "Search file, folder or command...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.system(size: 22, weight: .light))
                    .focused($isSearchFieldFocused)
                    .onChange(of: searchText) { newValue in
                        searchDebounceItem?.cancel()

                        if activeWebURL != nil {
                            activeWebURL = nil
                        }

                        if isWebSearchMode {
                            selectedIndex = 0
                            updateWindowSize()
                            return
                        }

                        if newValue.isEmpty {
                            processService.startPolling()
                        } else {
                            processService.stopPolling()
                        }
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

            // Results Area & Dashboard Empty State
            if isWebSearchMode {
                if let webURL = activeWebURL {
                    Divider()
                    WebView(url: webURL)
                        .frame(height: 400)
                        .transition(.opacity)
                } else if !searchText.isEmpty {
                    Divider()
                    VStack(spacing: 0) {
                        WebSearchRow(
                            query: searchText,
                            isSelected: selectedIndex == 0,
                            isHovered: hoveredIndex == 0
                        )
                        .onHover { hoveredIndex = $0 ? 0 : nil }
                        .onTapGesture {
                            if let url = WebService.shared.searchURL(for: searchText) {
                                activeWebURL = url
                            }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                    .transition(.opacity)
                }
            } else {
                if !searchText.isEmpty {
                    Divider()
                    if searchText.hasPrefix("/") {
                        FileSearchView(
                            results: groupedResults,
                            selectedIndex: selectedIndex,
                            hoveredIndex: $hoveredIndex,
                            onTapRow: { index, result in
                                if selectedIndex == index {
                                    executeSelection(result)
                                } else {
                                    selectedIndex = index
                                }
                            }
                        )
                        .transition(.opacity)
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView {
                                LazyVStack(spacing: Theme.rowSpacing, pinnedViews: [.sectionHeaders]) {
                                    resultSection
                                }
                                .padding(.horizontal, 8)
                                .padding(.vertical, 8)
                            }
                            .frame(maxHeight: 350)
                            .scrollIndicators(.hidden)
                            .onChange(of: selectedIndex) { _ in
                                let targetId = "result-\(selectedIndex)-\(groupedResults[safe: selectedIndex]?.id ?? "")"
                                proxy.scrollTo(targetId, anchor: .center)
                            }
                        }
                        .transition(.opacity)
                    }
                } else {
                    Divider()
                    VStack(spacing: 0) {
                        WebSearchCard(
                            isSelected: selectedIndex == 0,
                            isHovered: hoveredIndex == 0
                        )
                        .onHover { hoveredIndex = $0 ? 0 : nil }
                        .onTapGesture {
                            isWebSearchMode = true
                            searchText = ""
                            selectedIndex = 0
                        }
                        .padding(.horizontal, 8)
                        .padding(.top, 8)

                        if let stats = processService.systemStats {
                            ProcessCard(stats: stats)
                                .transition(.opacity)
                        } else {
                            HStack {
                                Spacer()
                                ProgressView()
                                    .scaleEffect(0.8)
                                    .padding()
                                Text("Loading system stats...")
                                    .font(.system(size: 12))
                                    .foregroundColor(Theme.textSecondary)
                                Spacer()
                            }
                            .frame(height: 140)
                        }
                    }
                }
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
            if searchText.isEmpty {
                processService.startPolling()
            }
        }
        .onDisappear {
            processService.stopPolling()
        }
        .onChange(of: searchService.results) { _ in updateWindowSize() }
        .onChange(of: processService.systemStats) { _ in updateWindowSize() }
        .onChange(of: activeWebURL) { _ in updateWindowSize() }
        .onChange(of: isWebSearchMode) { _ in updateWindowSize() }
    }

    // MARK: - Sub-views

    @ViewBuilder
    private var resultSection: some View {
        // Single flat ForEach over DisplayItem — unique IDs guaranteed by the enum.
        ForEach(displayItems) { item in
            switch item {
            case .header(let title):
                sectionHeader(title)

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

    private func groupAndSort(_ results: [SearchResult]) -> [SearchResult] {
        var seen = Set<String>()
        var apps: [SearchResult] = []
        var folders: [SearchResult] = []
        var commands: [SearchResult] = []

        for result in results {
            guard !seen.contains(result.Item.Path) else { continue }
            seen.insert(result.Item.Path)
            switch result.Item.itemType {
            case .app:     apps.append(result)
            case .folder:  folders.append(result)
            case .command: commands.append(result)
            case .file:    break
            }
        }

        // Put the group with the higher top score first.
        let appTop     = apps.first?.Score     ?? Int.min
        let folderTop  = folders.first?.Score  ?? Int.min
        let commandTop = commands.first?.Score ?? Int.min

        var groups = [
            (type: ItemType.app, items: apps, topScore: appTop),
            (type: ItemType.folder, items: folders, topScore: folderTop),
            (type: ItemType.command, items: commands, topScore: commandTop)
        ]

        groups.sort { $0.topScore > $1.topScore }

        return groups.flatMap { $0.items }
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
        ) { _ in
            self.selectAllSearchText()
            if self.searchText.isEmpty {
                self.processService.startPolling()
            }
        }
        
        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification, object: nil, queue: .main
        ) { _ in
            self.processService.stopPolling()
        }
    }

    private func selectAllSearchText() {
        isSearchFieldFocused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            if let textView = NSApp.keyWindow?.firstResponder as? NSTextView {
                let text = textView.string
                if text.hasPrefix("/") {
                    let length = text.count
                    if length > 1 {
                        textView.setSelectedRange(NSRange(location: 1, length: length - 1))
                    } else {
                        textView.setSelectedRange(NSRange(location: 1, length: 0))
                    }
                } else {
                    textView.selectAll(nil)
                }
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

            // Custom select all for "/" prefixed searches (Cmd + A)
            if event.modifierFlags.contains(.command) && event.charactersIgnoringModifiers == "a" {
                if let textView = keyWindow.firstResponder as? NSTextView {
                    let text = textView.string
                    if text.hasPrefix("/") {
                        let length = text.count
                        if length > 1 {
                            textView.setSelectedRange(NSRange(location: 1, length: length - 1))
                        } else {
                            textView.setSelectedRange(NSRange(location: 1, length: 0))
                        }
                        return nil // Consume event
                    }
                }
            }

            let totalSelectable: Int
            if isWebSearchMode {
                if activeWebURL != nil {
                    totalSelectable = 0
                } else if searchText.isEmpty {
                    totalSelectable = 0
                } else {
                    totalSelectable = 1
                }
            } else {
                if searchText.isEmpty {
                    totalSelectable = 1
                } else {
                    totalSelectable = groupedResults.count
                }
            }

            switch event.keyCode {
            case 125: // ↓
                if selectedIndex < totalSelectable - 1 { selectedIndex += 1 }
                return nil
            case 126: // ↑
                if selectedIndex > 0 { selectedIndex -= 1 }
                return nil
            case 36: // ↵ Enter
                if isWebSearchMode {
                    if let url = WebService.shared.searchURL(for: searchText) {
                        activeWebURL = url
                    }
                } else {
                    if searchText.isEmpty {
                        if selectedIndex == 0 {
                            isWebSearchMode = true
                            searchText = ""
                            selectedIndex = 0
                        }
                    } else {
                        if selectedIndex < groupedResults.count {
                            executeSelection(groupedResults[selectedIndex])
                        }
                    }
                }
                return nil
            case 53: // Esc
                if isWebSearchMode {
                    if activeWebURL != nil {
                        activeWebURL = nil
                        selectedIndex = 0
                    } else {
                        isWebSearchMode = false
                        searchText = ""
                        selectedIndex = 0
                    }
                } else {
                    searchText.isEmpty ? NSApp.hide(nil) : clearSearch()
                }
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
        if result.Item.itemType == .command {
            executeCommand(result.Item.Path)
        } else if result.Item.itemType == .app {
            // Apps launch/open
            NSWorkspace.shared.open(URL(fileURLWithPath: result.Item.Path))
        } else {
            // Folders and Files reveal in Finder (selects the item in its parent directory)
            NSWorkspace.shared.activateFileViewerSelecting([URL(fileURLWithPath: result.Item.Path)])
        }
        NSApp.hide(nil)
    }

    private func executeCommand(_ commandId: String) {
        if commandId == "reset-index" {
            searchService.resetIndex()
        } else if let command = Command.allCommands.first(where: { $0.id == commandId }) {
            CommandService.shared.execute(command)
        }
    }
}

// MARK: - Row views

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
            } else if result.Item.itemType == .folder {
                Image(systemName: "folder.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Theme.iconSize, height: Theme.iconSize)
                    .foregroundColor(.blue)
            } else if result.Item.itemType == .command {
                Image(systemName: IconManager.shared.getCommandIcon(for: result.Item.Path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Theme.iconSize - 4, height: Theme.iconSize - 4)
                    .foregroundColor(isSelected ? Theme.textSelected : .blue)
                    .padding(4)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(result.Item.Name)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.textSelected : Theme.textPrimary)
                    .lineLimit(1)

                if result.Item.itemType == .folder {
                    Text(result.Item.Path)
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? Theme.textSelected.opacity(0.7) : Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(typeLabel(for: result.Item.itemType))
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isSelected ? Theme.textSelected.opacity(0.7) : Theme.textSecondary.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.white.opacity(0.15) : Theme.hoverBackground)
                )
        }
        .padding(.vertical, Theme.rowPaddingVertical)
        .padding(.horizontal, Theme.rowPaddingHorizontal)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowCornerRadius)
                .fill(isSelected ? Theme.selectionBackground : (isHovered ? Theme.hoverBackground : Color.clear))
        )
        .contentShape(Rectangle())
    }

    private func typeLabel(for type: ItemType) -> String {
        switch type {
        case .app: return "Application"
        case .folder: return "Folder"
        case .command: return "Command"
        case .file: return "File"
        }
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

// MARK: - WebSearchRow

struct WebSearchRow: View {
    let query: String
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Theme.iconSize - 4, height: Theme.iconSize - 4)
                .foregroundColor(isSelected ? Theme.textSelected : .blue)
                .padding(2)

            VStack(alignment: .leading, spacing: 1) {
                Text(query.isEmpty ? "Web Search" : "Search the Web")
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.textSelected : Theme.textPrimary)
                    .lineLimit(1)

                Text(query.isEmpty ? "Open Google" : "Search Google for \"\(query)\"")
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? Theme.textSelected.opacity(0.7) : Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("Web")
                .font(.system(size: 10, weight: .medium))
                .foregroundColor(isSelected ? Theme.textSelected.opacity(0.7) : Theme.textSecondary.opacity(0.8))
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(
                    RoundedRectangle(cornerRadius: 4)
                        .fill(isSelected ? Color.white.opacity(0.15) : Theme.hoverBackground)
                )
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

// MARK: - WebSearchCard

struct WebSearchCard: View {
    let isSelected: Bool
    let isHovered: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Theme.iconSize - 6, height: Theme.iconSize - 6)
                .foregroundColor(isSelected ? Theme.textSelected : .blue)
                .padding(3)
            
            Text("Web Search")
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Theme.textSelected : Theme.textPrimary)
            
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

