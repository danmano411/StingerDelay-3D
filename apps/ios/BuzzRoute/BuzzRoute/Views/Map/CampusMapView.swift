import MapKit
import SwiftUI

struct CampusMapView: View {
    @ObservedObject var model: NavigationViewModel

    var body: some View {
        Map(position: $model.cameraPosition) {
            ForEach(model.stingerRoutes) { route in
                let coords = route.coordinates
                if coords.count >= 2 {
                    MapPolyline(coordinates: coords)
                        .stroke(
                            Color(hex: route.color.replacingOccurrences(of: "#", with: "")),
                            lineWidth: route.isSynthetic ? 3 : 4
                        )
                }
            }

            ForEach(model.placesForMap) { place in
                Marker(
                    place.shortName,
                    systemImage: icon(for: place),
                    coordinate: place.coordinate
                )
                .tint(tint(for: place))
            }

            ForEach(model.buses) { bus in
                Marker(
                    bus.line.rawValue,
                    systemImage: "bus.fill",
                    coordinate: bus.coordinate
                )
                .tint(Color(hex: bus.line.tintHex))
            }

            if let trip = model.trip {
                let coords = trip.polylineCoordinates
                if coords.count >= 2 {
                    MapPolyline(coordinates: coords)
                        .stroke(GTTheme.gold, lineWidth: 5)
                }
            }
        }
        .mapStyle(.standard)
        .mapControls {
            MapCompass()
        }
    }

    private func icon(for place: CampusPlace) -> String {
        switch place.kind {
        case .busStop: return "bus.fill"
        case .building: return "building.2.fill"
        case .landmark: return "mappin.and.ellipse"
        }
    }

    private func tint(for place: CampusPlace) -> Color {
        if place.id == model.origin.id { return GTTheme.good }
        if place.id == model.destination?.id { return GTTheme.gold }
        return place.kind == .busStop ? GTTheme.navy : GTTheme.techGold
    }
}

extension Color {
    init(hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r, g, b: UInt64
        switch cleaned.count {
        case 6:
            (r, g, b) = ((int >> 16) & 0xFF, (int >> 8) & 0xFF, int & 0xFF)
        default:
            (r, g, b) = (234, 170, 0)
        }
        self.init(
            red: Double(r) / 255,
            green: Double(g) / 255,
            blue: Double(b) / 255
        )
    }
}
