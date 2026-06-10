import SwiftUI
import AppKit

class IconManager: ObservableObject {
    static let shared = IconManager()
    private var cache = NSCache<NSString, NSImage>()

    func icon(for iconPath: String, fallbackAppPath appPath: String) -> NSImage? {
        if !iconPath.isEmpty {
            let nsPath = iconPath as NSString
            if let cached = cache.object(forKey: nsPath) {
                return cached
            }
            
            if let image = NSImage(contentsOfFile: iconPath) {
                image.size = NSSize(width: 32, height: 32)
                cache.setObject(image, forKey: nsPath)
                return image
            }
        }
        
        let fallbackKey = "workspace:\(appPath)" as NSString
        if let cached = cache.object(forKey: fallbackKey) {
            return cached
        }

        let image = NSWorkspace.shared.icon(forFile: appPath)
        if image.isValid {
            image.size = NSSize(width: 32, height: 32)
            cache.setObject(image, forKey: fallbackKey)
            return image
        }
        
        return nil
    }

    func getCommandIcon(for commandId: String) -> String {
        switch commandId {
        case "sleep":       return Command.Symbols.sleep
        case "restart":     return Command.Symbols.restart
        case "shutdown":    return Command.Symbols.shutdown
        case "lock":        return Command.Symbols.lock
        case "empty-trash": return Command.Symbols.trash
        case "reset-index": return Command.Symbols.resetIndex
        case "nav-web":       return Command.Symbols.web
        case "nav-shelf":     return Command.Symbols.shelf
        case "nav-clipboard": return Command.Symbols.clipboard
        case "nav-activity":  return Command.Symbols.activity
        case "nav-settings":  return Command.Symbols.settings
        default:            return Command.Symbols.command
        }
    }
}
