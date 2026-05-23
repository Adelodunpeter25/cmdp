import SwiftUI
import WebKit

struct WebView: NSViewRepresentable {
    let url: URL
    
    func makeNSView(context: Context) -> WKWebView {
        let webView = WKWebView()
        webView.customUserAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/17.0 Safari/605.1.15"
        
        // Make the background transparent to blend nicely with the HUD material
        webView.setValue(false, forKey: "drawsBackground")
        
        // Force dark mode rendering
        webView.appearance = NSAppearance(named: .darkAqua)
        
        let request = URLRequest(url: url)
        webView.load(request)
        return webView
    }
    
    func updateNSView(_ nsView: WKWebView, context: Context) {
        // Normalize URLs before comparison
        let currentURLString = nsView.url?.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        let targetURLString = url.absoluteString.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        
        if currentURLString != targetURLString {
            let request = URLRequest(url: url)
            nsView.load(request)
        }
    }
}
