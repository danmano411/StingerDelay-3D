import CoreLocation
import Foundation

enum PlaceKind: String, Codable, CaseIterable, Identifiable {
    case building
    case busStop
    case landmark

    var id: String { rawValue }

    var title: String {
        switch self {
        case .building: return "Building"
        case .busStop: return "Stinger stop"
        case .landmark: return "Landmark"
        }
    }
}

struct CampusPlace: Identifiable, Hashable, Codable {
    let id: String
    let name: String
    let shortName: String
    let kind: PlaceKind
    let latitude: Double
    let longitude: Double
    let stingerRoutes: [String]

    var coordinate: CLLocationCoordinate2D {
        CLLocationCoordinate2D(latitude: latitude, longitude: longitude)
    }
}

enum StingerLine: String, CaseIterable, Identifiable, Codable {
    case red = "Red"
    case blue = "Blue"
    case green = "Green"
    case gold = "Gold"
    case clough = "Clough"
    case trolley = "Trolley"

    var id: String { rawValue }

    var tintHex: String {
        switch self {
        case .red: return "E04E39"
        case .blue: return "0000CF"
        case .green: return "4AB335"
        case .gold: return "E0C43A"
        case .clough: return "391B69"
        case .trolley: return "B3A369"
        }
    }
}
