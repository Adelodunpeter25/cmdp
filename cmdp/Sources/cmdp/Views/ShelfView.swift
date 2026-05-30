import SwiftUI
import AppKit

struct ShelfView: View {
    @StateObject private var shelfService = ShelfService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Image(systemName: "square.and.arrow.down.on.square")
                    .font(.system(size: 16))
                    .foregroundColor(Theme.textSelected)
                Text("File Shelf")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(Theme.textPrimary)
                Spacer()
                Text("\(shelfService.items.count) items")
                    .font(.system(size: 12))
                    .foregroundColor(Theme.textSecondary)
            }
            .padding()
            .background(Color.black.opacity(0.1))
            
            Divider()
            
            // Content
            if shelfService.items.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 40))
                        .foregroundColor(Theme.textSecondary.opacity(0.4))
                    Text("Drag & Drop files here")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundColor(Theme.textSecondary)
                    Text("They will copy and persist on this shelf for later drag-and-drop.")
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
                        ForEach(shelfService.items) { item in
                            ShelfItemRow(item: item)
                        }
                    }
                    .padding()
                }
            }
        }
        .frame(width: 350, height: 500)
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
        .onDrop(of: ["public.file-url"], isTargeted: nil) { providers in
            // Handle drop
            for provider in providers {
                let _ = provider.loadObject(ofClass: URL.self) { url, error in
                    if let url = url, url.isFileURL {
                        DispatchQueue.main.async {
                            shelfService.addToShelf(path: url.path)
                        }
                    }
                }
            }
            return true
        }
    }
}

struct ShelfItemRow: View {
    let item: ShelfItem
    @StateObject private var shelfService = ShelfService.shared
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            // File Icon View
            FileIconView(path: item.shelfPath)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(item.name)
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(Theme.textPrimary)
                    .lineLimit(1)
                
                Text(item.originalPath)
                    .font(.system(size: 10))
                    .foregroundColor(Theme.textSecondary)
                    .lineLimit(1)
                    .truncationMode(.head)
            }
            
            Spacer()
            
            if isHovered {
                Button(action: {
                    shelfService.removeFromShelf(id: item.id)
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
                .fill(isHovered ? Theme.hoverBackground : Color.clear)
        )
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        // Drag out support!
        .onDrag {
            let url = URL(fileURLWithPath: item.shelfPath)
            return NSItemProvider(object: url as NSURL)
        }
    }
}

struct FileIconView: View {
    let path: String
    
    var body: some View {
        if let icon = NSWorkspace.shared.icon(forFile: path) as NSImage? {
            Image(nsImage: icon)
                .resizable()
                .aspectRatio(contentMode: .fit)
        } else {
            Image(systemName: "doc")
                .resizable()
                .aspectRatio(contentMode: .fit)
        }
    }
}
