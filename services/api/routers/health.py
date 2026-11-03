"""Health check."""

from fastapi import APIRouter

router = APIRouter(tags=["health"])


@router.get("/health")
def get_health() -> dict:
    return {"status": "ok", "service": "stingerdelay-3d-api", "version": "0.0.0"}
