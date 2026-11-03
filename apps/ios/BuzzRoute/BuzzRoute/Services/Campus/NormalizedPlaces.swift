import Foundation

struct NormalizedPlace: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let lat: Double
    let lon: Double
    let stop_id: Int?
    let stop_name: String?

    var asCampusPlace: CampusPlace {
        CampusPlace(
            id: id,
            name: name,
            shortName: name.count <= 22 ? name : String(name.prefix(20)) + "…",
            kind: .building,
            latitude: lat,
            longitude: lon,
            stingerRoutes: []
        )
    }
}

enum NormalizedCatalog {
    static let places: [NormalizedPlace] = {
        let url = Bundle.main.url(forResource: "places", withExtension: "json", subdirectory: "Normalized")
            ?? Bundle.main.url(forResource: "places", withExtension: "json")
        guard let url,
              let data = try? Data(contentsOf: url),
              let decoded = try? JSONDecoder().decode([NormalizedPlace].self, from: data)
        else {
            return []
        }
        return decoded
    }()

    static func place(id: String) -> CampusPlace? {
        places.first(where: { $0.id == id || $0.id.replacingOccurrences(of: "-", with: "_") == id })?
            .asCampusPlace
    }

    /// Destinations preferred by the shared API (Wave A4).
    static var destinations: [CampusPlace] {
        let preferred = places.map(\.asCampusPlace)
        return preferred.isEmpty ? MockCampusData.destinations : preferred
    }
}
