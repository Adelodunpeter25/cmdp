import Foundation

enum ItemType: String, Codable {
    case app = "app"
    case folder = "folder"
    case command = "command"
    case file = "file"
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

struct ProcessInfo: Codable, Identifiable, Equatable {
    var id: Int32 { pid }
    let pid: Int32
    let name: String
    let cpu: Double
    let memory: UInt64
}

struct SystemStats: Codable, Equatable {
    let cpuUsage: Double
    let totalMemory: UInt64
    let usedMemory: UInt64
    let topMemoryProcs: [ProcessInfo]
    let topCPUProcs: [ProcessInfo]
}
