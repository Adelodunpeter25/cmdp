import Foundation
import CLibSearch

class SearchService: ObservableObject {
    @Published var results: [SearchResult] = []
    
    private let searchQueue = DispatchQueue(label: "cmdp.search.queue", qos: .userInitiated)
    private let stateQueue = DispatchQueue(label: "cmdp.search.state")
    private var searchRevision: Int = 0
    
    init() {
        // Initialize the Go Engine
        InitEngine()
    }
    
    func search(query: String) {
        let revision = stateQueue.sync {
            searchRevision += 1
            return searchRevision
        }

        searchQueue.async { [weak self] in
            guard let self else { return }

            let searchResults = self.performSearch(query: query)

            let shouldPublish = self.stateQueue.sync {
                revision == self.searchRevision
            }

            guard shouldPublish else { return }

            DispatchQueue.main.async {
                self.results = searchResults
            }
        }
    }
    
    func resetIndex() {
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

