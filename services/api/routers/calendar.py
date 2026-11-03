"""Calendar endpoints: sample schedule, .ics import, Google not configured."""
from datetime import datetime, timezone

import requests
import json
from pathlib import Path

from fastapi import APIRouter, Body, HTTPException

from tools import calendar as cal

USER_DIR = Path(__file__).resolve().parents[3] / "data" / "user"
router = APIRouter(tags=["calendar"])  # full paths: also serves /routes/week


@router.get("/calendar/status")
def status() -> dict:
    return {"source": "ics" if cal.IMPORTED else "sample", "google": cal.GOOGLE, "imported": len(cal.IMPORTED)}


@router.post("/calendar/import")
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
    for f in USER_DIR.glob("*_week.json"):
        f.unlink()  # saved weeks are stale after an import
    return {"source": "ics", "imported": len(evs)}


@router.get("/calendar/next")
def calendar_next() -> dict:
    now = datetime.now(cal.TZ)
    e = cal.next_event(now)
    if e:
        try:
            from planner.engine import resolve_place
            e = dict(e, place_id=(resolve_place(e["location"]) or {}).get("place_id"))
        except Exception:
            pass
    return {"source": e["source"] if e else "none", "synthetic": not cal.IMPORTED, "event": e,
            "as_of": now.astimezone(timezone.utc).isoformat()}


@router.get("/calendar/day")
def calendar_day() -> dict:
    return {"source": "ics" if cal.IMPORTED else "sample", "events": cal.events(datetime.now(cal.TZ))}


def get_week(user: str = "demo", refresh: bool = False) -> dict:
    """Weekly routes grouped by weekday; entries match /day/plan. Saved to data/user/<user>_week.json."""
    from routers.day import DayEvent, DayRequest, day_plan
    now = datetime.now(cal.TZ)
    safe = "".join(c for c in user if c.isalnum() or c in "-_") or "demo"
    f = USER_DIR / f"{safe}_week.json"
    mon = cal.monday(now).isoformat()
    if f.exists() and not refresh:
        try:
            w = json.loads(f.read_text(encoding="utf-8"))
            if w.get("week_of") == mon and w.get("source") == ("ics" if cal.IMPORTED else "sample"):
                return w
        except Exception:
            pass
    days = {}
    for name, evs in cal.week(now).items():
        days[name] = day_plan(DayRequest(events=[DayEvent(title=e["title"], place=e["location"], start=e["start"], end=e["end"])
                                                for e in evs], start_place="Student Center"))["entries"]
    w = {"source": "ics" if cal.IMPORTED else "sample", "user": safe, "week_of": mon, "days": days}
    USER_DIR.mkdir(parents=True, exist_ok=True)
    f.write_text(json.dumps(w), encoding="utf-8")
    return w


@router.get("/routes/week")
def routes_week(user: str = "demo", refresh: bool = False) -> dict:
    return get_week(user, refresh)
