"""Calendar sources: labeled sample schedule + .ics import (in memory). Google OAuth not configured."""
import re
from datetime import datetime, timedelta
from zoneinfo import ZoneInfo

TZ = ZoneInfo("America/New_York")
IMPORTED: list[dict] = []
GOOGLE = "needs GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET"


def sample(now: datetime) -> list[dict]:
    d = now.astimezone(TZ).replace(second=0, microsecond=0)
    rows = [("CS 1331 Lecture", "Klaus", 9, 0), ("MATH 2551", "Clough", 11, 0), ("Study group", "Student Center", 13, 30)]
    out = []
    for i, (t, loc, h, m) in enumerate(rows):
        s = d.replace(hour=h, minute=m)
        out.append({"id": f"sample-{i}", "title": t, "location": loc, "source": "sample",
                    "start": s.isoformat(), "end": (s + timedelta(minutes=50)).isoformat()})
    return out


def _dt(v: str) -> datetime:
    v = v.strip()
    if v.endswith("Z"):
        return datetime.strptime(v, "%Y%m%dT%H%M%SZ").replace(tzinfo=ZoneInfo("UTC")).astimezone(TZ)
    v = v[:15] if "T" in v else v[:8] + "T000000"
    return datetime.strptime(v, "%Y%m%dT%H%M%S").replace(tzinfo=TZ)


def parse_ics(text: str) -> list[dict]:
    text = re.sub(r"\r?\n[ \t]", "", text)
    out = []
    for blk in re.findall(r"BEGIN:VEVENT(.*?)END:VEVENT", text, re.S):
        f = {}
        for ln in blk.strip().splitlines():
            k, _, v = ln.partition(":")
            f[k.split(";")[0].upper()] = v.strip()
        if "DTSTART" in f:
            s = _dt(f["DTSTART"])
            e = _dt(f["DTEND"]) if "DTEND" in f else s + timedelta(hours=1)
            out.append({"id": f.get("UID", f"ics-{len(out)}"), "title": f.get("SUMMARY", "Event"),
                        "location": f.get("LOCATION", ""), "source": "ics",
                        "start": s.isoformat(), "end": e.isoformat()})
    return out


def events(now: datetime) -> list[dict]:
    """Imported events if any, else the labeled sample schedule; only now's local date."""
    day = now.astimezone(TZ).date()
    src = IMPORTED or sample(now)
    return sorted((e for e in src if datetime.fromisoformat(e["start"]).astimezone(TZ).date() == day),
                  key=lambda e: e["start"])


def next_event(now: datetime):
    return next((e for e in events(now) if datetime.fromisoformat(e["end"]) > now), None)
