import SwiftUI
import AppKit

struct Theme {
    // Colors
    static let windowBackground = Color(NSColor.windowBackgroundColor).opacity(0.8)
    static let selectionBackground = Color.accentColor
    static let hoverBackground = Color.primary.opacity(0.05)
    
    static let textPrimary = Color.primary
    static let textSecondary = Color.secondary
    static let textSelected = Color.white
    
    static let searchIconColor = Color.gray
    
    // Layout
    static let windowCornerRadius: CGFloat = 12
    static let rowCornerRadius: CGFloat = 6
    static let iconSize: CGFloat = 32
    static let rowPaddingVertical: CGFloat = 6
    static let rowPaddingHorizontal: CGFloat = 10
    static let rowSpacing: CGFloat = 2
}
