import SwiftUI

struct SearchListView: View {
    let displayItems: [DisplayItem]
    let groupedResults: [SearchResult]
    @Binding var selectedIndex: Int
    @Binding var hoveredIndex: Int?
    let onTapRow: (Int, SearchResult) -> Void

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: Theme.rowSpacing, pinnedViews: [.sectionHeaders]) {
                    ForEach(displayItems) { item in
                        switch item {
                        case .header(let title):
                            sectionHeader(title)

                        case .result(let result, let index):
                            ResultRow(
                                result: result,
                                isSelected: selectedIndex == index,
                                isHovered: hoveredIndex == index
                            )
                            .onHover { hoveredIndex = $0 ? index : nil }
                            .onTapGesture {
                                onTapRow(index, result)
                            }
                            .id(item.id)
                        }
                    }
                }
                .padding(.horizontal, 8)
                .padding(.vertical, 8)
            }
            .frame(maxHeight: 350)
            .scrollIndicators(.hidden)
            .onChange(of: selectedIndex) { _ in
                let targetId = "result-\(selectedIndex)-\(groupedResults[safe: selectedIndex]?.id ?? "")"
                proxy.scrollTo(targetId, anchor: .center)
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        HStack {
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.textSecondary.opacity(0.8))
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
            Spacer()
        }
        .background(VisualEffectView(material: .hudWindow, blendingMode: .behindWindow))
    }
}
