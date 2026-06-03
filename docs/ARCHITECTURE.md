# Architecture

> Kept in sync with the code. Updated as step (7) of every feature.
> Current state: **F2 — short-term memory live** (Firestore session history,
> multi-turn). No long-term memory yet.

## Components (target)
| Component | Tech | Region | Status |
|---|---|---|---|
| Web app | FastAPI on Cloud Run (`min-instances=0`) | us-central1 | F0 (local only) |
| LLM | Gemini 2.5 Flash via `google-genai` (Vertex) | us-central1 | F1 (done) |
| Short-term memory | Firestore (Native) | us-central1 | F2 (done) |
| Long-term memory | Agent Engine — Memory Bank | us-central1 | F3 |
| Tracing | Self-hosted Langfuse | — | F5 |
| CICD | GitHub Actions + WIF | — | F6 (done, brought forward) |
| Hosting | Cloud Run `memorychat` (public) | us-central1 | F6 (done) |

## Toolchain
- **Python**: `uv` (`pyproject.toml` + `uv.lock`).
- **Infra**: Terraform under `infra/` (provider + API enablement at F0; resources
  added per feature).

## Module map (`app/`)
| File | Responsibility | Added in |
|---|---|---|
| `main.py` | FastAPI app, route handlers, request orchestration | F0 |
| `gemini.py` | google-genai client; single `chat()` call | F1 (done) |
| `short_term.py` | Firestore read/write/delete of session history | F2 (done) |
| `long_term.py` | Memory Bank `generate` / `retrieve` | F3 |
| `tracing.py` | Langfuse client + span helpers | F5 |
| `static/index.html` | Entire frontend (HTML + fetch) | F0 |

## Request lifecycle (target, `POST /chat`)
1. Load session history from Firestore (short-term).
2. Retrieve user-scoped memories from Memory Bank (long-term).
3. Build prompt: system prompt + memories + history + new user message.
4. Call Gemini 2.5 Flash.
5. Persist user + model messages to Firestore.
6. Fire-and-forget `generate_memories` for this turn.
7. Return `{reply}`. Entire turn = one Langfuse trace.

## Current lifecycle (F2)
- `GET /` -> serves `static/index.html` (chat UI with session sidebar).
- `GET /health` -> `{"status": "ok"}` (liveness; NOT `/healthz` — Google's
  Front End intercepts `/healthz` on *.run.app).
- `POST /chat` `{session_id, message}` -> `{reply}`: persist user turn ->
  load full session history from Firestore -> `gemini.generate(history)`
  (multi-turn) -> persist model turn. Errors surface as HTTP 502.
- `GET /sessions/{id}` -> `{messages}` (load / switch session).
- `DELETE /sessions/{id}` -> delete session + messages (sidebar delete).
- `GET /static/*` -> static assets.

Frontend keeps only the session list (id + label) in localStorage; message
history is always fetched from Firestore (server is the source of truth).
