"""Chat agent: Grok (Responses API tools) with deterministic local fallback."""
import json
import os
import time
from datetime import datetime
from pathlib import Path

import requests

from contracts import PlaceRef, PlanConstraints, PlanPrefs
from tools import calendar as cal
from . import parser, state

TZ = cal.TZ
API = "https://api.x.ai/v1"
DEFAULT_ORIGIN = "Student Center"
_fail = {"until": 0.0, "detail": ""}
_val: dict = {}  # key validity cache


def _env():
    p = Path(__file__).resolve().parents[3] / ".env"
    if p.exists():
        for ln in p.read_text(encoding="utf-8", errors="ignore").splitlines():
            k, _, v = ln.partition("=")
            k = k.strip()
            if k and not k.startswith("#") and k not in os.environ:
                os.environ[k] = v.strip().strip("\"'")


_env()


def key() -> str:
    return os.environ.get("XAI_API_KEY", "").strip()


def model() -> str:
    return os.environ.get("GROK_TEXT_MODEL", "grok-4.7")


def hdr() -> dict:
    return {"Authorization": f"Bearer {key()}", "Content-Type": "application/json"}


def key_valid() -> bool:
    """Cached 60 s; a failed chat call also marks the key bad for 60 s."""
    if not key() or time.time() < _fail["until"]:
        return False
    return True


def status() -> dict:
    k = key()
    if not k:
        return {"provider": "local", "key_present": False, "key_valid": False, "detail": "no XAI_API_KEY"}
    c = _val.get(k)
    if not c or time.time() - c[0] > 60:
        try:
            r = requests.get(f"{API}/models", headers=hdr(), timeout=6)
            c = (time.time(), r.status_code == 200, "ok" if r.status_code == 200 else f"xAI HTTP {r.status_code}")
        except Exception as e:
            c = (time.time(), False, type(e).__name__)
        _val[k] = c
    if not c[1]:
        _fail.update(until=time.time() + 60, detail=c[2])
    return {"provider": "grok" if c[1] else "local", "key_present": True, "key_valid": c[1], "detail": c[2]}


# ---- planner helpers (imported lazily; planner/verify are owned elsewhere) ----
def _eng():
    from planner import engine
    return engine


def _verify():
    from verify import numbers
    return numbers


def _place(q):
    return _eng().resolve_place(q) if q else None


def _ref(p) -> PlaceRef:
    return PlaceRef(lat=p["lat"], lon=p["lon"], place_id=p.get("place_id"))


def _fmt(dt: datetime) -> str:
    return dt.astimezone(TZ).strftime("%I:%M %p").lstrip("0")


def _plan(st: dict, origin_ll, now):
    dest = st["dest"]
    org = st["origin"] or _place(DEFAULT_ORIGIN)
    if origin_ll and not st["origin"]:
        org = {"lat": origin_ll["lat"], "lon": origin_ll["lon"], "name": "your location", "place_id": None}
    c = PlanConstraints(origin=_ref(org), destination=_ref(dest), arrive_by=st["arrive_by"],
                        prefs=PlanPrefs(avoid_stairs=st["avoid_stairs"]))
    st["origin_name"] = org.get("name", DEFAULT_ORIGIN)
    st["trace"] = _eng().plan(c, now=now)
    return st["trace"]


def _day(now, avoid=False):
    """Plan each calendar event from the previous event's place (loop plan())."""
    out, prev = [], _place(DEFAULT_ORIGIN)
    for e in cal.events(now):
        p = _place(e["location"])
        row = dict(e, mode=None, leave_at=None, trace=None)
        if p and prev and p["place_id"] != prev["place_id"]:
            try:
                tr = _eng().plan(PlanConstraints(origin=_ref(prev), destination=_ref(p), prefs=PlanPrefs(avoid_stairs=avoid),
                                                 arrive_by=datetime.fromisoformat(e["start"])), now=now)
                kinds = {str(getattr(l.kind, "value", l.kind)) for l in tr.plan.legs}
                row.update(mode="bus" if "ride" in kinds else "walk", leave_at=tr.plan.leave_at.isoformat(), trace=tr.model_dump(mode="json"))
            except Exception as ex:
                row["error"] = type(ex).__name__
        prev = p or prev
        out.append(row)
    return out


