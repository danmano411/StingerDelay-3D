"""StingerDelay-3D FastAPI service."""

from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from routers import calendar, day, health, signals, trips

app = FastAPI(title="StingerDelay-3D API", version="0.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[],
    allow_origin_regex=r"https?://(localhost|127\.0\.0\.1)(:\d+)?",
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(trips.router)
app.include_router(day.router)
app.include_router(calendar.router)
app.include_router(signals.router)

try:
    from routers import grok  # type: ignore

    app.include_router(grok.router)
except ImportError:
    pass

_sim = Path(__file__).resolve().parents[2] / "web-sim"
if _sim.is_dir():
    app.mount("/sim", StaticFiles(directory=str(_sim), html=True), name="sim")
