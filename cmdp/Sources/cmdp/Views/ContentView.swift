import SwiftUI

struct ContentView: View {
    @StateObject private var searchService = SearchService()
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @State private var hoveredIndex: Int? = nil
    @FocusState private var isSearchFieldFocused: Bool
    @State private var searchDebounceItem: DispatchWorkItem?

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
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
            if !searchText.isEmpty && !searchService.results.isEmpty {
                Divider()
                
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(spacing: Theme.rowSpacing) {
                            ForEach(Array(searchService.results.enumerated()), id: \.offset) { index, result in
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
    }

    private func setupNotificationObservers() {
        NotificationCenter.default.addObserver(forName: NSWindow.didBecomeKeyNotification, object: nil, queue: .main) { _ in
            self.selectAllSearchText()
        }
    }

    private func selectAllSearchText() {
        isSearchFieldFocused = true
        // Small delay to ensure the field is focused before selecting
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.01) {
            if let window = NSApp.keyWindow,
               let textField = window.firstResponder as? NSTextView {
                textField.selectAll(nil)
            }
        }
    }

    private func updateWindowSize() {
        // Small delay to let SwiftUI layout pass finish
        DispatchQueue.main.async {
            guard let window = NSApp.windows.first(where: { $0 is SpotlightWindow }) else { return }
            
            let hostingView = window.contentView as? NSHostingView<ContentView>
            let targetSize = hostingView?.fittingSize ?? CGSize(width: 600, height: 60)
            
            var newFrame = window.frame
            let heightDifference = targetSize.height - newFrame.size.height
            
            if abs(heightDifference) > 0.1 {
                newFrame.size.height = targetSize.height
                newFrame.origin.y -= heightDifference // Expand downwards by moving origin up (macOS coords)
                window.setFrame(newFrame, display: true, animate: true)
            }
        }
    }

    func setupKeyEventMonitor() {
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Only handle if this window is key
            guard let keyWindow = NSApp.keyWindow, keyWindow.contentView?.closestHostingView() != nil else {
                return event
            }
            
            switch event.keyCode {
            case 125: // Down
                if selectedIndex < searchService.results.count - 1 {
                    selectedIndex += 1
                }
                return nil // Consume event
            case 126: // Up
                if selectedIndex > 0 {
                    selectedIndex -= 1
                }
                return nil // Consume event
            case 36: // Enter
                if selectedIndex < searchService.results.count {
                    executeSelection(searchService.results[selectedIndex])
                }
                return nil // Consume event
            case 53: // Escape
                if searchText.isEmpty {
                    NSApp.hide(nil)
                } else {
                    clearSearch()
                }
                return nil // Consume event
            default:
                return event
            }
        }
    }

    private func clearSearch() {
        searchText = ""
        selectedIndex = 0
        searchService.search(query: "")
    }

    func executeSelection(_ result: AppResult) {
        searchService.select(app: result)
        let url = URL(fileURLWithPath: result.App.Path)
        NSWorkspace.shared.open(url)
        NSApp.hide(nil)
    }
}

struct ResultRow: View {
    let result: AppResult
    let isSelected: Bool
    let isHovered: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            if let nsImage = IconManager.shared.icon(for: result.App.IconPath, fallbackAppPath: result.App.Path) {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: Theme.iconSize, height: Theme.iconSize)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .frame(width: Theme.iconSize, height: Theme.iconSize)
                    .foregroundColor(Theme.textSecondary)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(result.App.Name)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.textSelected : Theme.textPrimary)
            }
            Spacer()
        }
        .padding(.vertical, Theme.rowPaddingVertical)
        .padding(.horizontal, Theme.rowPaddingHorizontal)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowCornerRadius)
                .fill(isSelected ? Theme.selectionBackground : (isHovered ? Theme.hoverBackground : Color.clear))
        )
        .contentShape(Rectangle()) // Makes the whole row clickable
    }
}

// Helper to check if the view is in the active window
extension NSView {
    func closestHostingView() -> NSView? {
        if self.className.contains("HostingView") {
            return self
        }
        return self.superview?.closestHostingView()
    }
}

// Utility for the blurred background effect
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