def _day_reply(evs, now):
    if not evs:
        return "No events on your calendar today."
    parts = []
    for e in evs:
        s = f"{e['title']} at {e['location']} ({_fmt(datetime.fromisoformat(e['start']))})"
        if e["mode"]:
            s += f": {e['mode']}, leave {_fmt(datetime.fromisoformat(e['leave_at']))}"
        parts.append(s)
    return f"Today ({evs[0]['source']} schedule): " + "; ".join(parts) + "."


def _result(cid, reply, source, action=None, trace=None, clar=None, events=None, verified=False):
    r = {"conversation_id": cid, "reply": reply, "source": source, "verified": verified, "action": action,
         "trace": trace.model_dump(mode="json") if trace is not None else None, "clarification": clar}
    if events is not None:
        r["events"] = events
    return r


def _check(text, trace):
    """-> (reply, verified). On failure fall back to the template."""
    try:
        v = _verify()
        if trace is None:
            return text, True
        ok, _ = v.check(text, trace)
        if ok:
            return text, True
        return v.template(trace), False
    except Exception:
        return text, False


def _first_instruction(tr) -> str:
    leg = tr.plan.legs[0]
    return f"Starting the walk. First: {leg.label}."


# ---- shared tool implementations ----
def apply_update(st, args, now, origin_ll):
    """Merge tool/parsed fields into state. Returns (changes, error_question)."""
    ch = []
    if args.get("destination"):
        p = _place(args["destination"])
        if not p:
            return ch, {"question": f"I couldn't find '{args['destination']}'. Which building?", "options": [x["name"] for x in (_eng().list_places() or [])[:5]]}
        st["dest"] = p
        ch.append(f"destination {p['name']}")
    if args.get("origin"):
        p = _place(args["origin"])
        if p:
            st["origin"] = p
            ch.append(f"from {p['name']}")
    if args.get("arrive_by"):
        st["arrive_by"] = args["arrive_by"]
        ch.append(f"arrive by {_fmt(args['arrive_by'])}" + (" tomorrow" if args.get("tomorrow") else ""))
    if args.get("avoid_stairs") and not st["avoid_stairs"]:
        st["avoid_stairs"] = True
        ch.append("avoiding stairs")
    return ch, None


def _hhmm(s, now):
    if not s:
        return None
    t, _ = parser.parse_time(s, now)
    return t


def local_chat(cid, msg, now, origin_ll):
    st = state.get(cid)
    p = parser.parse(msg, now)
    it = p["intent"]
    if it == "stop":
        return _result(cid, "Okay, stopped walking.", "local", "stop_walk", st["trace"], verified=True)
    if it == "walk":
        if not st["trace"]:
            return _result(cid, "I don't have a plan to walk yet. Tell me where you want to go and by when.", "local", verified=True)
        r, v = _check(_first_instruction(st["trace"]), st["trace"])
        return _result(cid, r, "local", "walk", st["trace"], verified=v)
    if it == "calendar":
        evs = _day(now, st["avoid_stairs"])
        return _result(cid, _day_reply(evs, now), "local", events=evs, verified=True)
    args = {"destination": p["dest"], "origin": p["origin"], "arrive_by": p["time"], "tomorrow": p["tomorrow"],
            "avoid_stairs": p["avoid_stairs"]}
    ch, q = apply_update(st, args, now, origin_ll)
    if q:
        return _result(cid, q["question"], "local", clar=q, verified=True)
    if not st["dest"]:
        return _result(cid, "Sure. Where do you want to go, and by when?", "local", verified=True)
    try:
        tr = _plan(st, origin_ll, now)
    except Exception as e:
        return _result(cid, f"I couldn't plan that route ({type(e).__name__}).", "local", verified=True)
    head = f"Planning from {st['origin_name']} to {st['dest']['name']}"
    if ch:
        head += " (updated: " + ", ".join(ch) + ")"
    t = _verify().template(tr)
    base = f"Planning from {st['origin_name']} to {st['dest']['name']}. {t}"
    r, v = _check(f"{head}. {t}", tr)
    if not v:  # change list may carry unverified clock times; keep origin/dest wording
        r, v = _check(base, tr)
        if not v:
            r = base
    return _result(cid, r, "local", "show_path", tr, verified=v)


