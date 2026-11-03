"""StingerDelay-3D FastAPI service (Wave A3 scaffold)."""

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

from routers import calendar, health, signals, trips

app = FastAPI(title="StingerDelay-3D API", version="0.0.0")

app.add_middleware(
    CORSMiddleware,
    allow_origins=[
        "http://localhost:5173",
        "http://127.0.0.1:5173",
        "http://localhost:8080",
        "http://127.0.0.1:8080",
    ],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(health.router)
app.include_router(trips.router)
app.include_router(calendar.router)
app.include_router(signals.router)
