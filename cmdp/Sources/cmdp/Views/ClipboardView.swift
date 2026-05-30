import SwiftUI
import AppKit

struct ClipboardView: View {
    @StateObject private var clipboardService = ClipboardService.shared
    
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
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(clipboardService.items) { item in
                            ClipboardItemRow(item: item)
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
    @StateObject private var clipboardService = ClipboardService.shared
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 16))
                .foregroundColor(Theme.textSecondary)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.content.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                
                Text(formatTimestamp(item.createdAt))
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
            }
            
            Spacer()
            
            if isHovered {
                Button(action: {
                    clipboardService.deleteItem(id: item.id)
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.red.opacity(0.8))
                }
                .buttonStyle(PlainButtonStyle())
            }
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowCornerRadius)
                .fill(isHovered ? Theme.hoverBackground : Color.black.opacity(0.001))
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .onTapGesture {
            clipboardService.copyToClipboard(content: item.content)
            NSApp.hide(nil)
        }
    }
    
    private func formatTimestamp(_ timestamp: Int64) -> String {
        let date = Date(timeIntervalSince1970: TimeInterval(timestamp))
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        formatter.dateStyle = .none
        return formatter.string(from: date)
    }
}
