# PRD — MemoryChat (GCP demo)

## 1. One-liner
A public web chat where Gemini remembers **this conversation** (short-term) and
**you across sessions** (long-term), deployed serverless on GCP, built so every
file and architecture decision can be defended in a live interview walkthrough.

## 2. Goals / non-goals
**Goals**
- Demonstrate short-term (session) + long-term (cross-session, user-scoped) memory.
- Production hygiene: serverless, WIF (no JSON keys), structured logs, tracing,
  eval-gated CICD.
- Minimal surface area: few files, heavy "why" comments, walkable in ~30 min.

**Non-goals**
- No auth/OAuth (user types a `user_id`).
- No React/build step (single HTML + `fetch`).
- No multi-region HA, rate limiting, or streaming (mention as "next steps").

## 3. Locked decisions
| Topic | Decision |
|---|---|
| GCP project | Created from scratch; steps live in `RUNBOOK.md`. |
| Region | **Single region: `us-central1`** (most complete Agent Engine / Memory Bank support; drops AU data-residency, accepted trade-off of single-region). |
| Langfuse | **Self-hosted** on GCP. |
| Memory Bank SDK | **`google-genai` only** (`client.agent_engines.memories.*`). Fallback: if that unified path is unavailable in our region at F3, use the `vertexai` SDK for Memory Bank only. |
| Compute | Cloud Run, `min-instances=0`. |
| LLM | Gemini 2.5 Flash on Vertex AI (not AI Studio). |
| Short-term store | Firestore (Native mode), subcollection per session. |
| Long-term store | Vertex AI Agent Engine — Memory Bank. |
| Frontend | Single static HTML, served via FastAPI. |
| Deploy | GitHub Actions + Workload Identity Federation. |
| Tracing | Self-hosted Langfuse; one trace per turn. |
| Eval gate | Langfuse dataset + LLM-judge; CICD promotes traffic only if it passes. |
| Logs | Cloud Logging structured JSON, one line per endpoint. |

See `DECISIONS.md` for the rationale (ADR log).

## 4. Architecture
```
Browser (index.html + fetch)
        | HTTPS
        v
Cloud Run (FastAPI, min-instances=0)
        |
        +--> Vertex AI - Gemini 2.5 Flash      [us-central1]
        |        via google-genai (vertexai=True)
        |
        +--> Firestore (Native mode)           [SHORT-TERM: session history]
        |        sessions/{session_id}/messages/*
        |
        +--> Vertex AI Agent Engine - Memory Bank  [LONG-TERM: user-scoped facts]
        |        google-genai client.agent_engines.memories.generate/retrieve
        |
        +--> Langfuse (self-hosted; traces every turn; hosts eval dataset)

GitHub -> Actions (OIDC) -> Workload Identity Federation -> SA -> deploy Cloud Run
                                   |
                                   +- gate: run Langfuse eval against the no-traffic
                                      candidate revision; promote only if it passes.
```

## 5. Data model
**Firestore (short-term)**
```
sessions/{session_id}
  user_id: string
  created_at: timestamp
  messages/{auto_id}
    role: "user" | "model"
    text: string
    ts: timestamp
```
**Memory Bank (long-term)** — managed; we do not own the schema. We write with
`scope={"user_id": <id>}`; Memory Bank extracts facts into topics
(USER_PREFERENCES, USER_PERSONAL_INFO, KEY_CONVERSATION_DETAILS,
EXPLICIT_INSTRUCTIONS) and we retrieve by the same scope.

## 6. API
| Method | Path | Purpose |
|---|---|---|
| GET  | `/`                          | serve `index.html` |
| GET  | `/healthz`                   | liveness for Cloud Run + CICD gate |
| POST | `/chat`                      | `{user_id, session_id, message}` -> `{reply}` |
| GET  | `/sessions/{session_id}`     | session history (short-term proof) |
| GET  | `/debug/memories?user_id=X`  | list all Memory Bank memories for a user |

**`/chat` turn flow:** load Firestore history -> retrieve Memory Bank memories ->
build prompt (system+memories, history, new message) -> Gemini -> persist both
messages -> fire `generate_memories` for the turn -> return reply. The whole turn
is wrapped in one Langfuse trace.

## 7. Feature roadmap
Per feature: (1) UI/UX mock for approval -> feature spec, (2) DB, (3) AI,
(4) API, (5) frontend, (6) wire-up & verify, (7) update docs.

- **F0 — Scaffold & docs**: repo layout, docs skeleton, FastAPI hello + static
  mount, runs locally. *(no AI/DB)*  **<- current**
- **F1 — Basic chat**: Gemini 2.5 Flash via Vertex, no memory.
- **F2 — Short-term memory**: Firestore session history; reload -> history persists.
- **F3 — Long-term memory** *(headline)*: Memory Bank generate + retrieve.
- **F4 — Debug endpoint**: `/debug/memories` + a "Memories" panel in the UI.
- **F5 — Langfuse tracing**: every turn traced with spans.
- **F6 — CICD + WIF**: GitHub Actions builds & deploys to Cloud Run via WIF.
- **F7 — Eval gate**: Langfuse dataset of memory-recall cases gates promotion.

## 8. Repo layout
```
gcp/
  app/
    main.py            # FastAPI app + routes (thin)
    gemini.py          # google-genai client + chat call          (F1)
    short_term.py      # Firestore session history                (F2)
    long_term.py       # Memory Bank generate/retrieve             (F3)
    tracing.py         # Langfuse setup                            (F5)
    static/index.html  # the whole frontend
  evals/
    dataset.py         # seed Langfuse eval dataset                (F7)
    run_eval.py        # run experiment, nonzero exit on fail      (F7)
  infra/               # Terraform: all GCP infrastructure as code
    versions.tf variables.tf main.tf outputs.tf
    state.tf           # GCS remote-state bucket (backend in versions.tf)
    firestore.tf       # Firestore Native database (F2)
  .github/workflows/deploy.yml                                     (F6)
  Dockerfile
  pyproject.toml       # uv-managed deps
  uv.lock              # committed lockfile
  docs/{PRD.md, ARCHITECTURE.md, RUNBOOK.md, DECISIONS.md}
  README.md
```

## 8b. Toolchain
- **Python**: `uv` (`pyproject.toml` + `uv.lock`); app is `package = false`.
- **Infra**: Terraform under `infra/`, grown per feature.

## 9. Docs strategy (so a new agent can pick up instantly)
- `PRD.md` — what & why (this file).
- `ARCHITECTURE.md` — components, data flow, request lifecycle; kept in sync each feature.
- `DECISIONS.md` — append-only ADR log (one entry per non-obvious choice).
- `RUNBOOK.md` — exact commands: local run, deploy, env vars, GCP one-time setup, demo script.
- Each feature updates the relevant doc as step (7).
