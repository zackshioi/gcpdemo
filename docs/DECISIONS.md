# Decision log (ADR)

Append-only. One entry per non-obvious choice. Newest at the bottom.

---
## ADR-001 — Cloud Run with min-instances=0
**Decision:** Run the API as a container on Cloud Run with `min-instances=0`.
**Why:** Scale-to-zero means ~$0 when idle (demo-friendly); native IAM; the
container is portable. **Trade-off:** cold starts on first request — acceptable
for a demo; mention `min-instances=1` as the production knob.

## ADR-002 — Gemini 2.5 Flash on Vertex AI (not AI Studio)
**Decision:** Call Gemini through Vertex AI, not the AI Studio (Gemini Developer
API) endpoint. **Why:** enterprise IAM / VPC-SC / data-residency story; same
model family Memory Bank uses internally; one auth model (ADC) across all GCP
calls. **Trade-off:** slightly more setup (project + region) than an API key.

## ADR-003 — Firestore for short-term memory
**Decision:** Persist per-session conversation history in Firestore Native mode,
as a subcollection of messages under each session document. **Why:** survives
Cloud Run cold starts / restarts (in-memory would not); cheap; trivially
demonstrates "history persisted". **Trade-off:** a network round-trip per turn
vs. in-process memory.

## ADR-004 — Memory Bank for long-term memory
**Decision:** Use Vertex AI Agent Engine Memory Bank for cross-session,
user-scoped memory. **Why:** managed async fact-extraction (uses
`gemini-2.5-flash`), user-scoped retrieval, and consolidation — the demo's
differentiator over "just replay the whole history". **Trade-off:** a managed
dependency we do not fully control; eventual consistency on extraction.

## ADR-005 — Single region us-central1
**Decision:** Put everything in `us-central1` instead of splitting Gemini
inference (australia-southeast1) from the Agent Engine control plane.
**Why:** Agent Engine / Memory Bank has the most complete and earliest support
in us-central1, and the unified `google-genai` Memory Bank path is guaranteed
there; single region keeps the mental model and IAM simple. **Trade-off:** drops
the Australian data-residency narrative — accepted as the cost of "single region".

## ADR-006 — google-genai as the only SDK
**Decision:** Use `google-genai` for both chat (`generate_content`) and Memory
Bank (`client.agent_engines.memories.*`); avoid the legacy `vertexai` /
`google-generativeai` SDKs. **Why:** in 2026 google-genai unifies both surfaces;
one client object is the cleanest thing to walk through. **Fallback:** if the
unified Memory Bank path is unavailable/buggy in our region at F3, use the
`vertexai` SDK for Memory Bank only (chat stays on google-genai).

## ADR-007 — Self-hosted Langfuse
**Decision:** Self-host Langfuse on GCP rather than use Langfuse Cloud.
**Why:** "we own the whole stack" story; keeps trace/eval data inside our
project. **Trade-off:** more infra to run (Postgres + server) — documented in
`RUNBOOK.md`.

## ADR-011 — CICD: keyless WIF + Terraform/CICD split (brought forward)
**Decision:** Deploy via GitHub Actions using Workload Identity Federation
(no JSON key). Terraform owns the Cloud Run service shape (runtime SA, env,
scaling, public access); CICD only builds/pushes an image and updates the image
on the service. Brought forward (before F3/F4) so every later feature auto-ships
and the app is public early. **Why:** keyless auth is the compliant pattern;
the Terraform-owns-config / CICD-owns-image split keeps deploys boring and
avoids drift (service uses `ignore_changes` on the image). Two least-privilege
SAs: `memorychat-run` (runtime: Vertex + Firestore, no deploy) and
`github-deployer` (deploy: run.admin + AR writer + actAs runtime, no data
plane). **Trade-off:** the service is first created with a placeholder image
that the first CICD run replaces.

## ADR-008 — uv for Python toolchain
**Decision:** Manage the Python environment with `uv` (`pyproject.toml` +
`uv.lock`), not pip/venv or requirements.txt. **Why:** fast, reproducible
(committed lockfile), single tool for venv + deps + run; the Docker build reuses
the same lockfile via `uv sync --frozen` so local and prod resolve identically.
The project is `package = false` (an app, not a library), so uv only manages the
environment.

## ADR-009 — Terraform for GCP infrastructure
**Decision:** All GCP infra is Terraform under `infra/`, not ad-hoc `gcloud`
commands. **Why:** reproducible, reviewable, destroyable; the deploy story is
"read the HCL" not "trust my shell history". Infra grows per feature (Firestore
@ F2, Agent Engine @ F3, Artifact Registry + WIF + Cloud Run @ F6). **Trade-off:**
project+billing bootstrap is a chicken-and-egg — handled by an optional
`create_project` toggle.

## ADR-010 — Terraform remote state in GCS
**Decision:** Store Terraform state in a GCS bucket (`<project>-tfstate`,
versioned + private), configured as the `gcs` backend, instead of local state.
**Why:** local and CICD (F6) must share one source of truth; GCS gives state
locking (no concurrent-apply corruption) and version history for recovery.
**Bootstrap:** the bucket is created with the local backend first, then the
backend is switched to `gcs` and state migrated with
`terraform init -migrate-state` (the bucket name is hardcoded since backend
blocks can't use variables). **Trade-off:** the state bucket is self-managed in
the same config it backs — acceptable and common.
