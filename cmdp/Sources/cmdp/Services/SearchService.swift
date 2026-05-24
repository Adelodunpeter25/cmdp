import Foundation
import CLibSearch

class SearchService: ObservableObject {
    @Published var results: [SearchResult] = []
    
    // Thread-safe atomic counter for deduplication
    private var searchCounter: Int = 0
    private let counterLock = NSLock()
    
    // Separate search queue to handle blocking C API calls
    private let searchQueue = DispatchQueue(label: "cmdp.search.queue", qos: .userInitiated)
    
    init() {
        // Initialize the Go Engine
        InitEngine()
    }
    
    func search(query: String) {
        let isFileSearch = query.hasPrefix("/")
        let currentHasFiles = results.contains { $0.Item.itemType == .file }
        if isFileSearch != currentHasFiles {
            self.results = []
        }

        if query == "/" {
            self.results = []
            return
        }

        // Get unique counter value
        counterLock.lock()
        let counter = searchCounter
        counterLock.unlock()
        
        // Perform search on background queue
        searchQueue.async { [weak self] in
            guard let self else { return }

            let searchResults = self.performSearch(query: query)

            // Check if this result is still the latest
            counterLock.lock()
            let isValid = counter == self.searchCounter
            counterLock.unlock()
            
            guard isValid else { return }

            DispatchQueue.main.async {
                self.results = searchResults
            }
        }
    }
    
    func resetIndex() {
        // Reset counter to invalidate any pending searches
        counterLock.lock()
        searchCounter = 0
        counterLock.unlock()
        ResetIndex()
    }

    private func performSearch(query: String) -> [SearchResult] {
        var decodedResults: [SearchResult] = []

        let isFileSearch = query.hasPrefix("/")
        let cleanQuery = isFileSearch ? String(query.dropFirst()) : query

        cleanQuery.withCString { cQuery in
            let cResult: UnsafeMutablePointer<Int8>?
            if isFileSearch {
                cResult = SearchFiles(UnsafeMutablePointer(mutating: cQuery))
            } else {
                cResult = SearchApps(UnsafeMutablePointer(mutating: cQuery))
            }

            guard let rawResult = cResult else {
                return
            }
            defer { free(rawResult) }

            let jsonString = String(cString: rawResult)

            guard let data = jsonString.data(using: .utf8) else {
                return
            }

            do {
                let decoder = JSONDecoder()
                decodedResults = try decoder.decode([SearchResult].self, from: data)
            } catch {
                print("SearchService: Failed to decode JSON: \(error)")
            }
        }

        return decodedResults
    }
    }

