import SwiftUI

struct HomeDashboardView: View {
    @Binding var selectedIndex: Int
    @Binding var hoveredIndex: Int?
    @Binding var isWebSearchMode: Bool
    @Binding var isShelfMode: Bool
    @Binding var searchText: String
    @Binding var processSortByCPU: Bool
    @ObservedObject var processService: ProcessService
    let onOpenActivityMonitor: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            WebSearchCard(
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
            
            OpenShelfCard(
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

            if let stats = processService.systemStats {
                HStack(spacing: 12) {
                    CPUProcessCard(stats: stats) {
                        processSortByCPU = true
                        onOpenActivityMonitor()
                    }
                    MemoryProcessCard(stats: stats) {
                        processSortByCPU = false
                        onOpenActivityMonitor()
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .transition(.opacity)
            } else {
                HStack {
                    Spacer()
                    ProgressView()
                        .scaleEffect(0.8)
                        .padding()
                    Text("Loading system stats...")
                        .font(.system(size: 12))
                        .foregroundColor(Theme.textSecondary)
                    Spacer()
                }
                .frame(height: 140)
            }
        }
    }
}
