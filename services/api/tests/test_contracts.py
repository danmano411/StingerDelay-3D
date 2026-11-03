"""Round-trip validation for TripTrace contract (v0)."""

from __future__ import annotations

import sys
from pathlib import Path

import pytest

# Allow `from contracts import ...` without installing the package.
_API_ROOT = Path(__file__).resolve().parents[1]
if str(_API_ROOT) not in sys.path:
    sys.path.insert(0, str(_API_ROOT))

from contracts import (  # noqa: E402
    CONTRACT_VERSION,
    Leg,
    LegKind,
    PlaceRef,
    PlanConstraints,
    PlanPrefs,
    Quantiles,
    SocialFactor,
    TripPlan,
    TripTrace,
)


def _fixture_trace() -> dict:
    return {
        "plan": {
            "legs": [
                {
                    "kind": "walk",
                    "duration_s_p50": 180.0,
                    "label": "Walk to Klaus stop",
                    "geometry_ref": "walk:klaus-plaza",
                },
                {
                    "kind": "wait",
                    "duration_s_p50": 240.0,
                    "label": "Wait for Red",
                    "route_id": "red",
                    "from_stop_id": "klaus",
                },
                {
                    "kind": "ride",
                    "duration_s_p50": 420.0,
                    "label": "Ride Red to Kendeda",
                    "route_id": "red",
                    "from_stop_id": "klaus",
                    "to_stop_id": "kendeda",
                    "geometry_ref": "route:red:klaus-kendeda",
                },
                {
                    "kind": "walk",
                    "duration_s_p50": 120.0,
                    "label": "Walk to Kendeda entrance",
                    "geometry_ref": "walk:kendeda-door",
                },
            ],
            "total_s": {"p10": 780.0, "p50": 960.0, "p90": 1260.0},
            "leave_at": "2026-11-03T08:10:00-05:00",
            "arrive_at": "2026-11-03T08:26:00-05:00",
            "p_on_time": 0.82,
            "p_catch": 0.91,
            "explanation_facts": [
                "Median wait at Klaus is 4 min under eta_decile_lookup_v0",
                "Arrive-by 08:30 met with p_on_time=0.82",
            ],
        },
        "alternatives": [],
        "allowed_numbers": [
            180,
            240,
            420,
            120,
            780.0,
            960.0,
            1260.0,
            0.82,
            0.91,
            4,
            8,
            10,
            26,
            30,
        ],
        "model_id": "eta_decile_lookup_v0",
        "confidence_horizon_s": 1200.0,
        "social_factor": {
            "source": "x:mock",
            "badge_required": True,
            "spread_multiplier": 1.15,
            "label": "social signal",
        },
        "verification_version": "v0",
    }


def test_contract_version_is_v0():
    assert CONTRACT_VERSION == "v0"


def test_trip_trace_round_trip():
    raw = _fixture_trace()
    trace = TripTrace.model_validate(raw)
    dumped = trace.model_dump(mode="json")
    again = TripTrace.model_validate(dumped)

    assert again.model_id == "eta_decile_lookup_v0"
    assert again.verification_version == "v0"
    assert again.plan.p_on_time == pytest.approx(0.82)
    assert again.plan.p_catch == pytest.approx(0.91)
    assert len(again.plan.legs) == 4
    assert again.plan.legs[0].kind == LegKind.walk
    assert again.plan.legs[1].kind == LegKind.wait
    assert again.plan.legs[2].kind == LegKind.ride
    assert again.plan.total_s.p50 == 960.0
    assert again.social_factor is not None
    assert again.social_factor.badge_required is True
    assert 0.82 in again.allowed_numbers
    assert again.confidence_horizon_s == 1200.0


def test_plan_constraints_round_trip():
    raw = {
        "origin": {"lat": 33.7771, "lon": -84.3960, "place_id": "klaus"},
        "destination": {"lat": 33.7745, "lon": -84.3987, "place_id": "kendeda"},
        "arrive_by": "2026-11-03T08:30:00-05:00",
        "prefs": {"avoid_stairs": True, "walk_speed_mps": 1.4},
    }
    constraints = PlanConstraints.model_validate(raw)
    again = PlanConstraints.model_validate(constraints.model_dump(mode="json"))
    assert again.origin.place_id == "klaus"
    assert again.prefs.avoid_stairs is True
    assert again.arrive_by is not None


def test_leg_kind_rejects_unknown():
    with pytest.raises(Exception):
        Leg.model_validate(
            {"kind": "fly", "duration_s_p50": 10, "label": "nope"}
        )


def test_p_on_time_bounds():
    plan = {
        "legs": [
            {"kind": "walk", "duration_s_p50": 60, "label": "short"},
        ],
        "total_s": {"p10": 50, "p50": 60, "p90": 90},
        "leave_at": "2026-11-03T08:00:00Z",
        "arrive_at": "2026-11-03T08:01:00Z",
        "p_on_time": 1.5,
        "explanation_facts": [],
    }
    with pytest.raises(Exception):
        TripPlan.model_validate(plan)


def test_build_trace_from_constructors():
    plan = TripPlan(
        legs=[
            Leg(kind=LegKind.walk, duration_s_p50=60, label="Walk"),
            Leg(
                kind=LegKind.wait,
                duration_s_p50=120,
                label="Wait",
                route_id="blue",
                from_stop_id="sc",
            ),
            Leg(
                kind=LegKind.ride,
                duration_s_p50=300,
                label="Ride Blue (SYNTHETIC)",
                route_id="blue",
                from_stop_id="sc",
                to_stop_id="klaus",
                geometry_ref="route:blue:sc-klaus",
            ),
            Leg(kind=LegKind.transfer_walk, duration_s_p50=90, label="Transfer walk"),
        ],
        total_s=Quantiles(p10=500, p50=570, p90=720),
        leave_at="2026-11-03T12:00:00Z",
        arrive_at="2026-11-03T12:09:30Z",
        p_on_time=0.7,
        explanation_facts=["Blue route is synthetic"],
    )
    trace = TripTrace(
        plan=plan,
        alternatives=[],
        allowed_numbers=[60, 120, 300, 90, 500, 570, 720, 0.7],
        model_id="eta_decile_lookup_v0",
        confidence_horizon_s=600,
        social_factor=SocialFactor(
            source="x:none",
            badge_required=True,
            spread_multiplier=1.0,
            label="no social signal",
        ),
        verification_version="v0",
    )
    assert PlaceRef(lat=33.77, lon=-84.39).place_id is None
    assert PlanPrefs().walk_speed_mps == 1.4
    dumped = trace.model_dump_json()
    assert TripTrace.model_validate_json(dumped).plan.legs[2].route_id == "blue"
