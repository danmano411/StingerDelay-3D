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

    private var engine = RoutingEngine()
    private let calendar = CalendarStub()
    private var busTask: Task<Void, Never>?

    init() {
        let defaultOrigin = MockCampusData.place(id: "culc")
            ?? MockCampusData.destinations.first
            ?? CampusPlace(
                id: "fallback",
                name: "Campus Center",
                shortName: "Campus",
                kind: .landmark,
                latitude: MockCampusData.campusCenter.latitude,
                longitude: MockCampusData.campusCenter.longitude,
                stingerRoutes: ["Red"]
            )
        origin = defaultOrigin
        nextEvent = calendar.nextEvent()
        cameraPosition = .region(
            MKCoordinateRegion(
                center: MockCampusData.campusCenter,
                span: MKCoordinateSpan(latitudeDelta: 0.02, longitudeDelta: 0.02)
            )
        )
        refreshBuses()
        startBusReplay()
    }

    func stop() {
        busTask?.cancel()
        busTask = nil
    }

    var destinations: [CampusPlace] { MockCampusData.destinations }

    var placesForMap: [CampusPlace] {
        MockCampusData.places.filter { place in
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
        guard let place = MockCampusData.place(id: nextEvent.destinationID) else { return }
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

        let trace = engine.plan(
            from: origin,
            to: destination,
            departAt: .now,
            targetArrival: targetArrival ?? (destination.id == nextEvent.destinationID ? nextEvent.start : nil)
        )

        do {
            try TripVerification.verify(trace)
            trip = trace
            verificationOK = true
        } catch {
            trip = nil
            verificationOK = false
            errorMessage = error.localizedDescription
        }
        isPlanning = false
    }

    func clearTrip() {
        trip = nil
        destination = nil
        verificationOK = false
    }

    func focusCampus() {
        withAnimation(.easeInOut(duration: 0.35)) {
            cameraPosition = .region(
                MKCoordinateRegion(
                    center: MockCampusData.campusCenter,
                    span: MKCoordinateSpan(latitudeDelta: 0.018, longitudeDelta: 0.018)
                )
            )
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
                try? await Task.sleep(nanoseconds: 3_000_000_000)
                await MainActor.run {
                    self?.refreshBuses()
                }
            }
        }
    }

    private func refreshBuses() {
        buses = MockCampusData.replayBuses()
    }
}
