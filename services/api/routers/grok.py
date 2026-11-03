"""Grok chat, status, transcribe."""
import requests
from fastapi import APIRouter, File, HTTPException, UploadFile
from pydantic import BaseModel

from grok import agent

router = APIRouter(prefix="/grok", tags=["grok"])


class Origin(BaseModel):
    lat: float
    lon: float


class ChatIn(BaseModel):
    conversation_id: str
    message: str
    now: str | None = None
    origin: Origin | None = None


@router.post("/chat")
def chat(b: ChatIn) -> dict:
    return agent.chat(b.conversation_id, b.message, b.now, b.origin.model_dump() if b.origin else None)


@router.get("/status")
def status() -> dict:
    return agent.status()


@router.post("/transcribe")
async def transcribe(file: UploadFile = File(...)) -> dict:
    if not agent.status()["key_valid"]:
        raise HTTPException(503, "use browser speech")
    try:
        r = requests.post("https://api.x.ai/v1/stt", headers={"Authorization": f"Bearer {agent.key()}"}, timeout=30,
                          data={"model": "grok-voice-transcribe-2.0"},
                          files={"file": (file.filename or "audio", await file.read(), file.content_type or "audio/webm")})
        r.raise_for_status()
        return {"text": r.json().get("text", "")}
    except Exception:
        raise HTTPException(503, "use browser speech")
