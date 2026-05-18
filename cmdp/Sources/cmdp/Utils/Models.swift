import Foundation

struct AppResult: Codable, Identifiable {
    var id: String { App.Path }
    let App: AppInfo
    let Score: Int
}

struct AppInfo: Codable {
    let Name: String
    let Path: String
    let IconPath: String
}
