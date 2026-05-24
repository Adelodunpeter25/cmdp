import AppKit

extension NSView {
    func closestHostingView() -> NSView? {
        className.contains("HostingView") ? self : superview?.closestHostingView()
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
