# StingerDelay-3D API

FastAPI scaffold for the shared planner / calendar / signals backend (Wave A3).

## Setup

From this directory (`services/api`):

```bash
python -m venv .venv
# Windows
.venv\Scripts\activate
# macOS / Linux
source .venv/bin/activate

pip install -r requirements.txt
```

## Run

```bash
# from services/api
uvicorn main:app --reload --host 0.0.0.0 --port 8000
```

OpenAPI docs: http://localhost:8000/docs

CORS allows `http://localhost:5173` (Vite) and `http://localhost:8080` (web-sim static).

## Endpoints (v0 scaffold)

| Method | Path | Status |
|---|---|---|
| `GET` | `/health` | live |
| `POST` | `/trips/plan` | **501** stub (B2) |
| `GET` | `/calendar/next` | mock event |
| `GET` | `/signals/x` | neutral stub |

## Test

```bash
# from services/api
pytest -q
```
