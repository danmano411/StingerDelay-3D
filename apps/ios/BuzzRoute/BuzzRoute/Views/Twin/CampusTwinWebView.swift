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
        private var schemeHandler: TwinSchemeHandler?

        func makeWebView() -> WKWebView {
            let config = WKWebViewConfiguration()
            config.defaultWebpagePreferences.allowsContentJavaScript = true

            if let root = Self.twinRoot() {
                let handler = TwinSchemeHandler(twinRoot: root)
                schemeHandler = handler
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
                  const wrap = (level, fn) => function(){
                    post(level, arguments);
                    return fn.apply(console, arguments);
                  };
                  console.log = wrap('log', console.log);
                  console.warn = wrap('warn', console.warn);
                  console.error = wrap('error', console.error);
                  window.addEventListener('error', ev => post('error', [ev.message]));
                })();
                """,
                injectionTime: .atDocumentStart,
                forMainFrameOnly: false
            ))

            let webView = WKWebView(frame: .zero, configuration: config)
            let bg = UIColor(red: 0.03, green: 0.04, blue: 0.06, alpha: 1)
            webView.isOpaque = true
            webView.backgroundColor = bg
            webView.scrollView.backgroundColor = bg
            webView.scrollView.isScrollEnabled = false
            webView.scrollView.bounces = false
            if #available(iOS 15.0, *) {
                webView.underPageBackgroundColor = bg
            }
            webView.navigationDelegate = self
            reload(webView)
            return webView
        }

        func reload(_ webView: WKWebView) {
            // Prefer file:// first — this rendered correctly on working Simulators.
            if let index = Bundle.main.url(forResource: "index", withExtension: "html", subdirectory: "Twin") {
                webView.loadFileURL(index, allowingReadAccessTo: index.deletingLastPathComponent())
                return
            }
            webView.loadHTMLString(Self.errorHTML("Twin folder missing — Clean Build, then ▶ Run."), baseURL: nil)
        }

        func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
            guard let body = message.body as? [String: Any],
                  let level = body["level"] as? String,
                  let text = body["message"] as? String
            else { return }
            print("[Twin \(level)] \(text)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("Twin provisional fail: \(error.localizedDescription)")
            let url = URL(string: "\(TwinSchemeHandler.scheme)://twin/index.html")!
            webView.load(URLRequest(url: url))
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("Twin nav fail: \(error.localizedDescription)")
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
            </body></html>
            """
        }
    }
}
