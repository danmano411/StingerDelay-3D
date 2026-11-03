# StingerDelay-3D API

FastAPI backend for trip planning, the Grok assistant, calendar schedules, and the embedded 3D simulation. Requires Python 3.10+.

## Setup

From this directory (`services/api`):

```bash
python -m venv .venv
# Windows
.venv\Scripts\activate
# macOS / Linux
source .venv/bin/activate

python -m pip install -r requirements.txt fastapi uvicorn requests python-multipart httpx
```

## Run

```bash
# from services/api
python -m uvicorn main:app --reload --host 127.0.0.1 --port 8000
```

OpenAPI docs: http://127.0.0.1:8000/docs. The API also serves the 3D scene at http://127.0.0.1:8000/sim/index.html.

CORS allows HTTP/HTTPS origins on `localhost` and `127.0.0.1`, including the Vite client on port 5173.

## Endpoints

| Method | Path | Behavior |
|---|---|---|
| `GET` | `/health` | Service health |
| `GET` | `/places` | Known campus places |
| `POST` | `/trips/plan` | Plan a trip; returns a `trace` and `contract_version` |
| `POST` | `/day/plan` | Chain trips between supplied events; provide `start_place` for a route to the first event |
| `GET` | `/routes/week` | Weekday routes; accepts `user` and `refresh` query parameters |
| `GET` | `/calendar/status` | Active source, imported-event count, and Google configuration note |
| `GET` | `/calendar/next` | Next event from the sample or imported schedule |
| `GET` | `/calendar/day` | Today's events |
| `POST` | `/calendar/import` | Import `.ics` text or a URL using a JSON body |
| `GET` | `/grok/status` | xAI key/provider status |
| `POST` | `/grok/chat` | Tool-enabled assistant, with a deterministic local fallback |
| `POST` | `/grok/transcribe` | Multipart audio transcription; returns 503 when unavailable |
| `GET` | `/signals/x` | Neutral social-signal stub; not active in routing |
| `GET` | `/signals/x/feed` | Key-dependent xAI search for cited campus posts; not used by the planner |

## Demo and integration status

No xAI key is required for the local planner, sample calendar, or local assistant. Optional `XAI_API_KEY` and `GROK_TEXT_MODEL` values are read from the server environment or the repository-root `.env`. Keep credentials out of Git.

Bus waits use loop/headway estimates with uncertainty from `data/normalized/delay_lookup.json`. The scene replays GPS, with synthetic Blue buses; it is not a live arrival feed. The current planner does not load trained Stinger Delay model artifacts.

Google OAuth is not implemented. The calendar uses a labeled sample schedule until `.ics` events are imported. Imports are held in server memory and are lost on restart; generated weekly routes are cached under `data/user/`.

The import endpoint accepts JSON such as `{"text": "BEGIN:VCALENDAR..."}` or `{"url": "https://example.com/calendar.ics"}`. To import a local file from a terminal:

```bash
python -c 'import json, pathlib; print(json.dumps({"text": pathlib.Path("schedule.ics").read_text()}))' | curl --fail-with-body -X POST http://127.0.0.1:8000/calendar/import -H "Content-Type: application/json" --data-binary @-
```

The current web **Import .ics** button sends multipart data, which does not match this endpoint's JSON contract. Use the API import above until the client request is aligned.

## Trip planning smoke check

With the API running:

```bash
curl --fail-with-body http://127.0.0.1:8000/health
curl --fail-with-body -X POST http://127.0.0.1:8000/trips/plan \
  -H "Content-Type: application/json" \
  -d '{"constraints":{"origin":{"lat":33.7734,"lon":-84.3992},"destination":{"lat":33.7775,"lon":-84.3956}}}'
```

## Test

```bash
# from services/api
python -m pytest -q
```
