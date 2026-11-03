"""Deterministic trip planner: walk-only vs walk+wait+ride+walk, Monte Carlo."""
from __future__ import annotations

import difflib
import hashlib
import json
import math
import random
import statistics
from datetime import datetime, timedelta
from pathlib import Path

from contracts import Leg, LegKind, PlanConstraints, Quantiles, TripPlan, TripTrace
from predictor import MODEL_ID, mae_for_eta

ROOT = Path(__file__).resolve().parents[3]
N = 300
MAX_STOP_WALK = 700.0
# route name -> (loop_s, n_bus, loop_len_m)
STATS = {
    "Red": (2133, 3.67, 4654), "Green": (1569.5, 2, 4279), "Gold": (2756, 4, 6503),
    "Clough": (1793, 4, 3478), "Blue": (2271, 3.67, 4955),
}
_D: dict = {}


def _load():
    if not _D:
        n = ROOT / "data/normalized"
        _D["places"] = json.loads((n / "places.json").read_text(encoding="utf-8"))
        _D["stops"] = {s["id"]: s for s in json.loads((n / "stops.json").read_text(encoding="utf-8"))}
        _D["routes"] = json.loads((n / "routes.json").read_text(encoding="utf-8"))
        for r in _D["routes"]:
            _prep(r)
    return _D


def hav(a, b):
    p1, p2 = math.radians(a[0]), math.radians(b[0])
    h = math.sin((p2 - p1) / 2) ** 2 + math.cos(p1) * math.cos(p2) * math.sin(math.radians(b[1] - a[1]) / 2) ** 2
    return 2 * 6371000 * math.asin(math.sqrt(h))


def _prep(r):
    stops = [s for s in r["stops"] if s["id"] in _D["stops"]]
    cum, t = [], 0.0
    for s in stops:
        cum.append(t)
        t += s.get("dwell", 0) + s.get("to_next", 0)
    r["_stops"], r["_cum"], r["_tot"] = stops, cum, t or 1.0
    r["_scale"] = STATS.get(r["name"], (2000, 3, 4000))[0] / r["_tot"]
    # monotone mapping of stops to line indices (handles out-and-back lines)
    line, idx, prev = r["line"], [], 0
    for s in stops:
        c = _D["stops"][s["id"]]
        best = min(range(prev, len(line)), key=lambda i: hav(line[i], (c["lat"], c["lon"])), default=prev)
        idx.append(best)
        prev = best
    r["_idx"] = idx


def list_places() -> list[dict]:
    return [{"place_id": p["id"], "name": p["name"], "lat": p["lat"], "lon": p["lon"]} for p in _load()["places"]]


def resolve_place(query: str):
    d = _load()
    q = (query or "").strip().lower().replace("_", "-")
    if not q:
        return None
    cands = []
    for p in d["places"]:
        base = {"place_id": p["id"], "name": p["name"], "lat": p["lat"], "lon": p["lon"]}
        for k in {p["id"], p["name"].lower(), p.get("stop_name", "").lower(), p["id"].replace("-", " ")}:
            if k:
                cands.append((k, base))
    for s in d["stops"].values():
        cands.append((s["name"].lower(), {"place_id": f"stop-{s['id']}", "name": s["name"], "lat": s["lat"], "lon": s["lon"]}))
    for k, b in cands:
        if k == q:
            return {**b, "score": 1.0}
    best, bs = None, 0.0
    for k, b in cands:
        sc = difflib.SequenceMatcher(None, q, k).ratio()
        if len(q) >= 4 and (q in k or k in q):
            sc = max(sc, 0.85)
        if sc > bs:
            best, bs = b, sc
    return {**best, "score": round(bs, 3)} if best and bs >= 0.6 else None


def _seed(*parts) -> int:
    return int(hashlib.sha256(repr(parts).encode()).hexdigest()[:12], 16)


def _name(ref):
    d = _load()
    if ref.place_id:
        for p in d["places"]:
            if p["id"] == ref.place_id:
                return p["name"]
    for p in d["places"]:
        if hav((ref.lat, ref.lon), (p["lat"], p["lon"])) < 80:
            return p["name"]
    return f"{ref.lat:.4f}, {ref.lon:.4f}"


def _sp(sid):
    s = _load()["stops"][sid]
    return (s["lat"], s["lon"])


def _slice(r, i, j):
    line, idx = r["line"], r["_idx"]
    a, b = idx[i], idx[j]
    pts = line[a:b + 1] if b >= a else line[a:] + line[:b + 1]
    if len(pts) > 190:
        step = math.ceil(len(pts) / 190)
        pts = pts[::step] + [pts[-1]]
    return [list(p) for p in pts]


