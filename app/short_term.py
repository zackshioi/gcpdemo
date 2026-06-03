"""Short-term memory: per-session conversation history in Firestore.

Data model (Firestore Native):
    sessions/{session_id}
        created_at: timestamp
        messages/{auto_id}
            role: "user" | "model"
            text: string
            ts:   server timestamp   (used to order the transcript)

This persists history across Cloud Run cold starts/restarts — the browser holds
only the session id, the transcript lives here. Auth is ADC (same as gemini.py).
"""

import os
from functools import lru_cache

from google.cloud import firestore

ROLES = ("user", "model")


@lru_cache(maxsize=1)
def _db() -> firestore.Client:
    return firestore.Client(project=os.environ["GCP_PROJECT"])


def _session_ref(session_id: str):
    return _db().collection("sessions").document(session_id)


def get_history(session_id: str) -> list[dict]:
    """Return the session transcript oldest-first as [{role, text}, ...]."""
    msgs = (
        _session_ref(session_id)
        .collection("messages")
        .order_by("ts")
        .stream()
    )
    return [{"role": m.get("role"), "text": m.get("text")} for m in msgs]


def add_message(session_id: str, role: str, text: str) -> None:
    """Append one message. Creates the session doc on first write."""
    assert role in ROLES, f"bad role: {role}"
    ref = _session_ref(session_id)
    # merge=True so we set created_at once without clobbering it later.
    ref.set({"created_at": firestore.SERVER_TIMESTAMP}, merge=True)
    ref.collection("messages").add(
        {"role": role, "text": text, "ts": firestore.SERVER_TIMESTAMP}
    )


def delete_session(session_id: str) -> None:
    """Delete a session and all its messages (sidebar 'delete')."""
    ref = _session_ref(session_id)
    for m in ref.collection("messages").stream():
        m.reference.delete()
    ref.delete()
