import CoreLocation
import Foundation

enum MockCampusData {
    static let campusCenter = CLLocationCoordinate2D(latitude: 33.7756, longitude: -84.3963)

    static let places: [CampusPlace] = [
        CampusPlace(
            id: "culc",
            name: "Clough Undergraduate Learning Commons",
            shortName: "CULC",
            kind: .building,
            latitude: 33.7747,
            longitude: -84.3964,
            stingerRoutes: ["Red", "Blue"]
        ),
        CampusPlace(
            id: "student-center",
            name: "Student Center",
            shortName: "Student Center",
            kind: .building,
            latitude: 33.7738,
            longitude: -84.3989,
            stingerRoutes: ["Red", "Green"]
        ),
        CampusPlace(
            id: "klaus",
            name: "Klaus Advanced Computing Building",
            shortName: "Klaus",
            kind: .building,
            latitude: 33.7772,
            longitude: -84.3963,
            stingerRoutes: ["Blue"]
        ),
        CampusPlace(
            id: "crc",
            name: "Campus Recreation Center",
            shortName: "CRC",
            kind: .building,
            latitude: 33.7755,
            longitude: -84.4030,
            stingerRoutes: ["Green"]
        ),
        CampusPlace(
            id: "tech-square",
            name: "Tech Square / CODA",
            shortName: "Tech Square",
            kind: .landmark,
            latitude: 33.7759,
            longitude: -84.3889,
            stingerRoutes: ["Trolley", "Red"]
        ),
        CampusPlace(
            id: "west-village",
            name: "West Village",
            shortName: "West Village",
            kind: .building,
            latitude: 33.7790,
            longitude: -84.4045,
            stingerRoutes: ["Green"]
        ),
        CampusPlace(
            id: "north-ave",
            name: "North Avenue Apartments",
            shortName: "North Ave",
            kind: .building,
            latitude: 33.7710,
            longitude: -84.3915,
            stingerRoutes: ["Red", "Trolley"]
        ),
        CampusPlace(
            id: "howey",
            name: "Howey Physics Building",
            shortName: "Howey",
            kind: .building,
            latitude: 33.7774,
            longitude: -84.3986,
            stingerRoutes: ["Blue", "Green"]
        ),
        CampusPlace(
            id: "stop-tech-green",
            name: "Tech Green Stinger Stop",
            shortName: "Tech Green",
            kind: .busStop,
            latitude: 33.7749,
            longitude: -84.3975,
            stingerRoutes: ["Red", "Blue", "Green"]
        ),
        CampusPlace(
            id: "stop-ferst",
            name: "Ferst Drive Stinger Stop",
            shortName: "Ferst Dr",
            kind: .busStop,
            latitude: 33.7764,
            longitude: -84.3928,
            stingerRoutes: ["Red", "Trolley"]
        ),
        CampusPlace(
            id: "stop-marta",
            name: "Midtown MARTA / Tech Square Stop",
            shortName: "MARTA",
            kind: .busStop,
            latitude: 33.7764,
            longitude: -84.3896,
            stingerRoutes: ["Trolley"]
        )
    ]

    static var destinations: [CampusPlace] {
        places.filter { $0.kind != .busStop }
    }

    static func place(id: String) -> CampusPlace? {
        places.first { $0.id == id }
    }

    static func nearestStop(to place: CampusPlace) -> CampusPlace {
        let stops = places.filter { $0.kind == .busStop }
        return stops.min { a, b in
            distance(place.coordinate, a.coordinate) < distance(place.coordinate, b.coordinate)
        } ?? places[8]
    }

    static func distance(_ a: CLLocationCoordinate2D, _ b: CLLocationCoordinate2D) -> CLLocationDistance {
        CLLocation(latitude: a.latitude, longitude: a.longitude)
            .distance(from: CLLocation(latitude: b.latitude, longitude: b.longitude))
    }

    /// Simulated live buses for the map overlay (replay demo).
    static func replayBuses(at date: Date = .now) -> [LiveBus] {
        let t = date.timeIntervalSinceReferenceDate
        return [
            LiveBus(
                id: "bus-red-12",
                line: .red,
                coordinate: CLLocationCoordinate2D(
                    latitude: 33.7747 + 0.0012 * sin(t / 40),
                    longitude: -84.3960 + 0.0020 * cos(t / 55)
                ),
                heading: 90,
                delayMinutes: 1.5
            ),
            LiveBus(
                id: "bus-blue-4",
                line: .blue,
                coordinate: CLLocationCoordinate2D(
                    latitude: 33.7768 + 0.0008 * cos(t / 35),
                    longitude: -84.3990 + 0.0015 * sin(t / 48)
                ),
                heading: 210,
                delayMinutes: 0.2
            ),
            LiveBus(
                id: "bus-green-7",
                line: .green,
                coordinate: CLLocationCoordinate2D(
                    latitude: 33.7752 + 0.0010 * sin(t / 50),
                    longitude: -84.4015 + 0.0012 * cos(t / 42)
                ),
                heading: 320,
                delayMinutes: 3.8
            )
        ]
    }
}

struct LiveBus: Identifiable, Hashable {
    let id: String
    let line: StingerLine
    let coordinate: CLLocationCoordinate2D
    let heading: Double
    let delayMinutes: Double

    static func == (lhs: LiveBus, rhs: LiveBus) -> Bool { lhs.id == rhs.id }
    func hash(into hasher: inout Hasher) { hasher.combine(id) }
}