def _candidates(o, dst):
    out = []
    for r in _load()["routes"]:
        st = r["_stops"]
        best = None
        for i, si in enumerate(st):
            wo = hav(o, _sp(si["id"]))
            if wo > MAX_STOP_WALK:
                continue
            for j, sj in enumerate(st):
                wd = hav(dst, _sp(sj["id"]))
                if wd > MAX_STOP_WALK or i == j:
                    continue
                ride = ((r["_cum"][j] - r["_cum"][i]) % r["_tot"]) * r["_scale"]
                score = (wo + wd) * 1.3 + ride * 1.3
                if best is None or score < best[0]:
                    best = (score, r, i, j, wo * 1.3, wd * 1.3, ride)
        if best:
            out.append(best[1:])
    return out


def _eval(cand, o, dst, leave_ts, speed, seed_key):
    rnd = random.Random(_seed(seed_key, int(leave_ts)))
    if cand is None:
        dist = hav(o, dst) * 1.3
        base = dist / speed
        tot = sorted(base * math.exp(rnd.gauss(0, 0.08)) for _ in range(N))
        return dict(totals=tot, p_catch=None, wait_med=0, ride=0, dist=dist)
    r, i, j, wo, wd, ride = cand
    st = r["_stops"]
    loop_s, n_bus, _ = STATS.get(r["name"], (2000, 3, 4000))
    H = loop_s / n_bus
    phase = (_seed("phase", r["id"], st[i]["id"]) % 100000) / 100000 * H
    w1, w2 = wo / speed, wd / speed
    totals, waits, caught = [], [], 0
    for _ in range(N):
        t_arr = leave_ts + w1 * math.exp(rnd.gauss(0, 0.08))
        eta = (phase - t_arr) % H
        wait = eta + rnd.gauss(0, mae_for_eta(eta) * 1.25)
        if wait < 0:
            wait += H
        else:
            caught += 1
        end = t_arr + wait + ride * (1 + rnd.gauss(0, 0.06)) + w2 * math.exp(rnd.gauss(0, 0.08))
        totals.append(end - leave_ts)
        waits.append(wait)
    totals.sort()
    return dict(totals=totals, p_catch=caught / N, wait_med=statistics.median(waits), ride=ride,
                dist=wo + wd, w1=w1, w2=w2)


def _q(a, f):
    return a[min(len(a) - 1, int(f * len(a)))]


def _build(cand, ev, o, dst, leave, deadline, speed, note, dname):
    tot = ev["totals"]
    p10, p50, p90 = _q(tot, .1), statistics.median(tot), _q(tot, .9)
    lt = leave.timestamp()
    p_on = 1.0 if deadline is None else sum(1 for t in tot if lt + t <= deadline) / N
    facts = []
    if cand is None:
        legs = [Leg(kind=LegKind.walk, duration_s_p50=round(p50, 1), label=f"Walk to {dname}",
                    path=[list(o), list(dst)], distance_m=round(ev["dist"], 1), estimate=True)]
        facts.append(f"Walking is about {round(ev['dist'])} m")
        mode = "walk_only"
    else:
        r, i, j, wo, wd, ride = cand
        st, d = r["_stops"], _load()["stops"]
        sa, sb = d[st[i]["id"]], d[st[j]["id"]]
        syn = bool(r.get("synthetic"))
        loop_s, n_bus, L = STATS.get(r["name"], (2000, 3, 4000))
        legs = [
            Leg(kind=LegKind.walk, duration_s_p50=round(ev["w1"], 1), label=f"Walk to {sa['name']}",
                to_stop_id=str(sa["id"]), path=[list(o), [sa["lat"], sa["lon"]]],
                distance_m=round(wo, 1), estimate=True),
            Leg(kind=LegKind.wait, duration_s_p50=round(ev["wait_med"], 1), label=f"Wait for the {r['name']}",
                route_id=r["name"], from_stop_id=str(sa["id"]), synthetic=syn),
            Leg(kind=LegKind.ride, duration_s_p50=round(ride, 1), label=f"Ride the {r['name']} to {sb['name']}",
                route_id=r["name"], from_stop_id=str(sa["id"]), to_stop_id=str(sb["id"]),
                path=_slice(r, i, j), distance_m=round(L * ride / loop_s, 1), synthetic=syn),
            Leg(kind=LegKind.transfer_walk, duration_s_p50=round(ev["w2"], 1), label=f"Walk to {dname}",
                from_stop_id=str(sb["id"]), path=[[sb["lat"], sb["lon"]], list(dst)],
                distance_m=round(wd, 1), estimate=True),
        ]
        facts.append(f"The {r['name']} comes about every {round(loop_s / n_bus / 60)} min")
        facts.append(f"{round(ev['p_catch'] * 100)}% chance to catch this bus")
        if syn:
            facts.append("Blue route data is synthetic")
        mode = "bus"
    if note:
        facts.append(note)
    return TripPlan(legs=legs, total_s=Quantiles(p10=round(p10, 1), p50=round(p50, 1), p90=round(p90, 1)),
                    leave_at=leave, arrive_at=leave + timedelta(seconds=p50), p_on_time=p_on,
                    p_catch=ev["p_catch"], explanation_facts=facts, mode=mode)


