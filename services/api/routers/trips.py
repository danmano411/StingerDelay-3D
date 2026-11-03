"""Trip planning (stub until Wave B2)."""

from typing import Any

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

try:
    from contracts import PlanRequest  # type: ignore
except ImportError:
    PlanRequest = None  # type: ignore


router = APIRouter(prefix="/trips", tags=["trips"])


class StubPlanRequest(BaseModel):
    """Minimal plan body when contracts package is not present."""

    origin: dict[str, Any] = Field(..., description="Origin place or lat/lon")
    destination: dict[str, Any] = Field(..., description="Destination place or lat/lon")
    depart_at: str | None = None
    arrive_by: str | None = None
    constraints: dict[str, Any] | None = None


_RequestModel = PlanRequest if PlanRequest is not None else StubPlanRequest


@router.post("/plan", status_code=501)
def plan_trip(body: _RequestModel) -> dict:  # type: ignore[valid-type]
    """Planner stub — returns 501 until deterministic TripTrace lands (B2)."""
    raise HTTPException(
        status_code=501,
        detail={
            "message": "planner not implemented",
            "wave": "B2",
            "received_keys": list(body.model_dump(exclude_none=True).keys()),
        },
    )
