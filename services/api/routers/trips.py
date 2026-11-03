"""Trip planning + places."""
from fastapi import APIRouter

from contracts import PlanRequest, PlanResponse
from planner.engine import list_places, plan

router = APIRouter(tags=["trips"])


@router.post("/trips/plan", response_model=PlanResponse)
def plan_trip(body: PlanRequest) -> PlanResponse:
    return PlanResponse(trace=plan(body.constraints))


@router.get("/places")
def places() -> list[dict]:
    return list_places()
