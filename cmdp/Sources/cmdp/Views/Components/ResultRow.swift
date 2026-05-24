import SwiftUI

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
            } else if result.Item.itemType == .folder {
                Image(systemName: "folder.fill")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Theme.iconSize, height: Theme.iconSize)
                    .foregroundColor(.blue)
            } else if result.Item.itemType == .command {
                Image(systemName: IconManager.shared.getCommandIcon(for: result.Item.Path))
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Theme.iconSize - 4, height: Theme.iconSize - 4)
                    .foregroundColor(isSelected ? Theme.textSelected : .blue)
                    .padding(4)
            }

            VStack(alignment: .leading, spacing: 1) {
                Text(result.Item.Name)
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.textSelected : Theme.textPrimary)
                    .lineLimit(1)

                if result.Item.itemType == .folder {
                    Text(result.Item.Path)
                        .font(.system(size: 10))
                        .foregroundColor(isSelected ? Theme.textSelected.opacity(0.7) : Theme.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            Text(typeLabel(for: result.Item.itemType))
                .font(.system(size: 10, weight: .medium))
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

    private func typeLabel(for type: ItemType) -> String {
        switch type {
        case .app: return "Application"
        case .folder: return "Folder"
        case .command: return "Command"
        case .file: return "File"
        }
    }
}
