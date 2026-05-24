import SwiftUI

struct HomeDashboardView: View {
    @Binding var selectedIndex: Int
    @Binding var hoveredIndex: Int?
    @Binding var isWebSearchMode: Bool
    @Binding var searchText: String
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

            if let stats = processService.systemStats {
                ProcessCard(stats: stats)
                    .onTapGesture {
                        onOpenActivityMonitor()
                    }
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
