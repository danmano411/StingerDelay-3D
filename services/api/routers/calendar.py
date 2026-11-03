"""Calendar endpoints: sample schedule, .ics import, Google not configured."""
from datetime import datetime, timezone

import requests
from fastapi import APIRouter, Body, HTTPException

from tools import calendar as cal

router = APIRouter(prefix="/calendar", tags=["calendar"])


@router.get("/status")
def status() -> dict:
    return {"source": "ics" if cal.IMPORTED else "sample", "google": cal.GOOGLE, "imported": len(cal.IMPORTED)}


@router.post("/import")
def import_ics(body: str | dict = Body(...)) -> dict:
    text = body
    if isinstance(body, dict):
        try:
            text = requests.get(body["url"], timeout=10).text if "url" in body else body.get("text", "")
        except Exception as e:
            raise HTTPException(502, f"fetch failed: {type(e).__name__}")
    evs = cal.parse_ics(text)
    if not evs:
        raise HTTPException(400, "no VEVENT found")
    cal.IMPORTED[:] = evs
    return {"source": "ics", "imported": len(evs)}


@router.get("/next")
def calendar_next() -> dict:
    now = datetime.now(cal.TZ)
    e = cal.next_event(now)
    return {"source": e["source"] if e else "none", "synthetic": not cal.IMPORTED, "event": e,
            "as_of": now.astimezone(timezone.utc).isoformat()}


@router.get("/day")
def calendar_day() -> dict:
    return {"source": "ics" if cal.IMPORTED else "sample", "events": cal.events(datetime.now(cal.TZ))}
