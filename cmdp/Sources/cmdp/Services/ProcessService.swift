import Foundation
import CLibSearch

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
}
