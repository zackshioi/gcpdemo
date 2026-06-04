"""MemoryChat — FastAPI entrypoint.

F2: chat with SHORT-TERM MEMORY. Each turn is scoped to a `session_id`; the
transcript is persisted in Firestore and replayed to Gemini so the model has
the whole conversation as context. Long-term, cross-session memory (F3) builds
on this orchestration. See docs/PRD.md.
"""

from pathlib import Path

from fastapi import BackgroundTasks, FastAPI, HTTPException
from fastapi.responses import FileResponse
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel

from app import gemini, long_term, short_term

# The frontend is a single static HTML file living next to this module.
STATIC_DIR = Path(__file__).parent / "static"

app = FastAPI(title="MemoryChat", version="0.3.0")


class ChatRequest(BaseModel):
    user_id: str  # identity for long-term memory (F3)
    session_id: str
    message: str


class ChatResponse(BaseModel):
    reply: str


class HistoryResponse(BaseModel):
    messages: list[dict]


@app.get("/health")
def health() -> dict[str, str]:
    """Liveness probe. NOTE: not `/healthz` — Google's Front End intercepts
    `/healthz` on *.run.app and never forwards it to the container."""
    return {"status": "ok"}


@app.post("/chat")
def chat(req: ChatRequest, bg: BackgroundTasks) -> ChatResponse:
    """One turn with both memories:
    1. persist user turn (short-term, Firestore)
    2. retrieve user-scoped long-term memories (Memory Bank)
    3. replay session history + inject memories -> Gemini
    4. persist model turn
    5. fire async long-term extraction for this turn (non-blocking)
    """
    try:
        short_term.add_message(req.session_id, "user", req.message)
        history = short_term.get_history(req.session_id)
        memories = long_term.retrieve(req.user_id)
        reply = gemini.generate(history, memories=memories)
        short_term.add_message(req.session_id, "model", reply)
        # Extract memories from this turn in the background (don't block reply).
        bg.add_task(
            long_term.generate,
            req.user_id,
            [{"role": "user", "text": req.message}, {"role": "model", "text": reply}],
        )
        return ChatResponse(reply=reply)
    except Exception as exc:  # surface upstream failures as 502, don't 500 opaquely
        raise HTTPException(status_code=502, detail=f"chat failed: {exc}")


@app.get("/sessions/{session_id}")
def get_session(session_id: str) -> HistoryResponse:
    """Return a session transcript — used by the UI to load / switch sessions."""
    return HistoryResponse(messages=short_term.get_history(session_id))


@app.delete("/sessions/{session_id}")
def delete_session(session_id: str) -> dict[str, str]:
    """Delete a session and its messages — the sidebar 'delete' action."""
    short_term.delete_session(session_id)
    return {"status": "deleted"}


@app.get("/")
def index() -> FileResponse:
    """Serve the chat UI."""
    return FileResponse(STATIC_DIR / "index.html")


# Serve any other static assets (css/js) under /static. Declared AFTER the API
# routes above so those take precedence over the mount.
app.mount("/static", StaticFiles(directory=STATIC_DIR), name="static")
