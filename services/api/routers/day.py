"""Day planner: chain trips between events."""
from datetime import datetime
from typing import Optional

from fastapi import APIRouter
from pydantic import AliasChoices, BaseModel, Field

from contracts import PlaceRef, PlanConstraints
from planner.engine import plan, resolve_place

router = APIRouter(prefix="/day", tags=["day"])


class DayEvent(BaseModel):
    title: str
    place: str = Field(validation_alias=AliasChoices("place", "location"))
    start: datetime
    end: Optional[datetime] = None


class DayRequest(BaseModel):
    events: list[DayEvent]
    start_place: Optional[str] = None


def _ref(p):
    return PlaceRef(lat=p["lat"], lon=p["lon"], place_id=p["place_id"])


@router.post("/plan")
def day_plan(body: DayRequest) -> dict:
    prev = resolve_place(body.start_place) if body.start_place else None
    entries = []
    for ev in body.events:
        dest = resolve_place(ev.place)
        e = {"event": ev.model_dump(mode="json"), "trace": None, "needs_place": dest is None,
             "recommendation": None, "leave_by": None}
        if dest is not None and prev is not None:
            tr = plan(PlanConstraints(origin=_ref(prev), destination=_ref(dest), arrive_by=ev.start))
            e["trace"] = tr.model_dump(mode="json")
            e["recommendation"] = "walk" if tr.plan.mode == "walk_only" else "bus"
            e["leave_by"] = tr.plan.leave_at.isoformat()
        if dest is not None:
            prev = dest
        entries.append(e)
    return {"entries": entries}
