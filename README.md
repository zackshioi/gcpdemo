# MemoryChat

A minimal, production-flavored GCP chat demo: Gemini that remembers **this
conversation** (short-term, Firestore) and **you across sessions** (long-term,
Vertex AI Memory Bank). Serverless on Cloud Run, deployed via GitHub Actions +
Workload Identity Federation, traced and eval-gated with self-hosted Langfuse.

## Status
Building feature by feature — see the roadmap in [docs/PRD.md](docs/PRD.md).
Current: **F0 — scaffold & docs** (runs locally, no GCP calls yet).

## Quickstart (local)
```bash
uv sync
uv run uvicorn app.main:app --reload --port 8080
# http://localhost:8080
```

## Docs (read in this order)
- [docs/PRD.md](docs/PRD.md) — what & why, locked decisions, feature roadmap.
- [docs/ARCHITECTURE.md](docs/ARCHITECTURE.md) — components, data flow, request lifecycle.
- [docs/DECISIONS.md](docs/DECISIONS.md) — ADR log (the "why" behind each choice).
- [docs/RUNBOOK.md](docs/RUNBOOK.md) — local run, deploy, GCP setup, demo script.

## Stack
FastAPI · Cloud Run · Gemini 2.5 Flash (Vertex AI) · Firestore · Vertex AI
Memory Bank · `google-genai` SDK · self-hosted Langfuse · GitHub Actions + WIF.
Tooling: **uv** (Python), **Terraform** (`infra/`). All in `us-central1`.
