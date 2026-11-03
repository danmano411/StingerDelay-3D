"""Core TripTrace contract models (v0).

Frozen field names for web + iOS consumers. All numeric planner outputs
live in TripTrace; Grok may only speak numbers from allowed_numbers.
"""

from __future__ import annotations

from datetime import datetime
from enum import Enum
from typing import Annotated, Optional, Union

from pydantic import BaseModel, ConfigDict, Field, field_validator


class LegKind(str, Enum):
    walk = "walk"
    wait = "wait"
    ride = "ride"
    transfer_walk = "transfer_walk"


class Quantiles(BaseModel):
    """Duration / ETA quantiles in seconds."""

    model_config = ConfigDict(extra="forbid")

    p10: float = Field(..., description="10th percentile duration in seconds")
    p50: float = Field(..., description="Median duration in seconds")
    p90: float = Field(..., description="90th percentile duration in seconds")

    @field_validator("p10", "p50", "p90")
    @classmethod
    def _non_negative(cls, v: float) -> float:
        if v < 0:
            raise ValueError("quantile seconds must be >= 0")
        return v


class PlaceRef(BaseModel):
    """Origin or destination coordinate, optionally tied to a known place."""

    model_config = ConfigDict(extra="forbid")

    lat: float = Field(..., ge=-90, le=90)
    lon: float = Field(..., ge=-180, le=180)
    place_id: Optional[str] = None


class PlanPrefs(BaseModel):
    """Traveler preferences applied by the deterministic planner."""

    model_config = ConfigDict(extra="forbid")

    avoid_stairs: bool = False
    walk_speed_mps: float = Field(1.4, gt=0, description="Walking speed in m/s")


class PlanConstraints(BaseModel):
    """Request constraints for POST /trips/plan."""

    model_config = ConfigDict(extra="forbid")

    origin: PlaceRef
    destination: PlaceRef
    arrive_by: Optional[datetime] = Field(
        None, description="ISO-8601 arrive-by deadline"
    )
    depart_at: Optional[datetime] = Field(
        None, description="ISO-8601 depart-at time; omit for leave-now"
    )
    prefs: PlanPrefs = Field(default_factory=PlanPrefs)


class Leg(BaseModel):
    """One PRT segment: walk → wait → ride → (transfer) → walk."""

    model_config = ConfigDict(extra="forbid")

    kind: LegKind
    duration_s_p50: float = Field(..., ge=0, description="Median leg duration (s)")
    label: str
    route_id: Optional[str] = None
    from_stop_id: Optional[str] = None
    to_stop_id: Optional[str] = None
    geometry_ref: Optional[str] = Field(
        None, description="Id of polyline/geometry asset; not inline OSM"
    )


class TripPlan(BaseModel):
    """A single planned itinerary with confidence quantiles."""

    model_config = ConfigDict(extra="forbid")

    legs: list[Leg] = Field(..., min_length=1)
    total_s: Quantiles
    leave_at: datetime = Field(..., description="ISO-8601 leave time")
    arrive_at: datetime = Field(..., description="ISO-8601 arrive time")
    p_on_time: float = Field(..., ge=0.0, le=1.0)
    p_catch: Optional[float] = Field(
        None, ge=0.0, le=1.0, description="Probability of catching the bus"
    )
    explanation_facts: list[str] = Field(default_factory=list)


class SocialFactor(BaseModel):
    """Secondary X/social uncertainty; must be badged when applied."""

    model_config = ConfigDict(extra="forbid")

    source: str
    badge_required: bool = True
    spread_multiplier: float = Field(..., gt=0)
    label: str


AllowedNumber = Union[float, int]


class TripTrace(BaseModel):
    """Canonical planner output. Verification checks spoken/displayed numbers
    against allowed_numbers only.
    """

    model_config = ConfigDict(extra="forbid")

    plan: TripPlan
    alternatives: list[TripPlan] = Field(default_factory=list)
    allowed_numbers: list[AllowedNumber] = Field(default_factory=list)
    model_id: str
    confidence_horizon_s: float = Field(..., ge=0)
    social_factor: Optional[SocialFactor] = None
    verification_version: str = "v0"


# Convenience aliases for OpenAPI / export clarity
ContractVersion = Annotated[str, Field(description="Contract version; currently v0")]
