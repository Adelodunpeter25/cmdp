import SwiftUI

struct HomeDashboardView: View {
    @Binding var selectedIndex: Int
    @Binding var hoveredIndex: Int?
    @Binding var isWebSearchMode: Bool
    @Binding var isShelfMode: Bool
    @Binding var isClipboardMode: Bool
    @Binding var isSettingsMode: Bool
    @Binding var searchText: String
    @Binding var processSortByCPU: Bool
    @ObservedObject var processService: ProcessService
    let onOpenActivityMonitor: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            DashboardCommandRow(
                iconName: Command.Symbols.web,
                title: "Web Search",
                iconColor: .blue,
                isSelected: selectedIndex == 0,
                isHovered: hoveredIndex == 0
            )
            .onHover { hoveredIndex = $0 ? 0 : nil }
            .onTapGesture {
                isWebSearchMode = true
                searchText = ""
                selectedIndex = 0
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            DashboardCommandRow(
                iconName: Command.Symbols.shelf,
                title: "Open Shelf",
                iconColor: .orange,
                isSelected: selectedIndex == 1,
                isHovered: hoveredIndex == 1
            )
            .onHover { hoveredIndex = $0 ? 1 : nil }
            .onTapGesture {
                isShelfMode = true
                searchText = ""
                selectedIndex = 0
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            DashboardCommandRow(
                iconName: Command.Symbols.clipboard,
                title: "Open Clipboard",
                iconColor: .green,
                isSelected: selectedIndex == 2,
                isHovered: hoveredIndex == 2
            )
            .onHover { hoveredIndex = $0 ? 2 : nil }
            .onTapGesture {
                isClipboardMode = true
                searchText = ""
                selectedIndex = 0
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            DashboardCommandRow(
                iconName: Command.Symbols.activity,
                title: "Open Activity Monitor",
                iconColor: .purple,
                isSelected: selectedIndex == 3,
                isHovered: hoveredIndex == 3
            )
            .onHover { hoveredIndex = $0 ? 3 : nil }
            .onTapGesture {
                onOpenActivityMonitor()
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)

            DashboardCommandRow(
                iconName: Command.Symbols.settings,
                title: "Settings",
                iconColor: .gray,
                isSelected: selectedIndex == 4,
                isHovered: hoveredIndex == 4
            )
            .onHover { hoveredIndex = $0 ? 4 : nil }
            .onTapGesture {
                isSettingsMode = true
                searchText = ""
                selectedIndex = 0
            }
            .padding(.horizontal, 8)
            .padding(.top, 8)
            
            Divider()
                .padding(.top, 8)
                .opacity(0.4)
            
            HStack(spacing: 8) {
                if let stats = processService.systemStats {
                    // CPU Pill
                    Button(action: {
                        processSortByCPU = true
                        onOpenActivityMonitor()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: Command.Symbols.activity)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textSecondary)
                            Text(String(format: "%.0f%%", stats.cpuUsage))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Theme.hoverBackground)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                    
                    Spacer()
                    
                    // Memory Pill
                    Button(action: {
                        processSortByCPU = false
                        onOpenActivityMonitor()
                    }) {
                        HStack(spacing: 4) {
                            Image(systemName: Command.Symbols.memory)
                                .font(.system(size: 10))
                                .foregroundColor(Theme.textSecondary)
                            let usedPercent = Double(stats.usedMemory) / Double(stats.totalMemory) * 100
                            Text(String(format: "%.0f%%", usedPercent))
                                .font(.system(size: 10, weight: .semibold))
                                .foregroundColor(Theme.textPrimary)
                        }
                        .padding(.vertical, 4)
                        .padding(.horizontal, 8)
                        .background(Theme.hoverBackground)
                        .cornerRadius(12)
                    }
                    .buttonStyle(PlainButtonStyle())
                } else {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: 12, height: 12)
                    Text("Loading system stats...")
                        .font(.system(size: 10))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
        }
    }
}
