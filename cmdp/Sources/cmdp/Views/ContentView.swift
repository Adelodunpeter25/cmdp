import SwiftUI

struct ContentView: View {
    @StateObject private var searchService = SearchService()
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @State private var hoveredIndex: Int? = nil
    @FocusState private var isSearchFieldFocused: Bool
    @State private var searchDebounceItem: DispatchWorkItem?

    // MARK: - Grouped results (single source of truth for ordering)

    /// Results split into [apps, folders] sections and then flattened in that
    /// display order.  All index arithmetic uses this array so keyboard
    /// navigation and the rendered list are always in sync.
    private var groupedResults: [SearchResult] {
        groupResults(searchService.results)
    }

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
                                Section(header: sectionHeader("COMMANDS")) {
                                    ForEach(Array(searchService.commandResults.enumerated()), id: \.offset) { index, command in
                                        CommandRow(command: command, isSelected: selectedIndex == index, isHovered: hoveredIndex == index)
                                            .onHover { isHovered in
                                                hoveredIndex = isHovered ? index : nil
                                            }
                                            .onTapGesture {
                                                if selectedIndex == index {
                                                    executeCommand(command)
                                                } else {
                                                    selectedIndex = index
                                                }
                                            }
                                            .id(index)
                                    }
                                }
                            } else {
                                // Render sections from the pre-grouped, flattened array.
                                // groupedDisplay splits the flat array back into sections
                                // for visual separation while preserving index continuity.
                                let sections = buildSections(groupedResults)
                                var runningIndex = 0
                                ForEach(sections, id: \.type) { section in
                                    Section(header: sectionHeader(section.type == .app ? "APPLICATIONS" : "FOLDERS")) {
                                        ForEach(Array(section.items.enumerated()), id: \.element.id) { localIdx, result in
                                            let index = runningIndex + localIdx
                                            ResultRow(result: result, isSelected: selectedIndex == index, isHovered: hoveredIndex == index)
                                                .onHover { isHovered in
                                                    hoveredIndex = isHovered ? index : nil
                                                }
                                                .onTapGesture {
                                                    if selectedIndex == index {
                                                        executeSelection(result)
                                                    } else {
                                                        selectedIndex = index
                                                    }
                                                }
                                                .id(index)
                                        }
                                    }
                                    // SwiftUI's ForEach closures don't allow mutation;
                                    // use a dummy view to advance the counter.
                                    let _ = { runningIndex += section.items.count }()
                                }
                            }
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 8)
                    }
                    .frame(maxHeight: 350)
                    .scrollIndicators(.hidden)
                    .onChange(of: selectedIndex) { _ in
                        proxy.scrollTo(selectedIndex, anchor: .center)
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
        .onChange(of: searchService.results) { _ in
            updateWindowSize()
        }
        .onChange(of: searchService.commandResults) { _ in
            updateWindowSize()
        }
    }

    // MARK: - Grouping helpers

    private struct ResultSection {
        let type: ItemType
        let items: [SearchResult]
    }

    /// Returns a flat array of results ordered: all apps first (by score),
    /// then all folders (by score).  This is the canonical display order and
    /// the source of truth for `selectedIndex`.
    private func groupResults(_ results: [SearchResult]) -> [SearchResult] {
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

        // Determine which group has the top-ranked result to put it first.
        // Check the first item of each group (they're already score-sorted
        // by the Go backend) to decide section order.
        let appTop    = apps.first.map    { $0.Score } ?? Int.min
        let folderTop = folders.first.map { $0.Score } ?? Int.min

        if folderTop > appTop {
            return folders + apps
        } else {
            return apps + folders
        }
    }

    /// Splits the flat grouped array back into sections for visual rendering,
    /// preserving the ordering from `groupResults`.
    private func buildSections(_ flat: [SearchResult]) -> [ResultSection] {
        guard !flat.isEmpty else { return [] }

        var sections: [ResultSection] = []
        var currentType = flat[0].Item.itemType
        var currentBatch: [SearchResult] = []

        for result in flat {
            if result.Item.itemType == currentType {
                currentBatch.append(result)
            } else {
                sections.append(ResultSection(type: currentType, items: currentBatch))
                currentType = result.Item.itemType
                currentBatch = [result]
            }
        }
        if !currentBatch.isEmpty {
            sections.append(ResultSection(type: currentType, items: currentBatch))
        }
        return sections
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
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { _ in
            self.selectAllSearchText()
        }
    }

    private func selectAllSearchText() {
        isSearchFieldFocused = true
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            if let window = NSApp.keyWindow,
               let textField = window.firstResponder as? NSTextView {
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
            let heightDifference = targetSize.height - newFrame.size.height
            
            if abs(heightDifference) > 0.1 {
                newFrame.size.height = targetSize.height
                newFrame.origin.y -= heightDifference
                window.setFrame(newFrame, display: true, animate: true)
            }
        }
    }

    // MARK: - Key events

    func setupKeyEventMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            guard let keyWindow = NSApp.keyWindow, keyWindow.contentView?.closestHostingView() != nil else {
                return event
            }

            // Use the grouped array count so navigation matches visual order exactly.
            let resultCount = searchService.isCommandMode
                ? searchService.commandResults.count
                : groupedResults.count

            switch event.keyCode {
            case 125: // Down
                if selectedIndex < resultCount - 1 {
                    selectedIndex += 1
                }
                return nil
            case 126: // Up
                if selectedIndex > 0 {
                    selectedIndex -= 1
                }
                return nil
            case 36: // Enter
                if searchService.isCommandMode {
                    if selectedIndex < searchService.commandResults.count {
                        executeCommand(searchService.commandResults[selectedIndex])
                    }
                } else {
                    if selectedIndex < groupedResults.count {
                        executeSelection(groupedResults[selectedIndex])
                    }
                }
                return nil
            case 53: // Escape
                if searchText.isEmpty {
                    NSApp.hide(nil)
                } else {
                    clearSearch()
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
        let url = URL(fileURLWithPath: result.Item.Path)
        NSWorkspace.shared.open(url)
        NSApp.hide(nil)
    }

    func executeCommand(_ command: Command) {
        if command.script == "RESET_INDEX" {
            searchService.resetIndex()
        } else {
            CommandService.shared.execute(command)
        }
        NSApp.hide(nil)
    }
}

// MARK: - Row Views

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
        if self.className.contains("HostingView") {
            return self
        }
        return self.superview?.closestHostingView()
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
