import Foundation
import UniformTypeIdentifiers
import WebKit

/// Serves bundled Twin files over `buzzroute-twin://` so ES modules / import maps
/// work reliably (file:// module loads often fail silently in WKWebView).
final class TwinSchemeHandler: NSObject, WKURLSchemeHandler {
    static let scheme = "buzzroute-twin"

    private let twinRoot: URL

    init(twinRoot: URL) {
        self.twinRoot = twinRoot
    }

    func webView(_ webView: WKWebView, start urlSchemeTask: WKURLSchemeTask) {
        guard let url = urlSchemeTask.request.url else {
            urlSchemeTask.didFailWithError(URLError(.badURL))
            return
        }

        // buzzroute-twin://twin/index.html → path "/index.html"
        // buzzroute-twin://twin/vendor/... → path "/vendor/..."
        var path = url.path
        if path.hasPrefix("/") { path = String(path.dropFirst()) }
        if path.isEmpty { path = "index.html" }

        let fileURL = twinRoot.appendingPathComponent(path)
        guard FileManager.default.fileExists(atPath: fileURL.path),
              let data = try? Data(contentsOf: fileURL)
        else {
            urlSchemeTask.didFailWithError(URLError(.fileDoesNotExist))
            return
        }

        let mime = Self.mimeType(for: fileURL)
        let response = URLResponse(
            url: url,
            mimeType: mime,
            expectedContentLength: data.count,
            textEncodingName: "utf-8"
        )
        urlSchemeTask.didReceive(response)
        urlSchemeTask.didReceive(data)
        urlSchemeTask.didFinish()
    }

    func webView(_ webView: WKWebView, stop urlSchemeTask: WKURLSchemeTask) {}

    private static func mimeType(for url: URL) -> String {
        switch url.pathExtension.lowercased() {
        case "html", "htm": return "text/html"
        case "js", "mjs": return "text/javascript"
        case "css": return "text/css"
        case "json": return "application/json"
        case "png": return "image/png"
        case "jpg", "jpeg": return "image/jpeg"
        case "svg": return "image/svg+xml"
        case "wasm": return "application/wasm"
        default:
            if let type = UTType(filenameExtension: url.pathExtension),
               let mime = type.preferredMIMEType {
                return mime
            }
            return "application/octet-stream"
        }
    }
}
