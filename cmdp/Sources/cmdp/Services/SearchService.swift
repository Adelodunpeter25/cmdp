import Foundation
import CLibSearch

class SearchService: ObservableObject {
    @Published var results: [AppResult] = []
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
        let searchText = isCmdMode ? String(query.dropFirst()).trimmingCharacters(in: .whitespaces) : query

        searchQueue.async { [weak self] in
            guard let self else { return }

            var searchResults: [AppResult] = []
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
                self.isCommandMode = isCmdMode
                self.results = searchResults
                self.commandResults = cmdResults
            }
        }
    }
    
    func select(app: AppResult) {
        app.App.Path.withCString { cPath in
            MarkSelected(UnsafeMutablePointer(mutating: cPath))
        }
    }

    private func performSearch(query: String) -> [AppResult] {
        var decodedResults: [AppResult] = []

        query.withCString { cQuery in
            guard let cResult = SearchApps(UnsafeMutablePointer(mutating: cQuery)) else {
                return
            }

            let jsonString = String(cString: cResult)
            free(cResult)

            guard let data = jsonString.data(using: .utf8) else {
                return
            }

            do {
                let decoder = JSONDecoder()
                decodedResults = try decoder.decode([AppResult].self, from: data)
            } catch {
                print("SearchService: Failed to decode JSON: \(error)")
            }
        }

        return decodedResults
    }
}
