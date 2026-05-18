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
}
