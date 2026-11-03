import Foundation

struct CalendarEvent: Identifiable, Hashable {
    let id: UUID
    let title: String
    let locationName: String
    let destinationID: String
    let start: Date
}

/// Google Calendar integration is limited to "next event" for now.
/// This stub stands in until the shared backend connector is wired.
struct CalendarStub {
    func nextEvent(now: Date = .now) -> CalendarEvent {
        let cal = Calendar.current
        let start = cal.date(byAdding: .minute, value: 75, to: now) ?? now.addingTimeInterval(75 * 60)
        return CalendarEvent(
            id: UUID(),
            title: "CS 2110 Recitation",
            locationName: "Klaus Advanced Computing Building",
            destinationID: "klaus",
            start: start
        )
    }
}
