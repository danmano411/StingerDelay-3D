import CoreLocation
import Foundation
import MapKit
import SwiftUI

@MainActor
final class NavigationViewModel: ObservableObject {
    @Published var origin: CampusPlace
    @Published var destination: CampusPlace?
    @Published var trip: TripTrace?
    @Published var verificationOK: Bool = false
    @Published var buses: [LiveBus] = []
    @Published var cameraPosition: MapCameraPosition
    @Published var replayMode: Bool = true
    @Published var isPlanning: Bool = false
    @Published var errorMessage: String?
    @Published var nextEvent: CalendarEvent
    @Published var showDestinationPicker: Bool = false
    @Published var showGrokBot: Bool = false
    @Published var showTwin3D: Bool = true
    @Published var twinReloadToken: Int = 0
    @Published var stingerRoutes: [StingerRouteGeo] = CampusCatalog.routes
    @Published var apiReachable: Bool?
    @Published var usingServerPlan: Bool = false

    private var engine = RoutingEngine()
    private let calendar = CalendarStub()
    private var busTask: Task<Void, Never>?
    private var planTask: Task<Void, Never>?
    private var replaySeconds: Double = {
        let cal = Calendar.current
        let comps = cal.dateComponents([.hour, .minute, .second], from: Date())
        return Double((comps.hour ?? 12) * 3600 + (comps.minute ?? 0) * 60 + (comps.second ?? 0))
    }()

