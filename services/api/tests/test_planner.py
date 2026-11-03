from datetime import datetime, timedelta, timezone

from contracts import PlaceRef, PlanConstraints
from planner.engine import plan, resolve_place
from verify.numbers import check, template

NOW = datetime(2026, 11, 3, 8, 0, tzinfo=timezone.utc)


def ref(q):
    p = resolve_place(q)
    return PlaceRef(lat=p["lat"], lon=p["lon"], place_id=p["place_id"])


def mk(a, b, **kw):
    return plan(PlanConstraints(origin=ref(a), destination=ref(b), **kw), now=NOW)


def test_routes_and_ordering():
    for a, b in [("Student Center", "Klaus"), ("Klaus", "Kendeda")]:
        t = mk(a, b)
        q = t.plan.total_s
        assert q.p10 <= q.p50 <= q.p90
        assert {p.mode for p in [t.plan, *t.alternatives]} >= {"walk_only"}


def test_deterministic_and_arrive_by():
    kw = dict(arrive_by=NOW + timedelta(minutes=30))
    a, b = mk("Student Center", "Klaus", **kw), mk("Student Center", "Klaus", **kw)
    assert a == b
    assert a.status in ("ok", "at_risk")


def test_verify():
    t = mk("Klaus", "Kendeda")
    ok, bad = check(template(t), t)
    assert ok, bad
    ok, bad = check("Leave by 3:41, arrive around 4:02.", t)
    assert not ok


def test_day_plan_needs_place():
    from fastapi.testclient import TestClient
    from main import app
    r = TestClient(app).post("/day/plan", json={"start_place": "Klaus", "events": [
        {"title": "A", "place": "Kendeda", "start": "2026-11-03T13:00:00+00:00"},
        {"title": "B", "place": "zzzz nowhere", "start": "2026-11-03T14:00:00+00:00"}]})
    e = r.json()["entries"]
    assert e[0]["trace"] and e[1]["needs_place"]
