import Foundation

/// Codable models matching `services/api/openapi/openapi.yaml` (contract v0).
/// Quantile fields are **seconds** on the wire.

struct APIPlaceRef: Codable, Hashable {
    var lat: Double
    var lon: Double
    var place_id: String?
}

struct APIPlanPrefs: Codable, Hashable {
    var avoid_stairs: Bool = false
    var walk_speed_mps: Double = 1.4
}

struct APIPlanConstraints: Codable, Hashable {
    var origin: APIPlaceRef
    var destination: APIPlaceRef
    var arrive_by: String?
    var depart_at: String?
    var prefs: APIPlanPrefs = APIPlanPrefs()
}

struct APIPlanRequest: Codable {
    var constraints: APIPlanConstraints
}

struct APIQuantiles: Codable, Hashable {
    var p10: Double
    var p50: Double
    var p90: Double
}

struct APISocialFactor: Codable, Hashable {
    var source: String
    var badge_required: Bool?
    var spread_multiplier: Double
    var label: String
}

struct APILeg: Codable, Hashable {
    var kind: String
    var duration_s_p50: Double
    var label: String
    var route_id: String?
    var from_stop_id: String?
    var to_stop_id: String?
    var geometry_ref: String?
    var path: [[Double]]?
    var distance_m: Double?
    var estimate: Bool?
    var synthetic: Bool?
}

struct APITripPlan: Codable, Hashable {
    var legs: [APILeg]
    var total_s: APIQuantiles
    var leave_at: String
    var arrive_at: String
    var p_on_time: Double
    var p_catch: Double?
    var explanation_facts: [String]?
    var mode: String?
}

struct APITripTrace: Codable, Hashable {
    var plan: APITripPlan
    var alternatives: [APITripPlan]?
    var allowed_numbers: [Double]?
    var model_id: String
    var confidence_horizon_s: Double
    var social_factor: APISocialFactor?
    var verification_version: String?
    var status: String?
    var origin_name: String?
    var destination_name: String?
}

struct APIPlanResponse: Codable {
    var trace: APITripTrace
    var contract_version: String?
}

struct APIHealthResponse: Codable {
    var status: String
    var service: String?
    var contract_version: String?
}

struct APIChatOrigin: Codable {
    var lat: Double
    var lon: Double
}

struct APIChatRequest: Codable {
    var conversation_id: String
    var message: String
    var now: String?
    var origin: APIChatOrigin?
}

struct APIChatClarification: Codable, Hashable {
    var question: String
    var options: [String]
}

struct APIChatResponse: Codable {
    var conversation_id: String
    var reply: String
    var source: String
    var verified: Bool
    var action: String?
    var trace: APITripTrace?
    var clarification: APIChatClarification?
}

struct APICalendarEventDTO: Codable {
    var id: String?
    var title: String?
    var start: String?
    var end: String?
    var place_id: String?
    var lat: Double?
    var lon: Double?
    var source: String?
}

struct APICalendarNextResponse: Codable {
    var event: APICalendarEventDTO?
    var contract_version: String?
}

/// Offline save shape (`docs/contracts/local_plan_v0.json`).
struct LocalSavedPlan: Codable, Identifiable, Hashable {
    var id: String
    var day: String
    var label: String
    var tripTrace: APITripTrace
    var createdAt: String
}