# ---- Grok provider ----
TOOLS = [
    {"type": "function", "name": "update_constraints", "description": "Set or change trip constraints and re-plan.",
     "parameters": {"type": "object", "properties": {
         "destination": {"type": "string"}, "origin": {"type": "string"},
         "arrive_by_local": {"type": "string", "description": "HH:MM 24h"},
         "depart_at_local": {"type": "string"}, "avoid_stairs": {"type": "boolean"}}}},
    {"type": "function", "name": "walk_path", "description": "Start guided walking of the current plan.", "parameters": {"type": "object", "properties": {}}},
    {"type": "function", "name": "stop_walk", "description": "Stop walking.", "parameters": {"type": "object", "properties": {}}},
    {"type": "function", "name": "get_day_plan", "description": "Plan today's calendar trips.", "parameters": {"type": "object", "properties": {}}},
    {"type": "function", "name": "explain_plan", "description": "Facts about the current plan.", "parameters": {"type": "object", "properties": {}}},
]
SYSTEM = ("You are the campus trip assistant. Use tools for anything about places, buses or times. "
          "Speak only numbers that appear in the latest tool result. Never suggest running or unsafe shortcuts. "
          "Keep replies to 1-2 short sentences. If there is no destination, ask where and by when.")


def grok_chat(cid, msg, now, origin_ll):
    st = state.get(cid)
    out = {"action": None, "events": None, "clar": None}
    inp = [{"role": "system", "content": SYSTEM}, {"role": "user", "content": msg}]
    text = ""

    def run(name, a):
        if name == "update_constraints":
            args = {"destination": a.get("destination"), "origin": a.get("origin"),
                    "arrive_by": _hhmm(a.get("arrive_by_local"), now), "avoid_stairs": a.get("avoid_stairs")}
            ch, q = apply_update(st, args, now, origin_ll)
            if q:
                out["clar"] = q
                return {"error": q["question"]}
            if not st["dest"]:
                return {"error": "no destination yet; ask the user"}
            tr = _plan(st, origin_ll, now)
            out["action"] = "show_path"
            return {"changed": ch, "from": st["origin_name"], "to": st["dest"]["name"], "summary": _verify().template(tr)}
        if name == "walk_path":
            if not st["trace"]:
                return {"error": "no plan yet"}
            out["action"] = "walk"
            return {"first_instruction": _first_instruction(st["trace"])}
        if name == "stop_walk":
            out["action"] = "stop_walk"
            return {"ok": True}
        if name == "get_day_plan":
            out["events"] = _day(now, st["avoid_stairs"])
            return {"summary": _day_reply(out["events"], now)}
        if name == "explain_plan":
            return {"facts": st["trace"].plan.explanation_facts if st["trace"] else "no plan yet"}
        return {"error": "unknown tool"}

    for _ in range(3):
        r = requests.post(f"{API}/responses", headers=hdr(), timeout=12,
                          json={"model": model(), "input": inp, "tools": TOOLS, "store": False})
        if r.status_code != 200:
            raise RuntimeError(f"xAI HTTP {r.status_code}")
        items = r.json().get("output", [])
        inp += items
        calls = [i for i in items if i.get("type") == "function_call"]
        text = "".join(c.get("text", "") for i in items if i.get("type") == "message" for c in i.get("content", []))
        if not calls:
            break
        for c in calls:
            try:
                res = run(c["name"], json.loads(c.get("arguments") or "{}"))
            except Exception as e:
                res = {"error": type(e).__name__}
            inp.append({"type": "function_call_output", "call_id": c["call_id"], "output": json.dumps(res, default=str)})
    if not text:
        raise RuntimeError("empty reply")
    tr = st["trace"] if out["action"] in ("show_path", "walk") else None
    reply, ok = _check(text, tr)
    return _result(cid, reply, "grok", out["action"], tr, out["clar"], out["events"], verified=ok)


def chat(cid, msg, now_s=None, origin_ll=None):
    now = datetime.fromisoformat(now_s).astimezone(TZ) if now_s else datetime.now(TZ)
    if key_valid():
        try:
            return grok_chat(cid, msg, now, origin_ll)
        except Exception as e:
            _fail.update(until=time.time() + 60, detail=type(e).__name__)
    return local_chat(cid, msg, now, origin_ll)
