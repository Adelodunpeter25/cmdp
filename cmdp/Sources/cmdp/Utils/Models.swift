import Foundation

enum ItemType: String, Codable {
    case app = "app"
    case folder = "folder"
    case command = "command"
}

struct SearchResult: Codable, Identifiable, Equatable {
    var id: String { Item.Path }
    let Item: IndexItem
    let Score: Int
}

struct IndexItem: Codable, Equatable {
    let Name: String
    let Path: String
    let IconPath: String
    let itemType: ItemType
    
    enum CodingKeys: String, CodingKey {
        case Name
        case Path
        case IconPath = "IconPath"
        case itemType = "Type"
    }
}
