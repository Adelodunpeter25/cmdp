import Foundation
import AppKit
import CLibSearch

class ClipboardService: ObservableObject {
    static let shared = ClipboardService()
    
    @Published var items: [ClipboardItem] = []
    
    private let clipboardQueue = DispatchQueue(label: "cmdp.clipboard.queue", qos: .userInitiated)
    private var lastChangeCount = -1
    private var pollTimer: Timer? = nil
    
    init() {
        startWatching()
        fetchItems()
    }
    
    func startWatching() {
        // Start polling the clipboard every 800ms
        pollTimer = Timer.scheduledTimer(withTimeInterval: 0.8, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
    }
    
    func stopWatching() {
        pollTimer?.invalidate()
        pollTimer = nil
    }
    
    private func checkClipboard() {
        let changeCount = NSPasteboard.general.changeCount
        if lastChangeCount == -1 {
            lastChangeCount = changeCount
            return
        }
        if changeCount == lastChangeCount {
            return
        }
        lastChangeCount = changeCount
        
        if let content = NSPasteboard.general.string(forType: .string), !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            saveItem(content: content)
        }
    }
    
    func saveItem(content: String) {
        clipboardQueue.async { [weak self] in
            guard let cContent = (content as NSString).utf8String else { return }
            SaveClipboardItem(UnsafeMutablePointer(mutating: cContent))
            self?.fetchItems()
        }
    }
    
    func fetchItems() {
        clipboardQueue.async { [weak self] in
            guard let cResult = GetClipboardItems() else {
                return
            }
            defer { free(cResult) }
            
            let jsonString = String(cString: cResult)
            guard let data = jsonString.data(using: .utf8) else {
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let fetchedItems = try decoder.decode([ClipboardItem].self, from: data)
                
                DispatchQueue.main.async {
                    self?.items = fetchedItems
                }
            } catch {
                print("ClipboardService: Failed to decode clipboard items: \(error)")
            }
        }
    }
    
    func deleteItem(id: String) {
        clipboardQueue.async { [weak self] in
            guard let cId = (id as NSString).utf8String else { return }
            let _ = RemoveFromClipboard(UnsafeMutablePointer(mutating: cId))
            self?.fetchItems()
        }
    }
    
    func copyToClipboard(content: String) {
        let pb = NSPasteboard.general
        pb.clearContents()
        pb.setString(content, forType: .string)
        self.lastChangeCount = pb.changeCount
    }
}
