# Architecture

> Kept in sync with the code. Updated as step (7) of every feature.
> Current state: **F3 — long-term memory live** (Memory Bank, user-scoped,
> cross-session). Short + long-term both working.

## Components (target)
| Component | Tech | Region | Status |
|---|---|---|---|
| Web app | FastAPI on Cloud Run (`min-instances=0`) | us-central1 | F0 (local only) |
| LLM | Gemini 2.5 Flash via `google-genai` (Vertex) | us-central1 | F1 (done) |
| Short-term memory | Firestore (Native) | us-central1 | F2 (done) |
| Long-term memory | Agent Engine — Memory Bank (vertexai SDK) | us-central1 | F3 (done) |
| Tracing | Self-hosted Langfuse | — | F5 |
| CICD | GitHub Actions + WIF: `infra.yml` (terraform) + `deploy.yml` (build/deploy) | — | F6 (done, brought forward) |
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
| `long_term.py` | Memory Bank `generate` / `retrieve` (vertexai SDK) | F3 (done) |
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

## Current lifecycle (F3)
- `GET /` -> serves `static/index.html` (sidebar with user_id + sessions).
- `GET /health` -> `{"status": "ok"}` (liveness; NOT `/healthz` — Google's
  Front End intercepts `/healthz` on *.run.app).
- `POST /chat` `{user_id, session_id, message}` -> `{reply}`:
  1. persist user turn (Firestore, short-term)
  2. `long_term.retrieve(user_id)` from Memory Bank
  3. `gemini.generate(history, memories)` — memories injected as system prompt
  4. persist model turn
  5. background: `long_term.generate(user_id, turn)` — async extraction
- `GET /sessions/{id}` -> `{messages}`; `DELETE /sessions/{id}`.
- `GET /static/*` -> static assets.

Frontend keeps only the per-user session list in localStorage; transcripts come
from Firestore. Long-term memory is keyed by user_id only, so it spans sessions
and browsers. AGENT_ENGINE_ID (the Agent Engine resource) is passed via env;
long-term degrades gracefully (no-op) if it's unset.
