import SwiftUI
import AppKit

class IconManager: ObservableObject {
    static let shared = IconManager()
    private var cache = NSCache<NSString, NSImage>()

    func icon(for path: String) -> NSImage? {
        if path.isEmpty { return nil }
        
        let nsPath = path as NSString
        if let cached = cache.object(forKey: nsPath) {
            return cached
        }

        // Load and cache
        if let image = NSImage(contentsOfFile: path) {
            // Resize for list display to save memory and rendering time
            image.size = NSSize(width: 32, height: 32)
            cache.setObject(image, forKey: nsPath)
            return image
        }
        
        return nil
    }
}
