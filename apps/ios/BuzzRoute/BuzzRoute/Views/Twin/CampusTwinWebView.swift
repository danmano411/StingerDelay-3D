import SwiftUI
import WebKit

/// Embeds the vendored `web-sim` Three.js campus twin (offline).
/// Twin files are copied as a real folder by the "Copy Twin Folder" build phase.
struct CampusTwinWebView: UIViewRepresentable {
    var reloadToken: Int = 0

    func makeUIView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.defaultWebpagePreferences.allowsContentJavaScript = true
        config.preferences.javaScriptCanOpenWindowsAutomatically = false

        let webView = WKWebView(frame: .zero, configuration: config)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.isScrollEnabled = false
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator
        context.coordinator.loadTwin(into: webView)
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            context.coordinator.loadTwin(into: webView)
        }
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        var lastReloadToken: Int = -1

        func loadTwin(into webView: WKWebView) {
            guard let index = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Twin") else {
                webView.loadHTMLString(
                    """
                    <html><body style="background:#070a10;color:#EAAA00;font:16px -apple-system;padding:24px">
                    Twin folder missing from app bundle. Rebuild so the Copy Twin Folder phase runs.
                    </body></html>
                    """,
                    baseURL: nil
                )
                return
            }
            let root = index.deletingLastPathComponent()
            webView.loadFileURL(index, allowingReadAccessTo: root)
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Twin navigation failed: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("Twin provisional failed: \(error.localizedDescription)")
        }
    }
}
