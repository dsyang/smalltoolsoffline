import SwiftUI
import WebKit

@MainActor
final class WebViewPool {
    static let shared = WebViewPool()

    private var warm: WKWebView?

    private init() {}

    func warmUp() {
        guard warm == nil else { return }
        warm = createWebView()
    }

    func dequeue() -> WKWebView {
        let view = warm ?? createWebView()
        warm = nil
        // Immediately prepare the next one
        warm = createWebView()
        return view
    }

    private func createWebView() -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.isElementFullscreenEnabled = true
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isInspectable = true
        webView.scrollView.bounces = false
        webView.isOpaque = false
        webView.backgroundColor = .clear
        return webView
    }
}

struct WebView: UIViewRepresentable {
    let fileURL: URL

    func makeUIView(context: Context) -> WKWebView {
        WebViewPool.shared.dequeue()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        let dir = fileURL.deletingLastPathComponent()
        webView.loadFileURL(fileURL, allowingReadAccessTo: dir)
    }
}
