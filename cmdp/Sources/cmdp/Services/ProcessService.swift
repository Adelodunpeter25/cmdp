import Foundation
import CLibSearch
import AppKit

class ProcessService: ObservableObject {
    @Published var systemStats: SystemStats? = nil
    
    private let statsQueue = DispatchQueue(label: "cmdp.stats.queue", qos: .background)
    private var statsTimer: Timer? = nil
    private var isPolling = false

    func startPolling() {
        guard !isPolling else { return }
        isPolling = true
        fetchSystemStats()
        
        statsTimer = Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchSystemStats()
        }
    }

    func stopPolling() {
        guard isPolling else { return }
        isPolling = false
        statsTimer?.invalidate()
        statsTimer = nil
    }

    func fetchSystemStats() {
        statsQueue.async { [weak self] in
            guard let self = self, self.isPolling else { return }
            
            guard let cResult = GetSystemStats() else {
                return
            }
            defer { free(cResult) }

            let jsonString = String(cString: cResult)
            guard let data = jsonString.data(using: .utf8) else {
                return
            }

            do {
                let decoder = JSONDecoder()
                let stats = try decoder.decode(SystemStats.self, from: data)
                
                DispatchQueue.main.async {
                    if self.isPolling {
                        self.systemStats = stats
                    }
                }
            } catch {
                print("ProcessService: Failed to decode system stats: \(error)")
            }
        }
    }

    func filteredProcesses(searchText: String, processSortByCPU: Bool) -> [ProcessInfo] {
        guard let stats = systemStats else { return [] }
        var seenPids = Set<Int32>()
        var mergedProcs: [ProcessInfo] = []
        
        let primaryList = processSortByCPU ? stats.topCPUProcs : stats.topMemoryProcs
        let secondaryList = processSortByCPU ? stats.topMemoryProcs : stats.topCPUProcs
        
        for proc in primaryList {
            if !seenPids.contains(proc.pid) {
                seenPids.insert(proc.pid)
                mergedProcs.append(proc)
            }
        }
        for proc in secondaryList {
            if !seenPids.contains(proc.pid) {
                seenPids.insert(proc.pid)
                mergedProcs.append(proc)
            }
        }
        
        if !searchText.isEmpty {
            let query = searchText.lowercased()
            mergedProcs = mergedProcs.filter { $0.name.lowercased().contains(query) }
        }
        
        if processSortByCPU {
            mergedProcs.sort { $0.cpu > $1.cpu }
        } else {
            mergedProcs.sort { $0.memory > $1.memory }
        }
        
        return Array(mergedProcs.prefix(7))
    }

    func confirmKillProcess(_ proc: ProcessInfo, force: Bool) {
        let alert = NSAlert()
        alert.messageText = force ? "Force Quit Process?" : "Quit Process?"
        alert.informativeText = force ? 
            "Are you sure you want to force quit '\(proc.name)' (PID: \(String(proc.pid)))? Any unsaved changes will be lost." : 
            "Are you sure you want to quit '\(proc.name)' (PID: \(String(proc.pid)))?"
        alert.alertStyle = .warning
        alert.addButton(withTitle: force ? "Force Quit" : "Quit")
        alert.addButton(withTitle: "Cancel")
        
        if alert.runModal() == .alertFirstButtonReturn {
            let success = KillProcess(proc.pid, force ? 1 : 0) == 1
            if success {
                // Immediately refresh stats to update list
                fetchSystemStats()
            } else {
                let failAlert = NSAlert()
                failAlert.messageText = "Failed to Terminate Process"
                failAlert.informativeText = "Could not terminate process '\(proc.name)' (PID: \(String(proc.pid))). You might not have permission."
                failAlert.alertStyle = .critical
                failAlert.addButton(withTitle: "OK")
                failAlert.runModal()
            }
        }
    }
}
