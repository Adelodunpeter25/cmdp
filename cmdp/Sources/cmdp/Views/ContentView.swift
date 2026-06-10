import SwiftUI
import CLibSearch


// MARK: - ContentView

struct ContentView: View {
    @StateObject private var searchService = SearchService()
    @StateObject private var processService = ProcessService()
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @State private var hoveredIndex: Int? = nil
    @State private var isActivityMonitorMode: Bool = false
    @State private var isShelfMode: Bool = false
    @State private var isClipboardMode: Bool = false
    @State private var isSettingsMode: Bool = false
    @State private var processSortByCPU: Bool = false
    @FocusState private var isSearchFieldFocused: Bool
    @State private var searchDebounceItem: DispatchWorkItem?
    @State private var previousSearchText: String = ""

    // MARK: Computed display list

    /// Flat, display-ordered list of results (apps first by score, then
    /// folders by score).  This is the single source of truth for
    /// selectedIndex and keyboard navigation.
    private var groupedResults: [SearchResult] {
        if searchText.hasPrefix("/") {
            return searchService.results
        }
        
        let query = searchText.hasPrefix(">") ? String(searchText.dropFirst()) : searchText
        let lowerQuery = query.lowercased()
        
        // Always include matching commands
        let commandResults = Command.allCommands.filter { cmd in
            lowerQuery.isEmpty || cmd.name.lowercased().contains(lowerQuery) || cmd.id.lowercased().contains(lowerQuery)
        }.map { cmd in
            SearchResult(Item: IndexItem(Name: cmd.name, Path: cmd.id, IconPath: "", itemType: .command), Score: 100)
        }
        
        if searchText.hasPrefix(">") {
            return commandResults
        }
        
        return groupAndSort(searchService.results + commandResults)
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
                isShelfMode: isShelfMode,
                isClipboardMode: isClipboardMode,
                isSettingsMode: isSettingsMode,
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
            } else if isShelfMode {
                Divider()
                ShelfView()
                    .transition(.opacity)
            } else if isClipboardMode {
                Divider()
                ClipboardView(searchText: $searchText)
                    .transition(.opacity)
            } else if isSettingsMode {
                Divider()
                SettingsView(searchService: searchService, isSettingsMode: $isSettingsMode)
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
                                selectedIndex = index
                                executeSelection(result)
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
                                selectedIndex = index
                                executeSelection(result)
                            }
                        )
                        .transition(.opacity)
                    }
                } else if searchText.isEmpty {
                    // Empty state - nothing shown below the search bar
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

            if isClipboardMode {
                selectedIndex = 0
                updateWindowSize()
                return
            }

            if isSettingsMode {
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
        .onChange(of: isShelfMode) { _ in updateWindowSize() }
        .onChange(of: isClipboardMode) { _ in updateWindowSize() }
        .onChange(of: isSettingsMode) { _ in updateWindowSize() }
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
            } else if isShelfMode {
                totalSelectable = 0
            } else if isClipboardMode {
                totalSelectable = 0
            } else if isSettingsMode {
                totalSelectable = 0
            } else {
                if searchText.isEmpty {
                    totalSelectable = 0
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
                } else if isShelfMode {
                    // No action
                } else if isClipboardMode {
                    // No action
                } else if isSettingsMode {
                    // No action
                } else {
                    if !searchText.isEmpty && selectedIndex < groupedResults.count {
                        executeSelection(groupedResults[selectedIndex])
                    }
                }
                return nil
            case 53: // Esc
                if isActivityMonitorMode {
                    isActivityMonitorMode = false
                    if previousSearchText.hasPrefix(">") {
                        searchText = ">"
                    } else {
                        searchText = ""
                    }
                    selectedIndex = 0
                } else if isShelfMode {
                    isShelfMode = false
                    if previousSearchText.hasPrefix(">") {
                        searchText = ">"
                    } else {
                        searchText = ""
                    }
                    selectedIndex = 0
                } else if isClipboardMode {
                    isClipboardMode = false
                    if previousSearchText.hasPrefix(">") {
                        searchText = ">"
                    } else {
                        searchText = ""
                    }
                    selectedIndex = 0
                } else if isSettingsMode {
                    isSettingsMode = false
                    if previousSearchText.hasPrefix(">") {
                        searchText = ">"
                    } else {
                        searchText = ""
                    }
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
        previousSearchText = searchText
        let path = result.Item.Path
        let url = URL(fileURLWithPath: path)

        if result.Item.itemType == .command {
            // Only hide if it's not a navigation command
            if !path.hasPrefix("nav-") {
                NSApp.hide(nil)
            }
            executeCommand(path)
        } else {
            // Apps, folders, and files always hide the app
            NSApp.hide(nil)
            
            if result.Item.itemType == .app {
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
    }

    private func executeCommand(_ commandId: String) {
        previousSearchText = searchText
        if commandId == "nav-shelf" {
            isShelfMode = true
            searchText = ""
        } else if commandId == "nav-clipboard" {
            isClipboardMode = true
            searchText = ""
        } else if commandId == "nav-activity" {
            openActivityMonitor()
        } else if commandId == "nav-settings" {
            isSettingsMode = true
            searchText = ""
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



