import Foundation

enum BuzzAPIError: LocalizedError {
    case badURL
    case http(Int, String)
    case decoding(Error)
    case unreachable(Error)

    var errorDescription: String? {
        switch self {
        case .badURL:
            return "Invalid API base URL."
        case .http(let code, let body):
            return "API error \(code): \(body.prefix(160))"
        case .decoding(let error):
            return "Could not decode API response: \(error.localizedDescription)"
        case .unreachable(let error):
            return "API unreachable at \(APIConfig.baseURL.absoluteString) — \(error.localizedDescription)"
        }
    }
}

actor BuzzAPIClient {
    static let shared = BuzzAPIClient()

    private let session: URLSession
    private let decoder: JSONDecoder
    private let encoder: JSONEncoder

    init(session: URLSession = .shared) {
        self.session = session
        decoder = JSONDecoder()
        encoder = JSONEncoder()
    }

    func health() async throws -> APIHealthResponse {
        try await get("/health")
    }

    func planTrip(_ constraints: APIPlanConstraints) async throws -> APITripTrace {
        let body = APIPlanRequest(constraints: constraints)
        let response: APIPlanResponse = try await post("/trips/plan", body: body)
        return response.trace
    }

    func grokChat(
        conversationID: String,
        message: String,
        origin: APIChatOrigin? = nil,
        now: String? = nil
    ) async throws -> APIChatResponse {
        let body = APIChatRequest(
            conversation_id: conversationID,
            message: message,
            now: now,
            origin: origin
        )
        return try await post("/grok/chat", body: body)
    }

    func calendarNext() async throws -> APICalendarNextResponse {
        try await get("/calendar/next")
    }

    // MARK: - HTTP

    private func get<T: Decodable>(_ path: String) async throws -> T {
        var request = try makeRequest(path: path)
        request.httpMethod = "GET"
        return try await send(request)
    }

    private func post<Body: Encodable, T: Decodable>(_ path: String, body: Body) async throws -> T {
        var request = try makeRequest(path: path)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try encoder.encode(body)
        return try await send(request)
    }

    private func makeRequest(path: String) throws -> URLRequest {
        guard let url = URL(string: path, relativeTo: APIConfig.baseURL) else {
            throw BuzzAPIError.badURL
        }
        var request = URLRequest(url: url)
        request.timeoutInterval = 12
        return request
    }

    private func send<T: Decodable>(_ request: URLRequest) async throws -> T {
        let data: Data
        let response: URLResponse
        do {
            (data, response) = try await session.data(for: request)
        } catch {
            throw BuzzAPIError.unreachable(error)
        }

        guard let http = response as? HTTPURLResponse else {
            throw BuzzAPIError.http(-1, "Non-HTTP response")
        }
        guard (200..<300).contains(http.statusCode) else {
            let body = String(data: data, encoding: .utf8) ?? ""
            throw BuzzAPIError.http(http.statusCode, body)
        }

        do {
            return try decoder.decode(T.self, from: data)
        } catch {
            throw BuzzAPIError.decoding(error)
        }
    }
}
