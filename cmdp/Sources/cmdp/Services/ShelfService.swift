import Foundation
import CLibSearch

class ShelfService: ObservableObject {
    static let shared = ShelfService()
    
    @Published var items: [ShelfItem] = []
    
    private let shelfQueue = DispatchQueue(label: "cmdp.shelf.queue", qos: .userInitiated)
    
    init() {
        fetchItems()
    }
    
    func fetchItems() {
        shelfQueue.async { [weak self] in
            guard let cResult = GetShelfItems() else {
                return
            }
            defer { free(cResult) }
            
            let jsonString = String(cString: cResult)
            guard let data = jsonString.data(using: .utf8) else {
                return
            }
            
            do {
                let decoder = JSONDecoder()
                let fetchedItems = try decoder.decode([ShelfItem].self, from: data)
                
                DispatchQueue.main.async {
                    self?.items = fetchedItems
                }
            } catch {
                print("ShelfService: Failed to decode shelf items: \(error)")
            }
        }
    }
    
    func addToShelf(path: String) {
        shelfQueue.async { [weak self] in
            guard let cPath = (path as NSString).utf8String else { return }
            guard let cResult = AddToShelf(UnsafeMutablePointer(mutating: cPath)) else { return }
            defer { free(cResult) }
            
            // Re-fetch items to ensure state is synchronized
            self?.fetchItems()
        }
    }
    
    func removeFromShelf(id: String) {
        shelfQueue.async { [weak self] in
            guard let cId = (id as NSString).utf8String else { return }
            let _ = RemoveFromShelf(UnsafeMutablePointer(mutating: cId))
            
            self?.fetchItems()
        }
    }
}
