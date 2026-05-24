import Foundation

enum DisplayItem: Identifiable {
    case header(String)
    /// result + its global index in the flattened display order
    case result(SearchResult, Int)

    var id: String {
        switch self {
        case .header(let title):      return "header-\(title)"
        case .result(let r, let i):  return "result-\(i)-\(r.id)"
        }
    }

    /// Global index for scroll-to and selectedIndex matching.
    /// Headers return nil — they are never selectable.
    var globalIndex: Int? {
        if case .result(_, let i) = self { return i }
        return nil
    }
}
