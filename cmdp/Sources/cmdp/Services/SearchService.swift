import Foundation
import CLibSearch

class SearchService: ObservableObject {
    @Published var results: [AppResult] = []
    
    init() {
        // Initialize the Go Engine
        InitEngine()
    }
    
    func search(query: String) {
        query.withCString { cQuery in
            // Call the Go function
            // Note: Go returns a C string that we must free
            guard let cResult = SearchApps(UnsafeMutablePointer(mutating: cQuery)) else {
                DispatchQueue.main.async {
                    self.results = []
                }
                return
            }
            
            // Convert C string back to Swift Data
            let jsonString = String(cString: cResult)
            
            // VERY IMPORTANT: Free the C string allocated by Go's C.CString
            free(cResult)
            
            guard let data = jsonString.data(using: .utf8) else {
                DispatchQueue.main.async {
                    self.results = []
                }
                return
            }
            
            // Parse JSON
            do {
                let decoder = JSONDecoder()
                let searchResults = try decoder.decode([AppResult].self, from: data)
                DispatchQueue.main.async {
                    self.results = searchResults
                }
            } catch {
                print("SearchService: Failed to decode JSON: \(error)")
                DispatchQueue.main.async {
                    self.results = []
                }
            }
        }
    }
    
    func select(app: AppResult) {
        app.App.Path.withCString { cPath in
            MarkSelected(UnsafeMutablePointer(mutating: cPath))
        }
    }
}
