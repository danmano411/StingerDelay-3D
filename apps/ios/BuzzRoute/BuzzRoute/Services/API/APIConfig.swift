import Foundation

enum APIConfig {
    /// Base URL for the shared FastAPI process. Never embeds API keys.
    static var baseURL: URL {
        if let env = ProcessInfo.processInfo.environment["API_BASE_URL"],
           let url = URL(string: env), !env.isEmpty {
            return url
        }
        if let raw = Bundle.main.object(forInfoDictionaryKey: "API_BASE_URL") as? String,
           let url = URL(string: raw), !raw.isEmpty {
            return url
        }
        return URL(string: "http://127.0.0.1:8000")!
    }

    static var replayPreferred: Bool {
        let env = ProcessInfo.processInfo.environment["REPLAY_MODE"]?.lowercased()
        if env == "false" || env == "0" { return false }
        return true
    }
}
