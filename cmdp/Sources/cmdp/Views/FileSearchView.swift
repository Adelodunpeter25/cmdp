import SwiftUI

struct FileSearchView: View {
    let results: [SearchResult]
    let selectedIndex: Int
    @Binding var hoveredIndex: Int?
    let onTapRow: (SearchResult) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.rowSpacing) {
                    HStack {
                        Text("FILES")
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(Theme.textSecondary.opacity(0.8))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                        Spacer()
                    }

                    ForEach(Array(results.enumerated()), id: \.element.id) { index, result in
                        FileResultRow(
                            result: result,
                            isSelected: selectedIndex == index,
                            isHovered: hoveredIndex == index
                        )
                        .onHover { hoveredIndex = $0 ? index : nil }
                        .onTapGesture {
                            onTapRow(result)
                        }
                        .id("file-\(index)-\(result.id)")
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 350)
            .scrollIndicators(.hidden)
            .onChange(of: selectedIndex) { newIndex in
                if newIndex >= 0 && newIndex < results.count {
                    let targetId = "file-\(newIndex)-\(results[newIndex].id)"
                    proxy.scrollTo(targetId, anchor: .center)
                }
            }
        }
    }
}

struct FileResultRow: View {
    let result: SearchResult
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: fileIcon(for: result.Item.Name))
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: Theme.iconSize - 6, height: Theme.iconSize - 6)
                .foregroundColor(isSelected ? Theme.textSelected : .secondary)
                .padding(3)

            VStack(alignment: .leading, spacing: 1) {
                Text(result.Item.Name)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.textSelected : Theme.textPrimary)
                    .lineLimit(1)

                Text(result.Item.Path)
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? Theme.textSelected.opacity(0.7) : Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text(fileBadge(for: result.Item.Name))
                .font(.system(size: 10, weight: .bold))
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

    private func fileIcon(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.lowercased()
        switch ext {
        case "png", "jpg", "jpeg", "gif", "svg", "heic":
            return "photo"
        case "pdf":
            return "doc.richtext"
        case "txt", "md", "rtf", "pages":
            return "doc.text"
        case "doc", "docx":
            return "doc.text.fill"
        case "xls", "xlsx", "numbers":
            return "tablecells"
        case "ppt", "pptx", "key":
            return "play.rectangle"
        case "zip", "tar", "gz", "rar", "7z":
            return "archivebox"
        case "mp3", "wav", "m4a", "flac":
            return "music.note"
        case "mp4", "mov", "avi", "mkv":
            return "film"
        case "go", "swift", "py", "js", "ts", "json", "html", "css", "c", "cpp", "h", "java", "sh":
            return "doc.plaintext"
        default:
            return "doc"
        }
    }

    private func fileBadge(for filename: String) -> String {
        let ext = (filename as NSString).pathExtension.uppercased()
        return ext.isEmpty ? "FILE" : ext
    }
}
