"""X / social signals (stub — secondary uncertainty only)."""

from fastapi import APIRouter

try:
    from contracts import SocialFactor  # type: ignore
except ImportError:
    SocialFactor = None  # type: ignore


router = APIRouter(prefix="/signals", tags=["signals"])


@router.get("/x")
def signals_x() -> dict:
    """Stub social factor. Always badged; never overrides TripTrace numbers."""
    payload = {
        "source": "stub",
        "badge": "secondary_social",
        "active": False,
        "multiplier": 1.0,
        "notes": "X signals not wired; returns neutral factor",
        "events": [],
    }
    if SocialFactor is not None:
        return SocialFactor.model_validate(payload).model_dump()
    return payload
