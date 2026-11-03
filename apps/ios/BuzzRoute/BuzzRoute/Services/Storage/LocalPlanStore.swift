import Foundation

/// Persists plans matching `docs/contracts/local_plan_v0.json`.
actor LocalPlanStore {
    static let shared = LocalPlanStore()

    private let fileURL: URL
    private let encoder: JSONEncoder
    private let decoder: JSONDecoder

    init() {
        let dir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        fileURL = dir.appendingPathComponent("local_plans_v0.json")
        encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        decoder = JSONDecoder()
    }

    func loadAll() throws -> [LocalSavedPlan] {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return [] }
        let data = try Data(contentsOf: fileURL)
        return try decoder.decode([LocalSavedPlan].self, from: data)
    }

    func plans(forDay day: String) throws -> [LocalSavedPlan] {
        try loadAll().filter { $0.day == day }
    }

    func save(_ plan: LocalSavedPlan) throws {
        var all = try loadAll()
        if let idx = all.firstIndex(where: { $0.id == plan.id }) {
            all[idx] = plan
        } else {
            all.append(plan)
        }
        try encoder.encode(all).write(to: fileURL, options: .atomic)
    }

    func saveTrace(
        _ trace: APITripTrace,
        label: String,
        day: Date = .now
    ) throws -> LocalSavedPlan {
        let dayKey = Self.dayKey(day)
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let saved = LocalSavedPlan(
            id: UUID().uuidString,
            day: dayKey,
            label: label,
            tripTrace: trace,
            createdAt: iso.string(from: .now)
        )
        try save(saved)
        return saved
    }

    static func dayKey(_ date: Date) -> String {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.timeZone = TimeZone(identifier: "America/New_York")
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: date)
    }
}
