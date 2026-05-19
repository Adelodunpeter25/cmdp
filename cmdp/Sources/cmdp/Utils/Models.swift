import Foundation

struct AppResult: Codable, Identifiable, Equatable {
    var id: String { App.Path }
    let App: AppInfo
    let Score: Int
}

struct AppInfo: Codable, Equatable {
    let Name: String
    let Path: String
    let IconPath: String
}
