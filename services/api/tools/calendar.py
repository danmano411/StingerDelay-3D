"""Calendar sources: labeled sample week + .ics import (RRULE weekly expanded). Google OAuth not configured."""
import re
from datetime import date, datetime, timedelta
from zoneinfo import ZoneInfo

TZ = ZoneInfo("America/New_York")
IMPORTED: list[dict] = []
GOOGLE = "needs GOOGLE_CLIENT_ID and GOOGLE_CLIENT_SECRET"
DAYS = ["monday", "tuesday", "wednesday", "thursday", "friday"]
_BYDAY = {"MO": 0, "TU": 1, "WE": 2, "TH": 3, "FR": 4, "SA": 5, "SU": 6}
# weekday -> (title, location, hour, minute)
SAMPLE_WEEK = {
    0: [("CS 1331 Lecture", "Klaus", 9, 0), ("MATH 2551", "Clough", 11, 0), ("Study group", "Student Center", 13, 30)],
    1: [("PHYS 2211", "Clough", 8, 30), ("CS 1331 Lab", "Klaus", 10, 0), ("Club meeting", "Student Center", 14, 0)],
    2: [("MATH 2551", "Clough", 11, 0), ("CS 1331 Lecture", "Klaus", 9, 0), ("Gym", "CRC", 16, 0)],
    3: [("PHYS 2211", "Clough", 8, 30), ("English 1101", "Student Center", 12, 0), ("CS 1331 Lab", "Klaus", 15, 0)],
    4: [("CS 1331 Lecture", "Klaus", 9, 0), ("Office hours", "Clough", 13, 0), ("Gym", "CRC", 15, 30)],
}


def monday(now: datetime) -> date:
    d = now.astimezone(TZ).date()
    return d - timedelta(days=d.weekday())


def sample_day(d: date) -> list[dict]:
    rows = sorted(SAMPLE_WEEK.get(d.weekday(), SAMPLE_WEEK[0]), key=lambda r: r[2:])  # weekend shows Monday's schedule
    out = []
    for i, (t, loc, h, m) in enumerate(rows):
        s = datetime(d.year, d.month, d.day, h, m, tzinfo=TZ)
        out.append({"id": f"sample-{d.weekday()}-{i}", "title": t, "location": loc, "source": "sample",
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
            ev = {"id": f.get("UID", f"ics-{len(out)}"), "title": f.get("SUMMARY", "Event"),
                  "location": f.get("LOCATION", ""), "source": "ics", "start": s.isoformat(), "end": e.isoformat()}
            m = re.search(r"FREQ=WEEKLY.*?BYDAY=([A-Z,]+)", f.get("RRULE", ""))
            if m:
                ev["byday"] = [_BYDAY[x[-2:]] for x in m[1].split(",") if x[-2:] in _BYDAY]
            out.append(ev)
    return out


def _on(e: dict, d: date):
    """The event as it occurs on date d (weekly RRULE expanded), else None."""
    s, en = datetime.fromisoformat(e["start"]), datetime.fromisoformat(e["end"])
    if s.astimezone(TZ).date() == d:
        return e
    if d.weekday() in e.get("byday", []) and d > s.astimezone(TZ).date():
        sh = datetime.combine(d, s.astimezone(TZ).timetz())
        return dict(e, start=sh.isoformat(), end=(sh + (en - s)).isoformat())
    return None


def events_on(d: date) -> list[dict]:
    if not IMPORTED:
        return sample_day(d)
    return sorted((x for x in (_on(e, d) for e in IMPORTED) if x), key=lambda e: e["start"])


def events(now: datetime) -> list[dict]:
    return events_on(now.astimezone(TZ).date())


def week(now: datetime) -> dict:
    """{monday: [events dated this week], ... friday}."""
    m = monday(now)
    return {n: events_on(m + timedelta(days=i)) for i, n in enumerate(DAYS)}


def next_event(now: datetime):
    evs = events(now)
    return next((e for e in evs if datetime.fromisoformat(e["end"]) > now), None if IMPORTED else (evs[0] if evs else None))