def _latest_leave(cand, o, dst, lo, hi, speed, key):
    """Latest leave ts in [lo, hi] at 30 s steps with p_on_time >= 0.9, else None."""
    def ok(k):
        ts = lo + 30 * k
        ev = _eval(cand, o, dst, ts, speed, key)
        return sum(1 for t in ev["totals"] if ts + t <= hi) / N >= 0.9
    kmax = int((hi - lo) // 30)
    if kmax < 0 or not ok(0):
        return None
    a, b = 0, kmax
    while a < b:
        m = (a + b + 1) // 2
        if ok(m):
            a = m
        else:
            b = m - 1
    return lo + 30 * a


def _aware(x):
    return x if x is None or x.tzinfo else x.astimezone()


def plan(constraints: PlanConstraints, now: datetime | None = None) -> TripTrace:
    c = constraints
    o, dst = (c.origin.lat, c.origin.lon), (c.destination.lat, c.destination.lon)
    now = _aware(now) or datetime.now().astimezone()
    start = _aware(c.depart_at) or now
    arrive_by = _aware(c.arrive_by)
    speed, note = c.prefs.walk_speed_mps, None
    if c.prefs.avoid_stairs:
        speed, note = 0.8, "stairs data not available yet"
    oname, dname = _name(c.origin), _name(c.destination)
    base_key = (round(o[0], 5), round(o[1], 5), round(dst[0], 5), round(dst[1], 5), speed,
                arrive_by.isoformat() if arrive_by else None, int(start.timestamp()))
    results = []  # (cand, leave_dt, ev, feasible)
    for cd in [None] + _candidates(o, dst):
        key = base_key + ((cd[0]["name"], cd[1], cd[2]) if cd else ("walk",))
        if arrive_by is None:
            results.append((cd, start, _eval(cd, o, dst, start.timestamp(), speed, key), True))
        else:
            lo, hi = start.timestamp(), arrive_by.timestamp()
            ts = _latest_leave(cd, o, dst, lo, hi, speed, key)
            ok = ts is not None
            ts = ts if ok else lo
            results.append((cd, datetime.fromtimestamp(ts, start.tzinfo), _eval(cd, o, dst, ts, speed, key), ok))

    med = lambda x: statistics.median(x[2]["totals"])  # noqa: E731
    walk, bus, status = results[0], results[1:], "ok"
    if arrive_by is None:
        best = min(bus, key=med) if bus else walk
        if med(walk) <= med(best) + 60:
            best = walk
    else:
        feas = [x for x in results if x[3]]
        if feas:
            best = max(feas, key=lambda x: (x[1], -med(x)))
            if walk[3] and walk[1] >= best[1] - timedelta(seconds=60):
                best = walk
        else:
            status = "at_risk"
            dl = arrive_by.timestamp()
            best = max(results, key=lambda x: sum(1 for t in x[2]["totals"] if x[1].timestamp() + t <= dl))
    dl = arrive_by.timestamp() if arrive_by else None
    build = lambda x: _build(x[0], x[2], o, dst, x[1], dl, speed, note, dname)  # noqa: E731
    primary = build(best)
    other = [x for x in results if (x[0] is None) != (best[0] is None)]
    alts = []
    if other:
        alts.append(build(min(other, key=med) if arrive_by is None else max(other, key=lambda x: (x[3], x[1]))))
    trace = TripTrace(plan=primary, alternatives=alts, model_id=MODEL_ID, status=status,
                      confidence_horizon_s=max(0.0, (primary.leave_at - now).total_seconds() + primary.total_s.p50),
                      origin_name=oname, destination_name=dname)
    from verify.numbers import allowed_numbers
    trace.allowed_numbers = allowed_numbers(trace)
    return trace
