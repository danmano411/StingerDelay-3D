"""Number verification: every time/minute/percent/distance in text must come from the trace."""
from __future__ import annotations

import re

from contracts import TripTrace

CLOCK = re.compile(r"\b(\d{1,2}):(\d{2})\s*(?:[ap]\.?m\.?)?", re.I)
PCT = re.compile(r"(\d+(?:\.\d+)?)\s*%")
MIN = re.compile(r"(\d+(?:\.\d+)?)\s*(?:min(?:ute)?s?)\b", re.I)
DIST = re.compile(r"(\d+(?:\.\d+)?)\s*(km|m|meters?|metres?)\b", re.I)


def _tod(dt):
    return (dt.hour * 60 + dt.minute + dt.second / 60) % 720


def _sets(t: TripTrace):
    times, pcts, mins, dists = [], [], [], []
    for p in [t.plan, *t.alternatives]:
        times += [_tod(p.leave_at), _tod(p.arrive_at)]
        pcts += [p.p_on_time * 100] + ([p.p_catch * 100] if p.p_catch is not None else [])
        mins += [p.total_s.p10 / 60, p.total_s.p50 / 60, p.total_s.p90 / 60]
        for l in p.legs:
            mins.append(l.duration_s_p50 / 60)
            if l.distance_m is not None:
                dists.append(l.distance_m)
        for f in p.explanation_facts:
            mins += [float(m.group(1)) for m in MIN.finditer(f)]
            pcts += [float(m.group(1)) for m in PCT.finditer(f)]
            dists += [float(m.group(1)) for m in DIST.finditer(f)]
    return times, pcts, mins, dists


def allowed_numbers(t: TripTrace) -> list[float]:
    return sorted({round(x, 1) for s in _sets(t) for x in s})


def _near(v, pool, tol, mod=None):
    for a in pool:
        d = abs(v - a)
        if mod:
            d = min(d, mod - d)
        if d <= tol + 1e-9:
            return True
    return False


def check(text: str, trace: TripTrace) -> tuple[bool, list[str]]:
    times, pcts, mins, dists = _sets(trace)
    bad = []
    for m in CLOCK.finditer(text):
        v = (int(m.group(1)) % 12) * 60 + int(m.group(2))
        if int(m.group(2)) > 59 or not _near(v, times, 1.0, 720):
            bad.append(m.group(0).strip())
    rest = CLOCK.sub(" ", text)
    for m in PCT.finditer(rest):
        if not _near(float(m.group(1)), pcts, 1.0):
            bad.append(m.group(0))
    rest = PCT.sub(" ", rest)
    for m in MIN.finditer(rest):
        if not _near(float(m.group(1)), mins, 1.0):
            bad.append(m.group(0))
    rest = MIN.sub(" ", rest)
    for m in DIST.finditer(rest):
        v = float(m.group(1)) * (1000 if m.group(2).lower() == "km" else 1)
        if not _near(v, dists, max(10.0, 0.05 * v)):
            bad.append(m.group(0))
    return (not bad, bad)


def _hm(dt):
    return f"{dt.hour % 12 or 12}:{dt.minute:02d}"


def template(t: TripTrace) -> str:
    p = t.plan
    if p.mode == "walk_only":
        body = f"walk {round(p.legs[0].distance_m)} m to {t.destination_name}"
    else:
        w, _, r, w2 = p.legs
        body = (f"walk {round(w.distance_m)} m to the stop, take the {r.route_id} "
                f"({round(r.duration_s_p50 / 60)} min ride), then walk {round(w2.distance_m)} m to {t.destination_name}")
    s = (f"Leave by {_hm(p.leave_at)}, {body}, arrive around {_hm(p.arrive_at)} "
         f"({round(p.total_s.p50 / 60)} min total), {round(p.p_on_time * 100)}% chance on time.")
    if t.status == "at_risk":
        s += " This is at risk of being late."
    return s