    init() {
        let defaultOrigin = NormalizedCatalog.place(id: "student-center")
            ?? MockCampusData.place(id: "student-center")
            ?? MockCampusData.place(id: "culc")
            ?? MockCampusData.destinations.first
            ?? CampusPlace(
                id: "fallback",
                name: "Campus Center",
                shortName: "Campus",
                kind: .landmark,
                latitude: CampusCatalog.campusCenter.latitude,
                longitude: CampusCatalog.campusCenter.longitude,
                stingerRoutes: ["Red"]
            )
        origin = defaultOrigin
        nextEvent = calendar.nextEvent()
        cameraPosition = .region(
            MKCoordinateRegion(
                center: CampusCatalog.campusCenter,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        )
        refreshBuses()
        startBusReplay()
        Task { await probeAPI() }
    }

    func stop() {
        busTask?.cancel()
        busTask = nil
        planTask?.cancel()
        planTask = nil
    }

    var destinations: [CampusPlace] {
        let normalized = NormalizedCatalog.destinations
        return normalized.isEmpty ? MockCampusData.destinations : normalized
    }

    var placesForMap: [CampusPlace] {
        let base = destinations + MockCampusData.places.filter { $0.kind == .busStop }
        return base.filter { place in
            place.kind == .busStop
                || place.id == origin.id
                || place.id == destination?.id
                || place.id == nextEvent.destinationID
        }
    }

    func selectDestination(_ place: CampusPlace) {
        destination = place
        showDestinationPicker = false
        plan()
        focusRoute()
    }

    func planForNextCalendarEvent() {
        let place = NormalizedCatalog.place(id: nextEvent.destinationID)
            ?? MockCampusData.place(id: nextEvent.destinationID)
        guard let place else { return }
        destination = place
        plan(targetArrival: nextEvent.start)
        focusRoute()
        showGrokBot = true
    }

    func plan(targetArrival: Date? = nil) {
        guard let destination else {
            errorMessage = "Pick a destination first."
            return
        }
        isPlanning = true
        errorMessage = nil
        engine.replayMode = replayMode
        planTask?.cancel()

        let originSnapshot = origin
        let destSnapshot = destination
        let replay = replayMode
        let target = targetArrival ?? (destination.id == nextEvent.destinationID ? nextEvent.start : nil)

        planTask = Task {
            defer { isPlanning = false }

            if let serverTrace = await planViaAPI(
                origin: originSnapshot,
                destination: destSnapshot,
                targetArrival: target,
                replay: replay
            ) {
                apply(trace: serverTrace, fromServer: true)
                focusRoute()
                return
            }

            // Offline / API-down fallback — local RoutingEngine (numbers still verified).
            let local = engine.plan(
                from: originSnapshot,
                to: destSnapshot,
                departAt: .now,
                targetArrival: target
            )
            apply(trace: local, fromServer: false)
            focusRoute()
        }
    }

    func clearTrip() {
        trip = nil
        destination = nil
        verificationOK = false
        usingServerPlan = false
    }

    func focusCampus() {
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: CampusCatalog.campusCenter,
                    span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
                )
            )
        }
    }

    private func apply(trace: TripTrace, fromServer: Bool) {
        do {
            try TripVerification.verify(trace)
            trip = trace
            verificationOK = true
            usingServerPlan = fromServer
            if let api = trace.apiTrace {
                let label = "\(trace.origin.shortName) → \(trace.destination.shortName)"
                Task {
                    _ = try? await LocalPlanStore.shared.saveTrace(api, label: label)
                }
            }
        } catch {
            trip = nil
            verificationOK = false
            usingServerPlan = false
            errorMessage = error.localizedDescription
        }
    }

    private func planViaAPI(
        origin: CampusPlace,
        destination: CampusPlace,
        targetArrival: Date?,
        replay: Bool
    ) async -> TripTrace? {
        let iso = ISO8601DateFormatter()
        iso.formatOptions = [.withInternetDateTime]
        let constraints = APIPlanConstraints(
            origin: APIPlaceRef(lat: origin.latitude, lon: origin.longitude, place_id: origin.id),
            destination: APIPlaceRef(lat: destination.latitude, lon: destination.longitude, place_id: destination.id),
            arrive_by: targetArrival.map { iso.string(from: $0) },
            depart_at: nil,
            prefs: APIPlanPrefs(avoid_stairs: false, walk_speed_mps: 1.4)
        )

        do {
            let apiTrace = try await BuzzAPIClient.shared.planTrip(constraints)
            apiReachable = true
            return TripTraceMapper.toUI(
                apiTrace,
                origin: origin,
                destination: destination,
                replayMode: replay
            )
        } catch {
            apiReachable = false
            errorMessage = "Server planner offline — using local TripTrace. (\(error.localizedDescription))"
            return nil
        }
    }

    private func probeAPI() async {
        do {
            _ = try await BuzzAPIClient.shared.health()
            apiReachable = true
        } catch {
            apiReachable = false
        }
    }

    private func focusRoute() {
        guard let trip else {
            focusCampus()
            return
        }
        let coords = trip.polylineCoordinates
        guard let first = coords.first else { return }
        var minLat = first.latitude
        var maxLat = first.latitude
        var minLon = first.longitude
        var maxLon = first.longitude
        for c in coords {
            minLat = min(minLat, c.latitude)
            maxLat = max(maxLat, c.latitude)
            minLon = min(minLon, c.longitude)
            maxLon = max(maxLon, c.longitude)
        }
        let center = CLLocationCoordinate2D(
            latitude: (minLat + maxLat) / 2,
            longitude: (minLon + maxLon) / 2
        )
        withAnimation(.easeInOut(duration: 0.4)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: center,
                    span: MKCoordinateSpan(
                        latitudeDelta: max(0.01, (maxLat - minLat) * 1.8),
                        longitudeDelta: max(0.01, (maxLon - minLon) * 1.8)
                    )
                )
            )
        }
    }

    private func startBusReplay() {
        busTask?.cancel()
        busTask = Task { [weak self] in
            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: 2_500_000_000)
                await MainActor.run {
                    guard let self else { return }
                    if self.replayMode {
                        self.replaySeconds = (self.replaySeconds + 150).truncatingRemainder(dividingBy: 86_400)
                    }
                    self.refreshBuses()
                }
            }
        }
    }

    private func refreshBuses() {
        if !CampusCatalog.routes.isEmpty {
            buses = CampusCatalog.buses(atSecondsOfDay: replaySeconds)
        } else {
            buses = MockCampusData.replayBuses()
        }
    }
}
