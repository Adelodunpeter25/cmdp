import SwiftUI

struct DashboardCommandRow: View {
    let iconName: String
    let title: String
    let iconColor: Color
    let isSelected: Bool
    let isHovered: Bool
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: iconName)
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(width: 18, height: 18)
                .foregroundColor(isSelected ? Theme.textSelected : iconColor)
                .padding(4)
            
            Text(title)
                .font(.system(size: 14, weight: isSelected ? .semibold : .regular))
                .foregroundColor(isSelected ? Theme.textSelected : Theme.textPrimary)
            
            Spacer()

            Text("Command")
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
