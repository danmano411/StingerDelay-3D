import SwiftUI
import WebKit

/// Embeds the vendored `web-sim` Three.js campus twin (offline).
struct CampusTwinWebView: UIViewRepresentable {
    var reloadToken: Int = 0

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> WKWebView {
        context.coordinator.makeWebView()
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        if context.coordinator.lastReloadToken != reloadToken {
            context.coordinator.lastReloadToken = reloadToken
            context.coordinator.reload(webView)
        }
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKScriptMessageHandler {
        var lastReloadToken: Int = -1
        private var handler: TwinSchemeHandler?
        private(set) var lastError: String?

        func makeWebView() -> WKWebView {
            let config = WKWebViewConfiguration()
            config.defaultWebpagePreferences.allowsContentJavaScript = true
            config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
            config.setValue(true, forKey: "allowUniversalAccessFromFileURLs")

            if let root = Self.twinRoot() {
                let handler = TwinSchemeHandler(twinRoot: root)
                self.handler = handler
                config.setURLSchemeHandler(handler, forURLScheme: TwinSchemeHandler.scheme)
            }

            let controller = config.userContentController
            controller.add(self, name: "twinLog")
            controller.addUserScript(WKUserScript(
                source: """
                (function(){
                  const post = (level, args) => {
                    try {
                      window.webkit.messageHandlers.twinLog.postMessage({
                        level: level,
                        message: Array.from(args).map(String).join(' ')
                      });
                    } catch (e) {}
                  };
                  const wrap = (level, fn) => function(){ post(level, arguments); return fn.apply(console, arguments); };
                  console.log = wrap('log', console.log);
                  console.warn = wrap('warn', console.warn);
                  console.error = wrap('error', console.error);
                  window.addEventListener('error', ev => post('error', [ev.message]));
                  window.addEventListener('unhandledrejection', ev => post('error', [ev.reason]));
                })();
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            ))

            let webView = WKWebView(frame: .zero, configuration: config)
            webView.isOpaque = false
            webView.backgroundColor = .black
            webView.scrollView.isScrollEnabled = false
            webView.scrollView.bounces = false
            webView.navigationDelegate = self
            reload(webView)
            return webView
        }

        func reload(_ webView: WKWebView) {
            guard Self.twinRoot() != nil else {
                lastError = "Twin folder missing — rebuild the app (Copy Twin Folder phase)."
                webView.loadHTMLString(Self.errorHTML(lastError!), baseURL: nil)
                return
            }
            // Custom scheme keeps relative ./vendor/... imports working
            let url = URL(string: "\(TwinSchemeHandler.scheme)://twin/index.html")!
            webView.load(URLRequest(url: url))
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let level = body["level"] as? String,
                  let text = body["message"] as? String
            else { return }
            print("[Twin \(level)] \(text)")
            if level == "error" { lastError = text }
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Twin nav fail: \(error.localizedDescription)")
            webView.loadHTMLString(Self.errorHTML(error.localizedDescription), baseURL: nil)
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("Twin provisional fail: \(error.localizedDescription)")
            webView.loadHTMLString(Self.errorHTML(error.localizedDescription), baseURL: nil)
        }

        private static func twinRoot() -> URL? {
            Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Twin")?
                .deletingLastPathComponent()
        }

        private static func errorHTML(_ message: String) -> String {
            let safe = message
                .replacingOccurrences(of: "&", with: "&amp;")
                .replacingOccurrences(of: "<", with: "&lt;")
            return """
            <html><body style="background:#070a10;color:#EAAA00;font:15px -apple-system;padding:24px;line-height:1.4">
            <h3 style="color:#fff;margin:0 0 8px">3D twin failed to load</h3>
            <p>\(safe)</p>
            <p style="color:#8591a5">In Xcode: Product → Clean Build Folder, then ▶ Run on this Simulator.</p>
            </body></html>
            """
        }
    }
}
