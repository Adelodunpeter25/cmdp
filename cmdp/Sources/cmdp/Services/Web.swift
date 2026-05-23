import Foundation

class WebService: ObservableObject {
    static let shared = WebService()
    
    private init() {}
    
    func searchURL(for query: String) -> URL? {
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if cleanQuery.isEmpty {
            return URL(string: "https://www.google.com")
        }
        
        var components = URLComponents(string: "https://www.google.com/search")
        components?.queryItems = [
            URLQueryItem(name: "q", value: cleanQuery)
        ]
        return components?.url
    }
}
