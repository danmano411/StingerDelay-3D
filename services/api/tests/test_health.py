"""Health + trip plan scaffold tests."""

from fastapi.testclient import TestClient

from main import app

client = TestClient(app)


def test_health_ok():
    res = client.get("/health")
    assert res.status_code == 200
    body = res.json()
    assert body["status"] == "ok"
    assert "service" in body


def test_plan_empty_body_422():
    res = client.post("/trips/plan", json={})
    assert res.status_code == 422


def test_plan_ok():
    res = client.post("/trips/plan", json={"constraints": {
        "origin": {"lat": 33.7734, "lon": -84.3992}, "destination": {"lat": 33.7775, "lon": -84.3956}}})
    assert res.status_code == 200
    assert res.json()["trace"]["plan"]["legs"]


def test_calendar_next_mock():
    res = client.get("/calendar/next")
    assert res.status_code == 200
    body = res.json()
    assert body["source"] == "sample"
    assert body["event"]["place_id"] == "klaus"


def test_signals_x_stub():
    res = client.get("/signals/x")
    assert res.status_code == 200
    body = res.json()
    assert body["badge"] == "secondary_social"
    assert body["active"] is False
