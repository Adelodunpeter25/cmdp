import SwiftUI

struct CPUProcessCard: View {
    let stats: SystemStats
    @State private var isHovered = false
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            metricHeader(title: "CPU USAGE", value: String(format: "%.1f%%", stats.cpuUsage), icon: "cpu")
            
            progressBar(value: CGFloat(stats.cpuUsage / 100.0), color: Color.accentColor)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("TOP CPU PROCESSES")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.textSecondary.opacity(0.8))
                    .padding(.bottom, 2)
                
                ForEach(stats.topCPUProcs.prefix(3)) { proc in
                    processRow(name: proc.name, metric: String(format: "%.1f%%", proc.cpu))
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowCornerRadius)
                .fill(isHovered ? Theme.hoverBackground.opacity(0.6) : Theme.hoverBackground.opacity(0.3))
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
        .contentShape(Rectangle())
    }

    private func metricHeader(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
        }
    }

    private func progressBar(value: CGFloat, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.hoverBackground)
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: geo.size.width * min(max(value, 0.0), 1.0), height: 6)
            }
        }
        .frame(height: 6)
    }

    private func processRow(name: String, metric: String) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
            Spacer()
            Text(metric)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
    }
}

struct MemoryProcessCard: View {
    let stats: SystemStats
    @State private var isHovered = false
    let onTap: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            let usedGB = Double(stats.usedMemory) / 1_073_741_824.0
            let totalGB = Double(stats.totalMemory) / 1_073_741_824.0
            let memoryPercent = stats.totalMemory > 0 ? Double(stats.usedMemory) / Double(stats.totalMemory) : 0.0
            
            metricHeader(title: "MEMORY", value: String(format: "%.1f GB / %.1f GB", usedGB, totalGB), icon: "memorychip")
            
            progressBar(value: CGFloat(memoryPercent), color: Color.purple)
            
            VStack(alignment: .leading, spacing: 6) {
                Text("TOP MEMORY PROCESSES")
                    .font(.system(size: 9, weight: .bold))
                    .foregroundColor(Theme.textSecondary.opacity(0.8))
                    .padding(.bottom, 2)
                
                ForEach(stats.topMemoryProcs.prefix(3)) { proc in
                    let memFormatted = formatMemory(proc.memory)
                    processRow(name: proc.name, metric: memFormatted)
                }
            }
            .padding(.top, 4)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background(
            RoundedRectangle(cornerRadius: Theme.rowCornerRadius)
                .fill(isHovered ? Theme.hoverBackground.opacity(0.6) : Theme.hoverBackground.opacity(0.3))
        )
        .onHover { hovering in
            isHovered = hovering
        }
        .onTapGesture {
            onTap()
        }
        .contentShape(Rectangle())
    }

    private func metricHeader(title: String, value: String, icon: String) -> some View {
        HStack(spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
            Text(title)
                .font(.system(size: 10, weight: .bold))
                .foregroundColor(Theme.textSecondary)
            Spacer()
            Text(value)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textPrimary)
        }
    }

    private func progressBar(value: CGFloat, color: Color) -> some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: 3)
                    .fill(Theme.hoverBackground)
                    .frame(height: 6)
                
                RoundedRectangle(cornerRadius: 3)
                    .fill(color)
                    .frame(width: geo.size.width * min(max(value, 0.0), 1.0), height: 6)
            }
        }
        .frame(height: 6)
    }

    private func processRow(name: String, metric: String) -> some View {
        HStack {
            Text(name)
                .font(.system(size: 11, weight: .regular))
                .foregroundColor(Theme.textPrimary)
                .lineLimit(1)
            Spacer()
            Text(metric)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(Theme.textSecondary)
        }
    }

    private func formatMemory(_ bytes: UInt64) -> String {
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useAll]
        formatter.countStyle = .memory
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
