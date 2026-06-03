# Runbook

Operational commands. Grows as features land. Status: **F0**.

## Local development (uv)
```bash
# from repo root — uv creates .venv and installs from uv.lock
uv sync

# /chat calls Gemini on Vertex, so it needs ADC + project/region env:
gcloud auth application-default login                       # one-time
gcloud auth application-default set-quota-project gcpdemo-zackshioi  # one-time
export GCP_PROJECT=gcpdemo-zackshioi GCP_LOCATION=us-central1

# run the app (hot reload)
uv run uvicorn app.main:app --reload --port 8080

# verify
curl localhost:8080/health         # -> {"status":"ok"}  (NOT /healthz; GFE reserves it)
curl -X POST localhost:8080/chat -H 'Content-Type: application/json' \
     -d '{"message":"hi"}'         # -> {"reply":"..."}  (real Gemini)
open http://localhost:8080/         # the UI
```
Add a dependency: `uv add <pkg>` (updates pyproject.toml + uv.lock).

> The `app` and `f1-prototype` servers in `.claude/launch.json` are for the
> preview panel; `app` injects the env vars above.

## Run via Docker (parity with Cloud Run)
```bash
docker build -t memorychat .
docker run -p 8080:8080 memorychat
curl localhost:8080/health
```

## GCP infra (Terraform)
All infra lives in `infra/` as Terraform. State is **remote in GCS**
(`gs://gcpdemo-zackshioi-tfstate/infra/`) with locking + versioning, so local
and CICD share it. `gcloud` is only needed for auth.
```bash
gcloud auth application-default login    # ADC for the Terraform provider
cd infra
cp terraform.tfvars.example terraform.tfvars   # set project_id (+ billing if create_project)
terraform init     # connects to the GCS backend
terraform plan
terraform apply
```

### One-time backend bootstrap (already done; for reference / new env)
The state bucket is itself Terraform-managed, so it is created before the
backend points at it:
```bash
# 1. With NO backend block, create the bucket (state.tf) using local state:
terraform init && terraform apply        # creates <project>-tfstate
# 2. Add the `backend "gcs"` block to versions.tf, then migrate:
terraform init -migrate-state            # copies local state into the bucket
```
### Provisioned environment (live)
- Project: **`gcpdemo-zackshioi`** (ACTIVE, billing linked).
- Region: **`us-central1`**.
- Auth: ADC via `gcloud auth application-default login` (account
  `zack.weizhe.xu@gmail.com`).

Infra is built up incrementally, mirroring the app:
- **F0 (done)**: project creation + enabled APIs (run, aiplatform, firestore,
  artifactregistry, iamcredentials, cloudbuild, storage) + GCS remote-state
  backend.
- **F2 (done)**: Firestore Native database in `us-central1` (`infra/firestore.tf`).
- **F3**: Agent Engine instance (Memory Bank).
- **F5**: self-hosted Langfuse resources.
- **F6 (done, brought forward)**: Artifact Registry, Cloud Run service
  (`memorychat`, public), runtime + deployer SAs, WIF pool/provider.

## Deploy (CICD) — two pipelines
Two keyless (WIF) workflows, scoped by path so they don't overlap:
- **`infra.yml`** (changes under `infra/`): `terraform plan/apply` as the
  `terraform` SA, against the shared GCS state. Project bootstrap is NOT managed
  here (removed from state; `create_project=false`) so it can never be destroyed.
- **`deploy.yml`** (changes under `app/`, `Dockerfile`, deps): build image ->
  push to Artifact Registry -> `gcloud run deploy` as the `github-deployer` SA.
  Terraform owns the rest of the service (it `ignore_changes` image + scaling).

- Live URL: **https://memorychat-gjs22qk5cq-uc.a.run.app**
- Manual trigger: GitHub Actions -> "deploy" -> Run workflow (`workflow_dispatch`).
- Manual deploy (rarely needed):
  ```bash
  IMG=us-central1-docker.pkg.dev/gcpdemo-zackshioi/app/memorychat:manual
  gcloud auth configure-docker us-central1-docker.pkg.dev --quiet
  docker build -t $IMG . && docker push $IMG
  gcloud run deploy memorychat --image $IMG --region us-central1
  ```

## Environment variables
| Var | Used by | Added in |
|---|---|---|
| `PORT` | uvicorn (Cloud Run injects it) | F0 |
| `GCP_PROJECT` | google-genai / Firestore (`gcpdemo-zackshioi`) | F1 |
| `GCP_LOCATION` | `us-central1` | F1 |
| `AGENT_ENGINE_ID` | Memory Bank | F3 |
| `LANGFUSE_HOST` / `LANGFUSE_PUBLIC_KEY` / `LANGFUSE_SECRET_KEY` | tracing | F5 |

## Demo script (for the interview)
> Finalized once F3/F4 land. Sketch:
> 1. Open the app, set `user_id=alice`, chat and state a preference.
> 2. Show session history persists on reload (short-term).
> 3. Open a fresh browser, same `user_id` — the bot recalls the preference (long-term).
> 4. Hit `/debug/memories?user_id=alice` to show the extracted memories.
