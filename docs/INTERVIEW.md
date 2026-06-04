# Interview cheat sheet

A walkthrough study sheet for MemoryChat. Pairs with ARCHITECTURE.md / DECISIONS.md.

## 30-second pitch
FastAPI container on Cloud Run (scale-to-zero, least-privilege SA). GitHub
Actions deploys keyless via Workload Identity Federation; all infra is Terraform
with state in GCS. Chat uses the google-genai SDK against Gemini 2.5 Flash on
Vertex AI. **Short-term memory** = Firestore (per session); **long-term memory**
= Vertex AI Memory Bank (per user_id, async fact extraction, cross-session
recall). Auth is ADC end-to-end — zero JSON keys.

## Deploy on GCP (Cloud Run)
Project + billing → enable APIs → containerize → push to Artifact Registry →
`gcloud run deploy`.
- Quick path: `gcloud run deploy NAME --source . --region us-central1 --allow-unauthenticated`
- Knobs: `min-instances=0` (cost vs cold start); runtime **service account**
  (least privilege); public via `allUsers` + `roles/run.invoker`; env vars.
- Cloud Run ≈ AWS App Runner (between Lambda and Fargate).

## Use Vertex AI
```python
from google import genai
c = genai.Client(vertexai=True, project=P, location="us-central1")
c.models.generate_content(model="gemini-2.5-flash", contents=[...],
                          config={"system_instruction": "..."}).text
```
- `vertexai=True` → Vertex (enterprise IAM/region), NOT AI Studio API-key path.
- Auth = ADC (no key). Region matters (availability/latency/residency).

## Auth model (one ADC, three sources)
| Env | Credential |
|---|---|
| Local | `gcloud auth application-default login` (user) |
| Cloud Run | attached runtime SA (automatic) |
| CICD | WIF: GitHub OIDC token → impersonate SA (no key) |

**WIF = GitHub OIDC + AssumeRole.** Two policy layers: the provider's
`attribute_condition` (only my repo's tokens) + the SA's IAM binding
(`roles/iam.workloadIdentityUser` to the repo's principalSet).

## Memory: short vs long
| | Store | What | Scope |
|---|---|---|---|
| Short-term | **Firestore** | verbatim transcript | session_id |
| Long-term | **Vertex AI Memory Bank** | LLM-extracted facts | user_id |
Long-term ≠ replaying all history: Memory Bank extracts/dedupes durable facts
with gemini-2.5-flash (async ~15s) and retrieves by user_id → cross-session.

## Connecting a backing service (same 4 steps each)
1. enable API → 2. create resource → 3. grant runtime SA a role → 4. app
connects via SDK + env.
- Firestore: `firestore.googleapis.com` → `(default)` DB → `roles/datastore.user`
  → `firestore.Client(project)`.
- Memory Bank: `aiplatform.googleapis.com` → Agent Engine instance (imperative,
  no TF) → `roles/aiplatform.user` → `vertexai.Client().agent_engines.memories.*`
  with `AGENT_ENGINE_ID` + `scope={"user_id": ...}`.

## `/chat` request flow
persist user turn (Firestore) → retrieve long-term (Memory Bank, by user_id) →
inject as system prompt + replay session history → Gemini → persist model turn →
background async memory extraction → return.

## Real gotchas (shows experience)
- `/healthz` is intercepted by Google's Front End on `*.run.app` → renamed `/health`.
- CICD's SA needs `cloudresourcemanager` + `serviceusage` APIs enabled (user
  creds get a grace SAs don't) → classic "works locally, 403 in CI".
- Memory Bank has no Terraform resource → created imperatively (the IaC boundary).
- `google-genai 2.7.0` lacks `agent_engines` → Memory Bank via `vertexai` SDK.
- Agent Engine isn't in every region → whole stack pinned to `us-central1`.

## Likely follow-ups
- **Why Firestore not in-memory?** Cloud Run is stateless / scales to zero /
  multi-instance — memory would be lost and not shared; Firestore persists.
- **Cold starts?** `min-instances=1`, startup CPU boost, slim image.
- **Multi-user isolation?** long-term scoped by `scope={user_id}`; runtime SA
  can't deploy or touch IAM; prod would add real auth + Firestore rules.
- **Quality gate?** next: Langfuse traces + a memory-recall eval dataset that
  CICD must pass before shifting traffic.

## AWS ↔ GCP
Cloud Run≈App Runner · Firestore≈DynamoDB · GCS≈S3 · Artifact Registry≈ECR ·
WIF≈IAM OIDC+AssumeRole · Cloud Build≈CodeBuild · Vertex AI≈Bedrock/SageMaker ·
Cloud Logging≈CloudWatch.
