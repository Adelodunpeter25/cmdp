import SwiftUI

struct ContentView: View {
    @StateObject private var searchService = SearchService()
    @State private var searchText: String = ""
    @State private var selectedIndex: Int = 0
    @State private var hoveredIndex: Int? = nil
    @FocusState private var isSearchFieldFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            // Search Bar
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.title2)
                    .foregroundColor(.gray)
                
                TextField("Search apps and folders...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.title2)
                    .focused($isSearchFieldFocused)
                    .onChange(of: searchText) { _ in
                        searchService.search(query: searchText)
                        selectedIndex = 0 // Reset selection on new search
                    }
                
                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.gray)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor).opacity(0.8))
            
            Divider()

            // Results Area
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(spacing: 2) {
                        ForEach(Array(searchService.results.enumerated()), id: \.offset) { index, result in
                            ResultRow(result: result, isSelected: selectedIndex == index, isHovered: hoveredIndex == index)
                                .onHover { isHovered in
                                    hoveredIndex = isHovered ? index : nil
                                }
                                .onTapGesture {
                                    executeSelection(result)
                                }
                                .id(index)
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                }
                .scrollIndicators(.hidden)
                .onChange(of: selectedIndex) { _ in
                    proxy.scrollTo(selectedIndex, anchor: .center)
                }
            }
        }
        .frame(width: 600, height: 400)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .onAppear {
            isSearchFieldFocused = true
            searchService.search(query: "")
            setupKeyEventMonitor()
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
                NSApp.hide(nil)
                return nil // Consume event
            default:
                return event
            }
        }
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
            if let nsImage = IconManager.shared.icon(for: result.App.IconPath) {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 24, height: 24)
            } else {
                Image(systemName: "app.fill")
                    .resizable()
                    .frame(width: 24, height: 24)
                    .foregroundColor(.secondary)
            }
            
            VStack(alignment: .leading, spacing: 1) {
                Text(result.App.Name)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? .white : .primary)
            }
            Spacer()
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Color.accentColor : (isHovered ? Color.primary.opacity(0.05) : Color.clear))
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
