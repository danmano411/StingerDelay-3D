"""X / social signals."""
import time

import requests
from fastapi import APIRouter

from grok import agent

router = APIRouter(prefix="/signals", tags=["signals"])
_c: dict = {"t": 0, "v": None}


@router.get("/x")
def signals_x() -> dict:
    return {"source": "stub", "badge": "secondary_social", "active": False, "multiplier": 1.0,
            "notes": "X signals not wired; returns neutral factor", "events": []}


@router.get("/x/feed")
def x_feed() -> dict:
    if not agent.key_valid() or not agent.status()["key_valid"]:
        return {"status": "unavailable", "items": [], "detail": "xAI key missing or invalid"}
    if time.time() - _c["t"] < 600 and _c["v"]:
        return _c["v"]
    try:
        r = requests.post("https://api.x.ai/v1/responses", headers=agent.hdr(), timeout=20, json={
            "model": agent.model(), "tools": [{"type": "x_search"}],
            "input": "What is happening now at Georgia Tech campus? Short bullets, cite posts."}).json()
        text = next((c["text"] for o in r.get("output", []) if o.get("type") == "message"
                     for c in o["content"] if "text" in c), "")
        items = [{"text": text, "url": u} for u in (r.get("citations") or [])[:5]]
        v = {"status": "ok" if items else "empty", "items": items, "detail": "only cited items kept"}
    except Exception as e:
        return {"status": "unavailable", "items": [], "detail": type(e).__name__}
    _c.update(t=time.time(), v=v)
    return v
