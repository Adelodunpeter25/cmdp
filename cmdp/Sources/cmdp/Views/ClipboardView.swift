import SwiftUI
import AppKit

struct ClipboardView: View {
    @Binding var searchText: String
    @StateObject private var clipboardService = ClipboardService.shared
    @State private var selectedItemId: String? = nil
    
    var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return clipboardService.items
        } else {
            let query = searchText.lowercased()
            return clipboardService.items.filter { $0.content.lowercased().contains(query) }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            if clipboardService.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "doc.on.clipboard")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.textSecondary.opacity(0.4))
                    Text("Clipboard history is empty")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    Text("Copied text or links will automatically appear here.")
                        .font(.system(size: 11))
                        .foregroundColor(Theme.textSecondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }
                .frame(maxHeight: .infinity)
                .background(Color.clear)
            } else if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "magnifyingglass")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.textSecondary.opacity(0.4))
                    Text("No results for \"\(searchText)\"")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                }
                .frame(maxHeight: .infinity)
                .background(Color.clear)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(filteredItems) { item in
                            ClipboardItemRow(
                                item: item,
                                isSelected: selectedItemId == item.id,
                                onSelect: { selectedItemId = item.id }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(height: 350)
        .frame(maxWidth: .infinity)
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let isSelected: Bool
    let onSelect: () -> Void
    @StateObject private var clipboardService = ClipboardService.shared
    @State private var isHovered = false
    @State private var isCopied = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 16))
                .foregroundColor(isSelected ? Theme.textSelected : Theme.textSecondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.content.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(isSelected ? Theme.textSelected : Theme.textPrimary)
                    .lineLimit(1)
                
                Text(formatTimestamp(item.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? Theme.textSelected.opacity(0.7) : Theme.textSecondary)
            }
            
            Spacer()
            
            if isHovered {
                HStack(spacing: 8) {
                    // Hover Copy Button
                    Button(action: {
                        clipboardService.copyToClipboard(content: item.content)
                        isCopied = true
                        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                            isCopied = false
                        }
                    }) {
                        Image(systemName: isCopied ? "checkmark" : "doc.on.doc")
                            .font(.system(size: 12))
                            .foregroundColor(isCopied ? .green : (isSelected ? Theme.textSelected : Theme.textSecondary))
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    // Hover Delete Button
                    Button(action: {
                        clipboardService.deleteItem(id: item.id)
                    }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.system(size: 12))
                            .foregroundColor(isSelected ? Theme.textSelected : .red.opacity(0.8))
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowCornerRadius)
                .fill(isSelected ? Theme.selectionBackground : (isHovered ? Theme.hoverBackground : Color.black.opacity(0.001)))
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .simultaneousGesture(
            TapGesture(count: 1).onEnded {
                onSelect()
            }
        )
    }
    
    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}

