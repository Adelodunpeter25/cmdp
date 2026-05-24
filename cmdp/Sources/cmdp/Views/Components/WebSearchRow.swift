import SwiftUI

struct WebSearchRow: View {
    let query: String
    let isSelected: Bool
    let isHovered: Bool

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "globe")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundColor(isSelected ? Theme.textSelected : .blue)
                .padding(4)

            VStack(alignment: .leading, spacing: 1) {
                Text(query.isEmpty ? "Web Search" : "Search the Web")
                    .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.textSelected : Theme.textPrimary)
                    .lineLimit(1)

                Text(query.isEmpty ? "Open Google" : "Search Google for \"\(query)\"")
                    .font(.system(size: 10))
                    .foregroundColor(isSelected ? Theme.textSelected.opacity(0.7) : Theme.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            Text("Web")
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
}
