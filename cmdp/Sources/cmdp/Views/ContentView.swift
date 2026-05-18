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
                    .onKeyDown { event in
                        handleKeyDown(event)
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
                List {
                    ForEach(Array(searchService.results.enumerated()), id: \.offset) { index, result in
                        HStack {
                            if let nsImage = NSImage(contentsOfFile: result.App.IconPath) {
                                Image(nsImage: nsImage)
                                    .resizable()
                                    .frame(width: 32, height: 32)
                            } else {
                                Image(systemName: "app.fill")
                                    .resizable()
                                    .frame(width: 32, height: 32)
                                    .foregroundColor(.blue)
                            }
                            
                            VStack(alignment: .leading) {
                                Text(result.App.Name)
                                    .font(.headline)
                                Text(result.App.Path)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                                    .lineLimit(1)
                            }
                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedIndex == index || hoveredIndex == index ? Color.accentColor.opacity(0.2) : Color.clear)
                        )
                        .id(index)
                        .onHover { isHovered in
                            hoveredIndex = isHovered ? index : nil
                        }
                        .onTapGesture {
                            executeSelection(result)
                        }
                    }
                }
                .listStyle(.plain)
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
        }
    }

    func handleKeyDown(_ event: NSEvent) {
        switch event.keyCode {
        case 125: // Down
            if selectedIndex < searchService.results.count - 1 {
                selectedIndex += 1
            }
        case 126: // Up
            if selectedIndex > 0 {
                selectedIndex -= 1
            }
        case 36: // Enter
            if selectedIndex < searchService.results.count {
                executeSelection(searchService.results[selectedIndex])
            }
        case 53: // Escape
            NSApp.hide(nil)
        default:
            break
        }
    }

    func executeSelection(_ result: AppResult) {
        searchService.select(app: result)
        let url = URL(fileURLWithPath: result.App.Path)
        NSWorkspace.shared.open(url)
        NSApp.hide(nil)
    }
}

// Extension to handle key events on the TextField
extension View {
    func onKeyDown(perform action: @escaping (NSEvent) -> Void) -> some View {
        self.background(KeyEventView(action: action))
    }
}

struct KeyEventView: NSViewRepresentable {
    let action: (NSEvent) -> Void

    func makeNSView(context: Context) -> NSView {
        let view = KeyView()
        view.action = action
        return view
    }

    func updateNSView(_ nsView: NSView, context: Context) {}

    class KeyView: NSView {
        var action: ((NSEvent) -> Void)?

        override var acceptsFirstResponder: Bool { true }

        override func keyDown(with event: NSEvent) {
            action?(event)
        }
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
