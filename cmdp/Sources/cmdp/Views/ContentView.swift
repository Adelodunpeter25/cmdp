import SwiftUI
import CLibSearch


// MARK: - ContentView

struct ContentView: View {
    @StateObject private var searchService = SearchService()
    @StateObject private var processService = ProcessService()
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @State private var hoveredIndex: Int? = nil
    @State private var activeWebURL: URL? = nil
    @State private var isWebSearchMode: Bool = false
    @State private var isActivityMonitorMode: Bool = false
    @State private var isShelfMode: Bool = false
    @State private var isClipboardMode: Bool = false
    @State private var processSortByCPU: Bool = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var searchDebounceItem: DispatchWorkItem?
    @State private var loadedWebURL: URL?

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
            SearchBarView(
                searchText: $searchText,
                isActivityMonitorMode: isActivityMonitorMode,
                isWebSearchMode: isWebSearchMode,
                isShelfMode: isShelfMode,
                isClipboardMode: isClipboardMode,
                isSearchFieldFocused: $isSearchFieldFocused,
                onClear: { clearSearch() }
            )

            // Results Area & Dashboard Empty State
            if isActivityMonitorMode {
                Divider()
                ActivityMonitorView(
                    processes: processService.filteredProcesses(searchText: searchText, processSortByCPU: processSortByCPU),
                    searchText: $searchText,
                    selectedIndex: $selectedIndex,
                    isActivityMonitorMode: $isActivityMonitorMode,
                    processSortByCPU: $processSortByCPU,
                    onKill: { proc, force in
                        processService.confirmKillProcess(proc, force: force)
                    }
                )
            } else if isWebSearchMode {
                if let webURL = activeWebURL {
                    Divider()
                    WebView(url: webURL)
                        .frame(height: 400)
                        .transition(.opacity)
                        .onChange(of: activeWebURL) { _ in
                            // When URL changes, update loaded flag
                            if let url = activeWebURL {
                                loadedWebURL = url
                            }
                        }
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
                } else {
                    Divider()
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "globe")
                            .font(.system(size: 32))
                            .foregroundColor(Theme.textSecondary.opacity(0.6))
                        
                        Text("Web Search Mode")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundColor(Theme.textSecondary)
                        
                        Button(action: {
                            isShelfMode = true
                            selectedIndex = 0
                        }) {
                            HStack {
                                Image(systemName: "square.and.arrow.down.on.square")
                                Text("Open Shelf")
                            }
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(Theme.textSelected)
                            .padding(.vertical, 8)
                            .padding(.horizontal, 16)
                            .background(Theme.selectionBackground)
                            .cornerRadius(6)
                        }
                        .buttonStyle(PlainButtonStyle())
                        .onHover { hovered in
                            if hovered {
                                NSCursor.pointingHand.push()
                            } else {
                                NSCursor.pop()
                            }
                        }
                        
                        Spacer()
                    }
                    .frame(height: 200)
                    .frame(maxWidth: .infinity)
                }
            } else if isShelfMode {
                Divider()
                ShelfView()
                    .transition(.opacity)
            } else if isClipboardMode {
                Divider()
                ClipboardView()
                    .transition(.opacity)
            } else {
                if !searchText.isEmpty && !groupedResults.isEmpty {
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
                        SearchListView(
                            displayItems: displayItems,
                            groupedResults: groupedResults,
                            selectedIndex: $selectedIndex,
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
                    }
                } else if searchText.isEmpty {
                    Divider()
                    HomeDashboardView(
                        selectedIndex: $selectedIndex,
                        hoveredIndex: $hoveredIndex,
                        isWebSearchMode: $isWebSearchMode,
                        isShelfMode: $isShelfMode,
                        isClipboardMode: $isClipboardMode,
                        searchText: $searchText,
                        onOpenActivityMonitor: {
                            openActivityMonitor()
                        }
                    )
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
        .onChange(of: searchText) { newValue in
            // Observe and process text changes at parent level
            if isActivityMonitorMode {
                selectedIndex = 0
                updateWindowSize()
                return
            }

            searchDebounceItem?.cancel()

            if activeWebURL != nil {
                loadedWebURL = nil
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
        .onChange(of: searchService.results) { _ in updateWindowSize() }
        .onChange(of: processService.systemStats) { _ in updateWindowSize() }
        .onChange(of: activeWebURL) { _ in updateWindowSize() }
        .onChange(of: isWebSearchMode) { _ in updateWindowSize() }
        .onChange(of: isShelfMode) { _ in updateWindowSize() }
        .onChange(of: isClipboardMode) { _ in updateWindowSize() }
        .onChange(of: isActivityMonitorMode) { _ in updateWindowSize() }
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

        // Prioritize Applications, followed by Folders, then Commands
        return apps + folders + commands
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
            if isActivityMonitorMode {
                totalSelectable = processService.filteredProcesses(searchText: searchText, processSortByCPU: processSortByCPU).count
            } else if isWebSearchMode {
                if activeWebURL != nil {
                    totalSelectable = 0
                } else if searchText.isEmpty {
                    totalSelectable = 0
                } else {
                    totalSelectable = 1
                }
            } else if isShelfMode {
                totalSelectable = 0
            } else if isClipboardMode {
                totalSelectable = 0
            } else {
                if searchText.isEmpty {
                    totalSelectable = 4
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
                if isActivityMonitorMode {
                    let procs = processService.filteredProcesses(searchText: searchText, processSortByCPU: processSortByCPU)
                    if selectedIndex < procs.count {
                        processService.confirmKillProcess(procs[selectedIndex], force: false)
                    }
                } else if isWebSearchMode {
                    if let url = WebService.shared.searchURL(for: searchText) {
                        activeWebURL = url
                    }
                } else if isShelfMode {
                    // No action
                } else if isClipboardMode {
                    // No action
                } else {
                    if searchText.isEmpty {
                        if selectedIndex == 0 {
                            isWebSearchMode = true
                            searchText = ""
                            selectedIndex = 0
                        } else if selectedIndex == 1 {
                            isShelfMode = true
                            searchText = ""
                            selectedIndex = 0
                        } else if selectedIndex == 2 {
                            isClipboardMode = true
                            searchText = ""
                            selectedIndex = 0
                        } else if selectedIndex == 3 {
                            openActivityMonitor()
                        }
                    } else {
                        if selectedIndex < groupedResults.count {
                            executeSelection(groupedResults[selectedIndex])
                        }
                    }
                }
                return nil
            case 53: // Esc
                if isActivityMonitorMode {
                    isActivityMonitorMode = false
                    searchText = ""
                    selectedIndex = 0
                } else if isWebSearchMode {
                    if activeWebURL != nil {
                        loadedWebURL = nil
                        activeWebURL = nil
                        selectedIndex = 0
                    } else {
                        isWebSearchMode = false
                        searchText = ""
                        selectedIndex = 0
                        loadedWebURL = nil
                    }
                } else if isShelfMode {
                    isShelfMode = false
                    searchText = ""
                    selectedIndex = 0
                } else if isClipboardMode {
                    isClipboardMode = false
                    searchText = ""
                    selectedIndex = 0
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
        // Hide the app immediately so the UI doesn't hang on screen
        NSApp.hide(nil)

        let path = result.Item.Path
        let url = URL(fileURLWithPath: path)

        if result.Item.itemType == .command {
            executeCommand(path)
        } else if result.Item.itemType == .app {
            // Launch the application asynchronously to prevent main-thread freezing
            NSWorkspace.shared.open(url, configuration: NSWorkspace.OpenConfiguration()) { _, error in
                if let error = error {
                    print("ContentView: Failed to open app asynchronously: \(error)")
                }
            }
        } else {
            // Reveal folders and files in Finder on a background queue to keep main-thread responsive
            DispatchQueue.global(qos: .userInitiated).async {
                NSWorkspace.shared.activateFileViewerSelecting([url])
            }
        }
    }

    private func executeCommand(_ commandId: String) {
        if commandId == "reset-index" {
            searchService.resetIndex()
        } else if let command = Command.allCommands.first(where: { $0.id == commandId }) {
            CommandService.shared.execute(command)
        }
    }

    private func openActivityMonitor() {
        isActivityMonitorMode = true
        searchText = ""
        selectedIndex = 0
    }

}



