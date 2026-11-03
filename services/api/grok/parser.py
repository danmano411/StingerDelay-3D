"""Deterministic local intent parser."""
import re
from datetime import datetime, timedelta

CAL = re.compile(r"calendar|plan my day|my schedule|next (event|class)|leave for my next", re.I)
STOP = re.compile(r"^\s*(stop|cancel|end)\b", re.I)
WALK = re.compile(r"^\s*(walk (that|it|this)|walk$|start|go|let'?s go|begin)\b", re.I)
TIME = re.compile(r"\b(\d{1,2}):(\d{2})\s*(am|pm)?\b|\b(\d{3,4})\s*(am|pm)?\b|\b(\d{1,2})\s*(am|pm)\b|\bat (noon)\b", re.I)
REL = re.compile(r"\bin (\d+)\s*(?:min|minutes)\b", re.I)


def parse_time(text: str, now: datetime):
    """-> (datetime|None, is_tomorrow)."""
    m = REL.search(text)
    if m:
        return now + timedelta(minutes=int(m[1])), False
    m = TIME.search(text)
    if not m:
        return None, False
    if m[8]:
        h, mi, ap = 12, 0, None
    elif m[1]:
        h, mi, ap = int(m[1]), int(m[2]), m[3]
    elif m[4]:
        v = m[4]
        h, mi, ap = int(v[:-2]), int(v[-2:]), m[5]
    else:
        h, mi, ap = int(m[6]), 0, m[7]
    if mi > 59 or h > 24:
        return None, False
    if ap:
        h = h % 12 + (12 if ap.lower() == "pm" else 0)
    elif 1 <= h <= 6:
        h += 12  # ponytail: bare 1-6 means afternoon on a campus day
    t = now.replace(hour=h % 24, minute=mi, second=0, microsecond=0)
    if t <= now:
        return t + timedelta(days=1), True
    return t, False


def _clean(s: str) -> str:
    return re.sub(r"^(the|my)\s+", "", s.strip(" .,!?"), flags=re.I).strip()


STATED = re.compile(r"(?:,?\s*and\s+)?(?:(?:right now|currently)\s+(?:it'?s\s+|it is\s+)?|(?=it'?s\s+\d+(?::\d+)?\s*(?:am|pm)?\s+now)it'?s\s+)(\d{1,2})(?::(\d{2}))?\s*(am|pm)?(?:\s+now)?", re.I)
DAYS = ["monday", "tuesday", "wednesday", "thursday", "friday", "saturday", "sunday"]
WEEK = re.compile(r"plan my week|my week|weekly|(" + "|".join(DAYS) + r").*route|routes?.*(" + "|".join(DAYS) + r")", re.I)


def stated_now(msg: str, now: datetime):
    """'right now it's 6' -> (effective now, msg without that clause); None when absent."""
    m = STATED.search(msg)
    if not m:
        return None, msg
    rest = msg[:m.start()] + msg[m.end():]
    mid = now.replace(hour=0, minute=0, second=0, microsecond=0)
    dl, _ = parse_time(rest, mid)
    h, mi = int(m[1]), int(m[2] or 0)
    cands = [h % 12 + (12 if m[3].lower() == "pm" else 0)] if m[3] else [h % 12, h % 12 + 12]
    ts = [mid.replace(hour=c, minute=mi) for c in cands if c < 24 and mi < 60]
    ts = [t for t in ts if dl is None or t < dl] or ts
    return (max(ts) if ts else None), rest


def parse(msg: str, now: datetime) -> dict:
    sn, msg = stated_now(msg, now)
    if sn:
        now = sn
    out = {"now": sn, "day": None, "intent": "chat", "dest": None, "origin": None, "time": None, "tomorrow": False,
           "avoid_stairs": bool(re.search(r"avoid(ing)? (the )?stairs|no stairs|step.?free", msg, re.I))}
    if STOP.search(msg):
        out["intent"] = "stop"
        return out
    mw = WEEK.search(msg)
    if mw:
        out["intent"] = "week"
        out["day"] = next((d for d in DAYS if d in msg.lower()), None)
        return out
    if CAL.search(msg):
        out["intent"] = "calendar"
        return out
    if WALK.search(msg) and not re.search(r"\bto\b", msg, re.I):
        out["intent"] = "walk"
        return out
    m = re.search(r"\bfrom (.+?)(?=\s+(?:to|by|at|before|avoid)\b|[,.]|$)", msg, re.I)
    if m:
        out["origin"] = _clean(m[1])
    for m in re.finditer(r"\b(?:to|at|for|towards?)\s+(?!\d)(.+?)(?=\s+(?:by|at|before|from|avoid|in)\b|[,.]|$)", msg, re.I):
        c = re.sub(r"^(get|go|be|head|walk)\s+(to\s+)?", "", _clean(m[1]), flags=re.I)
        if c and c.lower() not in ("make a plan", "make plan"):
            out["dest"] = c
            break
    out["time"], out["tomorrow"] = parse_time(msg, now)
    if any(out[k] for k in ("dest", "origin", "time", "avoid_stairs")) or re.search(r"\bplan\b|get me|take me|route", msg, re.I):
        out["intent"] = "plan"
    return out
