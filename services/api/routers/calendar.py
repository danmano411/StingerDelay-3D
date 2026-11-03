"""Calendar next-event (mock until Wave C1 OAuth)."""

from datetime import datetime, timezone

from fastapi import APIRouter

try:
    from contracts import CalendarNextResponse  # type: ignore
except ImportError:
    CalendarNextResponse = None  # type: ignore


router = APIRouter(prefix="/calendar", tags=["calendar"])


@router.get("/next")
def calendar_next() -> dict:
    """Mock next class/event for offline E2E demos."""
    payload = {
        "source": "mock",
        "synthetic": True,
        "event": {
            "id": "mock-class-cs2110",
            "title": "CS 2110 Lecture",
            "location": "Klaus Advanced Computing Building",
            "place_id": "klaus",
            "start": "2026-11-03T08:30:00-05:00",
            "end": "2026-11-03T09:20:00-05:00",
        },
        "as_of": datetime.now(timezone.utc).isoformat(),
    }
    if CalendarNextResponse is not None:
        return CalendarNextResponse.model_validate(payload).model_dump()
    return payload
