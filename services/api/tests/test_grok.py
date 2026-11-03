"""Grok chat tests: no network, fake planner/verify."""
from datetime import datetime, timedelta, timezone
from types import SimpleNamespace as NS

import pytest
from fastapi import FastAPI
from fastapi.testclient import TestClient

from grok import agent, state
from routers import calendar as cal_router, grok as grok_router

PLACES = {"klaus": ("Klaus", 33.777, -84.396), "student center": ("Student Center", 33.774, -84.399),
          "crc": ("CRC", 33.775, -84.403), "clough": ("Clough", 33.775, -84.396)}
NOW = "2026-11-02T07:00:00-05:00"


class FakeEngine:
    @staticmethod
    def resolve_place(q):
        k = (q or "").lower().replace("the ", "").strip()
        for key, (n, la, lo) in PLACES.items():
            if key in k:
                return {"place_id": key, "name": n, "lat": la, "lon": lo, "score": 1.0}

    @staticmethod
    def list_places():
        return [{"name": n} for n, _, _ in PLACES.values()]

    @staticmethod
    def plan(c, now=None):
        leave = c.arrive_by - timedelta(minutes=10) if c.arrive_by else now
        leg = NS(kind="walk", label="Walk north")
        p = NS(legs=[leg], leave_at=leave, explanation_facts=["walk"])
        return NS(plan=p, model_dump=lambda mode=None: {"arrive_by": str(c.arrive_by), "stairs": c.prefs.avoid_stairs,
                                                         "origin": c.origin.place_id, "dest": c.destination.place_id})


class FakeVerify:
    check = staticmethod(lambda text, trace: (True, []))
    template = staticmethod(lambda trace: "Walk about 10 minutes.")


@pytest.fixture
def client(monkeypatch):
    monkeypatch.delenv("XAI_API_KEY", raising=False)
    monkeypatch.setattr(agent, "_eng", lambda: FakeEngine)
    monkeypatch.setattr(agent, "_verify", lambda: FakeVerify)
    state.CONVS.clear()
    app = FastAPI()
    app.include_router(grok_router.router)
    app.include_router(cal_router.router)
    return TestClient(app)


def say(c, m, cid="t"):
    r = c.post("/grok/chat", json={"conversation_id": cid, "message": m, "now": NOW})
    assert r.status_code == 200
    return r.json()


def test_make_a_plan_asks(client):
    r = say(client, "Hey, I want to make a plan")
    assert r["action"] is None and "where" in r["reply"].lower() and r["source"] == "local"


def test_plan_intent_defaults_origin(client):
    r = say(client, "get me to Klaus by 8:30, avoid stairs")
    assert r["action"] == "show_path" and r["trace"]["stairs"] is True
    assert "from Student Center" in r["reply"]


def test_stacked_constraints(client):
    say(client, "I want to get to Klaus at 8:30")
    r = say(client, "make it 8:15")
    assert "8:15" in r["trace"]["arrive_by"] and "arrive by 8:15" in r["reply"]
    r = say(client, "from the CRC")
    assert r["trace"]["origin"] == "crc" and r["trace"]["dest"] == "klaus"
    assert "8:15" in r["trace"]["arrive_by"]


def test_walk_and_stop(client):
    assert say(client, "walk it", "x")["action"] is None
    say(client, "get me to Klaus by 8:30")
    r = say(client, "walk that path")
    assert r["action"] == "walk" and r["trace"] and "Walk north" in r["reply"]
    assert say(client, "stop")["action"] == "stop_walk"


def test_calendar_day(client):
    r = say(client, "plan my day")
    assert [e["location"] for e in r["events"]] == ["Klaus", "Clough", "Student Center"]
    assert "Klaus" in r["reply"] and r["events"][0]["mode"] == "walk"


def test_status_and_transcribe_without_key(client):
    assert client.get("/grok/status").json()["key_present"] is False
    assert client.post("/grok/transcribe", files={"file": ("a.webm", b"x")}).status_code == 503
    assert client.get("/calendar/day").json()["source"] == "sample"
