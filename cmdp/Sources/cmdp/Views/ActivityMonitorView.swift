import SwiftUI
import CLibSearch

struct ActivityMonitorView: View {
    let processes: [ProcessInfo]
    @Binding var searchText: String
    @Binding var selectedIndex: Int
    @Binding var isActivityMonitorMode: Bool
    @Binding var processSortByCPU: Bool
    let onKill: (ProcessInfo, _ force: Bool) -> Void
    
    var body: some View {
        VStack(spacing: 0) {
            // Sort by CPU or Memory header
            HStack {
                Text("SORT BY:")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(Theme.textSecondary.opacity(0.8))
                
                Button(action: {
                    processSortByCPU = false
                    selectedIndex = 0
                }) {
                    Text("Memory")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(!processSortByCPU ? Theme.selectionBackground : Color.clear)
                        .foregroundColor(!processSortByCPU ? Theme.textPrimary : Theme.textSecondary)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)

                Button(action: {
                    processSortByCPU = true
                    selectedIndex = 0
                }) {
                    Text("CPU")
                        .font(.system(size: 10, weight: .bold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(processSortByCPU ? Theme.selectionBackground : Color.clear)
                        .foregroundColor(processSortByCPU ? Theme.textPrimary : Theme.textSecondary)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
                
                Spacer()
                
                Button(action: {
                    isActivityMonitorMode = false
                    searchText = ""
                    selectedIndex = 0
                }) {
                    Text("Back")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(.red.opacity(0.8))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(Theme.hoverBackground)
                        .cornerRadius(4)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Theme.windowBackground.opacity(0.5))
            
            Divider()
            
            if processes.isEmpty {
                HStack {
                    Spacer()
                    Text("No processes found")
                        .font(.system(size: 13))
                        .foregroundColor(Theme.textSecondary)
                        .padding()
                    Spacer()
                }
                .frame(height: 140)
            } else {
                ScrollView {
                    LazyVStack(spacing: Theme.rowSpacing) {
                        ForEach(Array(processes.enumerated()), id: \.element.pid) { idx, proc in
                            ProcessRow(proc: proc, isCPU: processSortByCPU, isSelected: selectedIndex == idx)
                                .onTapGesture {
                                    selectedIndex = idx
                                }
                                .contextMenu {
                                    Button("Kill") {
                                        onKill(proc, false)
                                    }
                                    Button("Force Kill") {
                                        onKill(proc, true)
                                    }
                                    Divider()
                                    Button("Copy PID") {
                                        let pasteboard = NSPasteboard.general
                                        pasteboard.clearContents()
                                        pasteboard.setString(String(proc.pid), forType: .string)
                                    }
                                }
                        }
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 8)
                }
                .frame(maxHeight: 280)
                .scrollIndicators(.hidden)
            }
        }
        .transition(.opacity)
    }
}

struct ProcessRow: View {
    let proc: ProcessInfo
    let isCPU: Bool
    let isSelected: Bool
    @State private var isHovered = false
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "cpu")
                .font(.system(size: 12))
                .foregroundColor(isSelected ? Theme.textSelected.opacity(0.8) : Theme.textSecondary)
            
            VStack(alignment: .leading, spacing: 1) {
                Text(proc.name)
                    .font(.system(size: 13, weight: isSelected ? .semibold : .regular))
                    .foregroundColor(isSelected ? Theme.textSelected : Theme.textPrimary)
                    .lineLimit(1)
                Text("PID: \(proc.pid)")
                    .font(.system(size: 9))
                    .foregroundColor(isSelected ? Theme.textSelected.opacity(0.7) : Theme.textSecondary)
            }
            
            Spacer()
            
            if isCPU {
                Text(String(format: "%.1f CPU", proc.cpu))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? Theme.textSelected : Theme.textPrimary)
            } else {
                Text(formatMemory(proc.memory))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundColor(isSelected ? Theme.textSelected : Theme.textPrimary)
            }
        }
        .padding(.vertical, 6)
        .padding(.horizontal, 10)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(isSelected ? Theme.selectionBackground : (isHovered ? Theme.hoverBackground : Color.clear))
        )
        .onHover { isHovered = $0 }
        .contentShape(Rectangle())
    }
    
    private func formatMemory(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
