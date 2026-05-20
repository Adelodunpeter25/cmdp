import Foundation
import CLibSearch

class SearchService: ObservableObject {
    @Published var results: [SearchResult] = []
    @Published var commandResults: [Command] = []
    @Published var isCommandMode: Bool = false
    
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

        let isCmdMode = query.hasPrefix(">")
        
        // Update mode and clear irrelevant results immediately on the main thread
        // to prevent stale data from showing during the transition.
        DispatchQueue.main.async {
            self.isCommandMode = isCmdMode
            if isCmdMode {
                self.results = []
            } else {
                self.commandResults = []
            }
        }

        let searchText = isCmdMode ? String(query.dropFirst()).trimmingCharacters(in: .whitespaces) : query

        searchQueue.async { [weak self] in
            guard let self else { return }

            var searchResults: [SearchResult] = []
            var cmdResults: [Command] = []

            if isCmdMode {
                if searchText.isEmpty {
                    cmdResults = Command.allCommands
                } else {
                    cmdResults = Command.allCommands.filter { 
                        $0.name.lowercased().contains(searchText.lowercased()) 
                    }
                }
            } else {
                searchResults = self.performSearch(query: searchText)
            }

            let shouldPublish = self.stateQueue.sync {
                revision == self.searchRevision
            }

            guard shouldPublish else { return }

            DispatchQueue.main.async {
                self.results = searchResults
                self.commandResults = cmdResults
            }
        }
    }
    
    func resetIndex() {
        ResetIndex()
    }

    private func performSearch(query: String) -> [SearchResult] {
        var decodedResults: [SearchResult] = []

        query.withCString { cQuery in
            guard let cResult = SearchApps(UnsafeMutablePointer(mutating: cQuery)) else {
                return
            }
            defer { free(cResult) }

            let jsonString = String(cString: cResult)

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

