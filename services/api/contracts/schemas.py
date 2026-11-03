"""API request/response schemas wrapping the TripTrace contracts (v0)."""

from __future__ import annotations

from datetime import datetime
from typing import Optional

from pydantic import BaseModel, ConfigDict, Field

from .trip_trace import PlanConstraints, SocialFactor, TripTrace


class PlanRequest(BaseModel):
    """Body for POST /trips/plan."""

    model_config = ConfigDict(extra="forbid")

    constraints: PlanConstraints


class PlanResponse(BaseModel):
    """Successful plan response — a TripTrace."""

    model_config = ConfigDict(extra="forbid")

    trace: TripTrace
    contract_version: str = "v0"


class HealthResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    status: str = "ok"
    service: str = "stingerdelay-3d-api"
    contract_version: str = "v0"


class CalendarEvent(BaseModel):
    """Next calendar / class event (mock or Google)."""

    model_config = ConfigDict(extra="forbid")

    id: str
    title: str
    start: datetime
    end: datetime
    place_id: Optional[str] = None
    lat: Optional[float] = None
    lon: Optional[float] = None
    source: str = Field("mock", description="mock | google")


class CalendarNextResponse(BaseModel):
    model_config = ConfigDict(extra="forbid")

    event: Optional[CalendarEvent] = None
    contract_version: str = "v0"


class SignalsXResponse(BaseModel):
    """Secondary social/X uncertainty factor (optional)."""

    model_config = ConfigDict(extra="forbid")

    factor: Optional[SocialFactor] = None
    contract_version: str = "v0"
